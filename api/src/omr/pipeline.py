"""Orquestração do pipeline de correção e regras de segurança da nota.

Garantias:
- Imagem reprovada na validação de qualidade → status REJEITADA_QUALIDADE, sem nota.
- Qualquer questão duvidosa → status PRECISA_REVISAO; a nota retornada é
  PROVISÓRIA e só pode ser confirmada após revisão manual.
- A nota é sempre calculada sobre o TOTAL de questões do gabarito
  (corrige o bug da versão anterior, que dividia pelas questões detectadas).
"""

import base64
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

import cv2
import numpy as np

from . import quality, preprocess, detector, classifier

logger = logging.getLogger('omr.pipeline')

STATUS_APROVADA = 'APROVADA_AUTOMATICA'
STATUS_REVISAO = 'PRECISA_REVISAO'
STATUS_REJEITADA = 'REJEITADA_QUALIDADE'
STATUS_ERRO = 'ERRO_PROCESSAMENTO'


@dataclass
class LayoutProva:
    """Configuração do layout do cartão-resposta (flexível por prova)."""
    num_questoes: int = 44
    num_alternativas: int = 5
    num_colunas: int = 2
    alternativas: List[str] = field(default_factory=lambda: ['A', 'B', 'C', 'D', 'E'])
    # margens relativas usadas apenas no fallback de grade matemática
    margens: Dict[str, float] = field(default_factory=lambda: {
        'superior': 0.20, 'inferior': 0.02, 'esquerda': 0.30, 'direita': 0.02,
    })

    def __post_init__(self):
        if len(self.alternativas) != self.num_alternativas:
            self.alternativas = [chr(ord('A') + i) for i in range(self.num_alternativas)]

    @classmethod
    def from_dict(cls, data: Optional[Dict[str, Any]]) -> 'LayoutProva':
        if not data:
            return cls()
        return cls(
            num_questoes=int(data.get('num_questoes', 44)),
            num_alternativas=int(data.get('num_alternativas', 5)),
            num_colunas=int(data.get('num_colunas', 2)),
            alternativas=data.get('alternativas') or
                [chr(ord('A') + i) for i in range(int(data.get('num_alternativas', 5)))],
            margens={**cls().margens, **(data.get('margens') or {})},
        )


def _recorte_base64(imagem: np.ndarray, bolhas: List[detector.Bolha],
                    numero: int) -> Optional[str]:
    """Recorta a região da questão (todas as bolhas) e devolve PNG em base64."""
    pts = [(b.cx, b.cy, b.raio) for b in bolhas if b.questao == numero]
    if not pts:
        return None
    margem = int(max(r for _, _, r in pts) * 2)
    x0 = max(0, min(p[0] for p in pts) - margem)
    x1 = min(imagem.shape[1], max(p[0] for p in pts) + margem)
    y0 = max(0, min(p[1] for p in pts) - margem)
    y1 = min(imagem.shape[0], max(p[1] for p in pts) + margem)
    recorte = imagem[y0:y1, x0:x1]
    if recorte.size == 0:
        return None
    ok, buf = cv2.imencode('.png', recorte)
    return base64.b64encode(buf).decode('ascii') if ok else None


