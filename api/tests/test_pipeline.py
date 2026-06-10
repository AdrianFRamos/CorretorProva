"""Testes ponta a ponta do pipeline com cartões sintéticos.

Inclui a métrica crítica: TAXA DE FALSO POSITIVO (questão corrigida
automaticamente com alternativa errada) deve ser ZERO.
"""

import numpy as np
import pytest

from src.omr import CorrecaoPipeline, LayoutProva
from src.omr.pipeline import STATUS_APROVADA, STATUS_REJEITADA, STATUS_REVISAO
from tests.synthetic import CartaoSintetico

ALTS = ['A', 'B', 'C', 'D', 'E']


def _gabarito(n):
    return {str(i): ALTS[(i - 1) % 5] for i in range(1, n + 1)}


def _respostas_corretas(gabarito):
    return {int(k): v for k, v in gabarito.items()}


def _layout(n):
    return LayoutProva(num_questoes=n, num_alternativas=5, num_colunas=2)


def _falsos_positivos(resultado, respostas_reais):
    """Questões corrigidas automaticamente com leitura diferente da real."""
    fp = []
    for q in resultado['questoes']:
        if q['precisa_revisao']:
            continue
        real = respostas_reais.get(q['numero'])
        if q['status'] == 'EM_BRANCO':
            if real is not None:
                fp.append(q['numero'])
        elif q['alternativa_detectada'] != real:
            fp.append(q['numero'])
    return fp


def test_cartao_perfeito_aprovado_automaticamente():
    n = 20
    gab = _gabarito(n)
    respostas = _respostas_corretas(gab)
    img = CartaoSintetico(num_questoes=n).gerar(respostas)

    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    assert r['status'] == STATUS_APROVADA
    assert r['resumo']['acertos'] == n
    assert r['resumo']['nota_confirmada'] == 10.0
    assert _falsos_positivos(r, respostas) == []


def test_nota_calculada_sobre_total_do_gabarito():
    """Regressão do bug crítico: aluno com poucas respostas não pode tirar 10."""
    n = 20
    gab = _gabarito(n)
    # Aluno respondeu (certo) só as 4 primeiras; resto em branco
    respostas = {i: (gab[str(i)] if i <= 4 else None) for i in range(1, n + 1)}
    img = CartaoSintetico(num_questoes=n).gerar(respostas)

    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    assert r['resumo']['acertos'] == 4
    nota = r['resumo']['nota_provisoria']
    assert nota == pytest.approx(4 / n * 10, abs=0.01), \
        f'nota {nota} deveria ser {4 / n * 10}'


def test_marcacao_dupla_exige_revisao():
    n = 20
    gab = _gabarito(n)
    respostas = _respostas_corretas(gab)
    img = CartaoSintetico(num_questoes=n).gerar(respostas, marcas_duplas={3: 'E'})

    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    q3 = next(q for q in r['questoes'] if q['numero'] == 3)
    assert q3['precisa_revisao']
    assert q3['alternativa_detectada'] is None
    assert r['status'] == STATUS_REVISAO
    assert r['resumo']['nota_confirmada'] is None


def test_marcacao_fraca_exige_revisao():
    n = 20
    gab = _gabarito(n)
    respostas = {i: (None if i == 5 else gab[str(i)]) for i in range(1, n + 1)}
    img = CartaoSintetico(num_questoes=n).gerar(respostas, marcas_fracas={5: 'B'})

    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    q5 = next(q for q in r['questoes'] if q['numero'] == 5)
    assert q5['precisa_revisao'], f'status inesperado: {q5["status"]}'
    assert r['status'] == STATUS_REVISAO


def test_questoes_pendentes_geram_recorte_para_revisao():
    n = 20
    gab = _gabarito(n)
    respostas = _respostas_corretas(gab)
    img = CartaoSintetico(num_questoes=n).gerar(respostas, marcas_duplas={7: 'E'})

    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    q7 = next(q for q in r['questoes'] if q['numero'] == 7)
    assert q7.get('recorte'), 'questão pendente deve incluir recorte da imagem'


def test_imagem_borrada_rejeitada_sem_nota():
    n = 20
    gab = _gabarito(n)
    img = CartaoSintetico(num_questoes=n).gerar(_respostas_corretas(gab))
    import cv2
    borrada = cv2.GaussianBlur(img, (51, 51), 0)

    r = CorrecaoPipeline().corrigir(borrada, gab, _layout(n))
    assert r['status'] == STATUS_REJEITADA
    assert r['resumo'] is None


def test_imagem_minuscula_rejeitada():
    n = 20
    gab = _gabarito(n)
    img = CartaoSintetico(num_questoes=n, largura=400, altura=560).gerar(
        _respostas_corretas(gab))
    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    assert r['status'] == STATUS_REJEITADA


def test_zero_falsos_positivos_em_condicoes_adversas():
    """Métrica crítica: em sombra/ruído/rotação, ou a leitura está certa,
    ou a questão vai para revisão. Nunca uma resposta automática errada."""
    n = 20
    gab = _gabarito(n)
    respostas = _respostas_corretas(gab)
    cenarios = [
        dict(sombra=True),
        dict(ruido=0.04),
        dict(rotacao_graus=2.0),
        dict(sombra=True, ruido=0.03, rotacao_graus=1.5),
    ]
    for cenario in cenarios:
        img = CartaoSintetico(num_questoes=n).gerar(respostas, **cenario)
        r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
        if r['status'] == STATUS_REJEITADA:
            continue  # rejeitar é aceitável; errar não
        fp = _falsos_positivos(r, respostas)
        assert fp == [], f'falsos positivos {fp} no cenário {cenario}'


def test_acuracia_minima_em_cartao_limpo():
    """Mede acurácia por questão num cartão limpo: >= 95% lidas corretamente."""
    n = 44
    gab = _gabarito(n)
    respostas = _respostas_corretas(gab)
    img = CartaoSintetico(num_questoes=n).gerar(respostas)

    r = CorrecaoPipeline().corrigir(img, gab, _layout(n))
    corretas = sum(
        1 for q in r['questoes']
        if not q['precisa_revisao'] and q['alternativa_detectada'] == respostas[q['numero']]
    )
    assert corretas / n >= 0.95, f'acurácia {corretas}/{n}'
    assert _falsos_positivos(r, respostas) == []
