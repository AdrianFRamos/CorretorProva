"""Leitura por IA visual do cartao-resposta.

A IA nao calcula a nota final. Ela apenas sugere leituras por questao com
confianca; o backend valida o JSON, aplica regras conservadoras e calcula a nota.
"""

import base64
import json
import logging
import os
import re
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional

import cv2
import numpy as np

from src.omr.classifier import (
    STATUS_AMBIGUA,
    STATUS_EM_BRANCO,
    STATUS_MULTIPLA,
    STATUS_NAO_LIDA,
    STATUS_OK,
)
from src.omr.pipeline import STATUS_APROVADA, STATUS_REVISAO, LayoutProva

logger = logging.getLogger('api.ai_omr')

OPENAI_RESPONSES_URL = 'https://api.openai.com/v1/responses'
MIN_CONFIANCA_OK = 0.82
MIN_CONFIANCA_BRANCO = 0.90


def _imagem_data_url(image: np.ndarray) -> str:
    h, w = image.shape[:2]
    max_lado = 1600
    escala = min(1.0, max_lado / max(h, w))
    if escala < 1.0:
        image = cv2.resize(image, None, fx=escala, fy=escala, interpolation=cv2.INTER_AREA)
    ok, buf = cv2.imencode('.jpg', image, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
    if not ok:
        raise ValueError('Nao foi possivel codificar a imagem para JPEG.')
    b64 = base64.b64encode(buf).decode('ascii')
    return f'data:image/jpeg;base64,{b64}'


def _prompt(gabarito: Dict[str, str], layout: LayoutProva) -> str:
    alternativas = ', '.join(layout.alternativas)
    return f"""
Voce e um leitor visual de cartoes-resposta.

Analise SOMENTE a area do gabarito de respostas da imagem. Para cada questao,
identifique a alternativa marcada entre {alternativas}. Nao calcule nota.

Regras:
- Retorne apenas JSON valido, sem markdown.
- Use numero de questoes de 1 a {layout.num_questoes}.
- Se uma questao nao existir na imagem, use status "unread".
- Se estiver em branco, use status "blank".
- Se houver duas marcacoes, rasura ou duvida, use status "multiple" ou "ambiguous".
- Use confidence entre 0 e 1.
- Nao invente resposta quando estiver incerto.

Formato exato:
{{
  "questions": [
    {{
      "number": 1,
      "answer": "A",
      "status": "ok",
      "confidence": 0.97,
      "notes": "marcacao forte"
    }}
  ]
}}

Gabarito oficial disponivel apenas para referencia de quantidade:
{json.dumps(gabarito, ensure_ascii=False, sort_keys=True)}
""".strip()


def _extrair_texto_resposta(data: Dict[str, Any]) -> str:
    if isinstance(data.get('output_text'), str):
        return data['output_text']
    partes: List[str] = []
    for item in data.get('output', []) or []:
        for content in item.get('content', []) or []:
            if isinstance(content.get('text'), str):
                partes.append(content['text'])
    return '\n'.join(partes)


def _parse_json(texto: str) -> Dict[str, Any]:
    texto = texto.strip()
    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        match = re.search(r'\{.*\}', texto, re.DOTALL)
        if not match:
            raise
        return json.loads(match.group(0))


def _chamar_openai(image: np.ndarray, gabarito: Dict[str, str], layout: LayoutProva) -> Dict[str, Any]:
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise RuntimeError('OPENAI_API_KEY nao configurada.')

    model = os.environ.get('AI_OMR_MODEL', 'gpt-4o-mini')
    url = os.environ.get('OPENAI_RESPONSES_URL', OPENAI_RESPONSES_URL)
    payload = {
        'model': model,
        'input': [
            {
                'role': 'user',
                'content': [
                    {'type': 'input_text', 'text': _prompt(gabarito, layout)},
                    {'type': 'input_image', 'image_url': _imagem_data_url(image)},
                ],
            }
        ],
    }
    body = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url,
        data=body,
        method='POST',
        headers={
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise RuntimeError(f'Falha na IA ({exc.code}): {detail[:500]}') from exc

    texto = _extrair_texto_resposta(data)
    if not texto:
        raise RuntimeError('IA nao retornou texto JSON.')
    return _parse_json(texto)


def _normalizar_status(status: str) -> str:
    status = (status or '').strip().lower()
    if status in {'ok', 'marked', 'marcada'}:
        return STATUS_OK
    if status in {'blank', 'empty', 'em_branco', 'branco'}:
        return STATUS_EM_BRANCO
    if status in {'multiple', 'dupla', 'multipla'}:
        return STATUS_MULTIPLA
    if status in {'unread', 'missing', 'nao_lida', 'nao_existe'}:
        return STATUS_NAO_LIDA
    return STATUS_AMBIGUA


def _questao_ia(numero: int, item: Optional[Dict[str, Any]],
                alternativas: List[str]) -> Dict[str, Any]:
    if not item:
        return {
            'numero': numero,
            'status': STATUS_NAO_LIDA,
            'alternativa_detectada': None,
            'confianca': 0.0,
            'motivo': 'IA nao retornou leitura para esta questao.',
            'precisa_revisao': True,
            'preenchimentos': {},
        }

    status = _normalizar_status(str(item.get('status') or 'ambiguous'))
    answer = item.get('answer')
    answer = str(answer).strip().upper() if answer is not None else None
    if answer not in alternativas:
        answer = None
    try:
        confianca = float(item.get('confidence') or 0.0)
    except (TypeError, ValueError):
        confianca = 0.0
    confianca = max(0.0, min(1.0, confianca))
    notes = str(item.get('notes') or '').strip() or None

    if status == STATUS_OK and (answer is None or confianca < MIN_CONFIANCA_OK):
        status = STATUS_AMBIGUA
    if status == STATUS_EM_BRANCO and confianca < MIN_CONFIANCA_BRANCO:
        status = STATUS_AMBIGUA

    precisa_revisao = status in {STATUS_MULTIPLA, STATUS_AMBIGUA, STATUS_NAO_LIDA}
    return {
        'numero': numero,
        'status': status,
        'alternativa_detectada': answer if status == STATUS_OK else None,
        'confianca': round(confianca, 3),
        'motivo': notes,
        'precisa_revisao': precisa_revisao,
        'preenchimentos': ({answer: round(confianca, 3)} if answer else {}),
        'origem': 'ia',
    }


def resultado_por_ia(image: np.ndarray, gabarito: Dict[str, str],
                     layout: LayoutProva) -> Dict[str, Any]:
    bruto = _chamar_openai(image, gabarito, layout)
    items = bruto.get('questions') or []
    por_numero = {}
    for item in items:
        try:
            numero = int(item.get('number'))
        except (AttributeError, TypeError, ValueError):
            continue
        por_numero[numero] = item

    questoes = [
        _questao_ia(numero, por_numero.get(numero), layout.alternativas)
        for numero in range(1, layout.num_questoes + 1)
    ]

    acertos = erros = em_branco = pendentes = 0
    for q in questoes:
        correta = gabarito.get(str(q['numero']))
        q['resposta_correta'] = correta
        if q['precisa_revisao']:
            pendentes += 1
            q['acertou'] = None
        elif q['status'] == STATUS_EM_BRANCO:
            em_branco += 1
            erros += 1
            q['acertou'] = False
        else:
            acertou = q['alternativa_detectada'] == correta
            acertos += int(acertou)
            erros += int(not acertou)
            q['acertou'] = acertou

    total = layout.num_questoes
    nota = round(acertos / total * 10, 2) if total else 0.0
    nota_maxima = round((acertos + pendentes) / total * 10, 2) if total else 0.0
    status = STATUS_APROVADA if pendentes == 0 else STATUS_REVISAO
    return {
        'status': status,
        'qualidade': {'aprovada': True, 'problemas': []},
        'folha': {'detectada': None, 'metodo': 'ia_visual'},
        'deteccao': {
            'metodo': 'ia_visual',
            'bolhas_localizadas': sum(1 for q in questoes if q['status'] != STATUS_NAO_LIDA),
        },
        'gabarito_usado': gabarito,
        'questoes': questoes,
        'resumo': {
            'total_questoes': total,
            'acertos': acertos,
            'erros': erros,
            'em_branco': em_branco,
            'pendentes_revisao': pendentes,
            'nota_provisoria': nota,
            'nota_maxima_possivel': nota_maxima,
            'nota_confirmada': nota if pendentes == 0 else None,
        },
        'diagnostico': ['Leitura feita por IA visual e validada por regras do backend.'],
        'ia': {'provider': 'openai', 'model': os.environ.get('AI_OMR_MODEL', 'gpt-4o-mini')},
    }
