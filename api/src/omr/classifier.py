"""Classificação de cada questão a partir dos percentuais de preenchimento.

Regra de ouro do sistema: NUNCA escolher uma alternativa com baixa confiança.
Tudo que não for uma marcação única, forte e bem separada das demais vai para
revisão manual do professor.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional

# Thresholds sobre o percentual de preenchimento (imagem binarizada adaptativa)
LIMIAR_MARCADA = 0.45      # acima disto a bolha é considerada pintada
LIMIAR_BRANCO = 0.22       # abaixo disto (todas) a questão está em branco
SEPARACAO_MINIMA = 0.25    # diferença mínima entre 1ª e 2ª bolha mais preenchidas
CONFIANCA_MINIMA = 0.70    # abaixo disto a questão vai para revisão

# Status possíveis de uma questão
STATUS_OK = 'OK'                    # marcação única e confiável
STATUS_EM_BRANCO = 'EM_BRANCO'      # nenhuma marcação (confiável)
STATUS_MULTIPLA = 'MULTIPLA'        # duas ou mais bolhas pintadas → revisão
STATUS_FRACA = 'FRACA'              # marcação fraca/parcial → revisão
STATUS_AMBIGUA = 'AMBIGUA'          # duas bolhas com níveis próximos → revisão
STATUS_NAO_LIDA = 'NAO_LIDA'        # bolhas não localizadas → revisão

STATUS_QUE_EXIGEM_REVISAO = {STATUS_MULTIPLA, STATUS_FRACA, STATUS_AMBIGUA, STATUS_NAO_LIDA}


@dataclass
class QuestaoClassificada:
    numero: int
    status: str
    alternativa: Optional[str]          # None quando não há leitura confiável
    confianca: float
    motivo: Optional[str]
    preenchimentos: Dict[str, float] = field(default_factory=dict)

    @property
    def precisa_revisao(self) -> bool:
        return self.status in STATUS_QUE_EXIGEM_REVISAO

    def to_dict(self):
        return {
            'numero': self.numero,
            'status': self.status,
            'alternativa_detectada': self.alternativa,
            'confianca': round(self.confianca, 3),
            'motivo': self.motivo,
            'precisa_revisao': self.precisa_revisao,
            'preenchimentos': {k: round(v, 3) for k, v in self.preenchimentos.items()},
        }


def _confianca_marcada(maior: float, segunda: float) -> float:
    """Confiança composta: força da marcação + separação da segunda colocada."""
    forca = min(1.0, maior / 0.7)
    separacao = min(1.0, (maior - segunda) / 0.5)
    return round(0.45 * forca + 0.55 * separacao, 3)


def classificar_questao(numero: int,
                        preenchimentos: Optional[Dict[str, float]]) -> QuestaoClassificada:
    """Classifica uma questão. `preenchimentos` é {alternativa: percentual}."""
    if not preenchimentos:
        return QuestaoClassificada(
            numero=numero, status=STATUS_NAO_LIDA, alternativa=None, confianca=0.0,
            motivo='As bolhas desta questão não foram localizadas na imagem.',
        )

    ordenadas = sorted(preenchimentos.items(), key=lambda kv: kv[1], reverse=True)
    (alt1, p1), p2 = ordenadas[0], (ordenadas[1][1] if len(ordenadas) > 1 else 0.0)

    # Em branco: nenhuma bolha atinge sequer o limiar de marca fraca
    if p1 < LIMIAR_BRANCO:
        confianca = round(min(1.0, 1.0 - p1 / LIMIAR_BRANCO * 0.5), 3)
        return QuestaoClassificada(
            numero=numero, status=STATUS_EM_BRANCO, alternativa=None,
            confianca=confianca, motivo=None, preenchimentos=dict(preenchimentos),
        )

    # Múltipla marcação: duas ou mais bolhas acima do limiar de marcada
    acima = [a for a, p in preenchimentos.items() if p >= LIMIAR_MARCADA]
    if len(acima) >= 2:
        return QuestaoClassificada(
            numero=numero, status=STATUS_MULTIPLA, alternativa=None, confianca=0.0,
            motivo=f'Múltiplas marcações detectadas: {", ".join(sorted(acima))}.',
            preenchimentos=dict(preenchimentos),
        )

    # Marcação fraca: existe sinal, mas abaixo do limiar de marcação plena
    if p1 < LIMIAR_MARCADA:
        return QuestaoClassificada(
            numero=numero, status=STATUS_FRACA, alternativa=None, confianca=0.0,
            motivo=(f'Marcação fraca/parcial na alternativa {alt1} '
                    f'({p1:.0%} de preenchimento). Pode ser rasura ou marca apagada.'),
            preenchimentos=dict(preenchimentos),
        )

    # Ambiguidade: segunda bolha perto demais da primeira (rasura, marca dupla parcial)
    if (p1 - p2) < SEPARACAO_MINIMA:
        alt2 = ordenadas[1][0]
        return QuestaoClassificada(
            numero=numero, status=STATUS_AMBIGUA, alternativa=None, confianca=0.0,
            motivo=(f'Leitura ambígua entre {alt1} ({p1:.0%}) e {alt2} ({p2:.0%}). '
                    'Possível rasura ou marcação dupla parcial.'),
            preenchimentos=dict(preenchimentos),
        )

    confianca = _confianca_marcada(p1, p2)
    if confianca < CONFIANCA_MINIMA:
        return QuestaoClassificada(
            numero=numero, status=STATUS_AMBIGUA, alternativa=None, confianca=confianca,
            motivo=f'Confiança insuficiente ({confianca:.0%}) na alternativa {alt1}.',
            preenchimentos=dict(preenchimentos),
        )

    return QuestaoClassificada(
        numero=numero, status=STATUS_OK, alternativa=alt1, confianca=confianca,
        motivo=None, preenchimentos=dict(preenchimentos),
    )


def classificar_prova(num_questoes: int,
                      preenchimentos: Dict[int, Dict[str, float]]) -> List[QuestaoClassificada]:
    """Classifica todas as questões de 1..num_questoes."""
    return [classificar_questao(n, preenchimentos.get(n)) for n in range(1, num_questoes + 1)]
