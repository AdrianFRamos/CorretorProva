"""Testes do classificador: regras de segurança por questão."""

import pytest

from src.omr.classifier import (
    STATUS_AMBIGUA, STATUS_EM_BRANCO, STATUS_FRACA, STATUS_MULTIPLA,
    STATUS_NAO_LIDA, STATUS_OK, classificar_questao,
)


def test_marcacao_unica_forte_e_ok():
    q = classificar_questao(1, {'A': 0.85, 'B': 0.05, 'C': 0.04, 'D': 0.06, 'E': 0.05})
    assert q.status == STATUS_OK
    assert q.alternativa == 'A'
    assert q.confianca >= 0.7
    assert not q.precisa_revisao


def test_em_branco_detectado():
    q = classificar_questao(2, {'A': 0.08, 'B': 0.06, 'C': 0.07, 'D': 0.05, 'E': 0.09})
    assert q.status == STATUS_EM_BRANCO
    assert q.alternativa is None
    assert not q.precisa_revisao


def test_multipla_marcacao_vai_para_revisao():
    q = classificar_questao(3, {'A': 0.80, 'B': 0.75, 'C': 0.05, 'D': 0.05, 'E': 0.05})
    assert q.status == STATUS_MULTIPLA
    assert q.alternativa is None
    assert q.precisa_revisao


def test_marcacao_fraca_vai_para_revisao():
    q = classificar_questao(4, {'A': 0.30, 'B': 0.05, 'C': 0.05, 'D': 0.05, 'E': 0.05})
    assert q.status == STATUS_FRACA
    assert q.alternativa is None
    assert q.precisa_revisao


def test_ambiguidade_por_separacao_insuficiente():
    # Uma acima do limiar, outra logo abaixo: sistema NÃO pode escolher
    q = classificar_questao(5, {'A': 0.50, 'B': 0.40, 'C': 0.05, 'D': 0.05, 'E': 0.05})
    assert q.status in (STATUS_AMBIGUA, STATUS_MULTIPLA)
    assert q.alternativa is None
    assert q.precisa_revisao


def test_questao_nao_lida_vai_para_revisao():
    q = classificar_questao(6, None)
    assert q.status == STATUS_NAO_LIDA
    assert q.precisa_revisao


def test_nunca_escolhe_alternativa_em_caso_de_duvida():
    """Propriedade central: se status exige revisão, alternativa é sempre None."""
    casos = [
        {'A': 0.5, 'B': 0.45, 'C': 0, 'D': 0, 'E': 0},
        {'A': 0.9, 'B': 0.9, 'C': 0, 'D': 0, 'E': 0},
        {'A': 0.3, 'B': 0.1, 'C': 0, 'D': 0, 'E': 0},
        None,
    ]
    for i, caso in enumerate(casos, start=1):
        q = classificar_questao(i, caso)
        if q.precisa_revisao:
            assert q.alternativa is None, f'caso {caso} escolheu {q.alternativa}'