class CorrecaoPipeline:
    """Pipeline completo: qualidade → pré-processamento → detecção →
    classificação → comparação com gabarito → regras de segurança."""

    def corrigir(self, image: np.ndarray,
                 gabarito: Dict[str, str],
                 layout: Optional[LayoutProva] = None) -> Dict[str, Any]:
        layout = layout or LayoutProva(num_questoes=len(gabarito) or 44)
        diagnostico: List[str] = []

        # ── 1. Validação de qualidade ────────────────────────────────────
        q = quality.validar_imagem(image)
        if not q.aprovada:
            logger.warning('Imagem rejeitada por qualidade: %s', q.problemas)
            return {
                'status': STATUS_REJEITADA,
                'qualidade': q.to_dict(),
                'questoes': [],
                'resumo': None,
                'diagnostico': q.problemas,
            }
        diagnostico.extend(q.problemas)  # avisos não bloqueantes (ex.: sombra)

        # ── 2. Pré-processamento ─────────────────────────────────────────
        prep = preprocess.preprocessar(image)
        if not prep.folha_detectada:
            diagnostico.append(
                'Borda da folha não detectada; processando a imagem completa. '
                'Garanta que o cartão apareça inteiro com fundo contrastante.'
            )

        # ── 3. Localização das bolhas ────────────────────────────────────
        det = detector.detectar_por_contornos(
            prep.imagem_binaria, layout.num_questoes,
            layout.num_alternativas, layout.num_colunas, layout.alternativas,
        )
        usou_fallback = det is None
        if usou_fallback:
            det = detector.detectar_por_grade(
                prep.imagem_binaria, layout.num_questoes,
                layout.num_alternativas, layout.num_colunas,
                layout.alternativas, layout.margens,
            )
            diagnostico.append(
                'Bolhas não localizadas individualmente; usada grade aproximada. '
                'A exigência de revisão manual foi reforçada.'
            )
        logger.info('Detecção: metodo=%s bolhas=%d', det.metodo, len(det.bolhas))

        # ── 4. Medição e classificação ───────────────────────────────────
        preenchimentos = detector.medir_preenchimentos(prep.imagem_binaria, det.bolhas)
        questoes = classifier.classificar_prova(layout.num_questoes, preenchimentos)

        # Regra de segurança extra: no modo grade (fallback, posições não
        # validadas), só leituras OK com confiança alta passam; o restante —
        # inclusive "em branco", que pode ser só grade desalinhada — vai para
        # revisão. Falso positivo é erro crítico; excesso de revisão não é.
        if usou_fallback:
            for qc in questoes:
                if qc.status == classifier.STATUS_OK and qc.confianca >= 0.85:
                    continue
                if qc.precisa_revisao:
                    continue
                qc.status = classifier.STATUS_AMBIGUA
                qc.alternativa = None
                qc.motivo = ('Leitura por grade aproximada (bolhas não localizadas '
                             'individualmente); confirmação manual necessária.')

        # ── 5. Comparação com o gabarito e nota ─────────────────────────
        acertos = erros = em_branco = pendentes = 0
        detalhes = []
        for qc in questoes:
            correta = gabarito.get(str(qc.numero))
            item = qc.to_dict()
            item['resposta_correta'] = correta
            if qc.precisa_revisao:
                pendentes += 1
                item['acertou'] = None
                item['recorte'] = _recorte_base64(prep.imagem_corrigida, det.bolhas, qc.numero)
            elif qc.status == classifier.STATUS_EM_BRANCO:
                em_branco += 1
                erros += 1
                item['acertou'] = False
            else:
                acertou = (qc.alternativa == correta)
                acertos += int(acertou)
                erros += int(not acertou)
                item['acertou'] = acertou
            detalhes.append(item)

        total = layout.num_questoes
        # Nota sempre sobre o total de questões do gabarito
        nota_provisoria = round(acertos / total * 10, 2) if total else 0.0
        nota_maxima_possivel = round((acertos + pendentes) / total * 10, 2) if total else 0.0

        status = STATUS_APROVADA if pendentes == 0 else STATUS_REVISAO
        if pendentes:
            diagnostico.append(
                f'{pendentes} questão(ões) exigem revisão manual do professor '
                'antes da confirmação da nota.'
            )

        return {
            'status': status,
            'qualidade': q.to_dict(),
            'folha': {'detectada': prep.folha_detectada, 'metodo': prep.metodo},
            'deteccao': {'metodo': det.metodo, 'bolhas_localizadas': len(det.bolhas)},
            'gabarito_usado': gabarito,
            'questoes': detalhes,
            'resumo': {
                'total_questoes': total,
                'acertos': acertos,
                'erros': erros,
                'em_branco': em_branco,
                'pendentes_revisao': pendentes,
                'nota_provisoria': nota_provisoria,
                'nota_maxima_possivel': nota_maxima_possivel,
                'nota_confirmada': nota_provisoria if pendentes == 0 else None,
            },
            'diagnostico': diagnostico,
        }
