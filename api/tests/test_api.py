"""Testes de contrato da API v2: autenticação, correção, revisão, confirmação,
bloqueios de segurança e exportação CSV."""

import base64
import json

import cv2
import pytest

from tests.synthetic import CartaoSintetico

ALTS = ['A', 'B', 'C', 'D', 'E']


@pytest.fixture()
def app(tmp_path, monkeypatch):
    import src.routes.correcao as rc
    monkeypatch.setattr(rc, 'STORAGE_DIR', str(tmp_path / 'storage'))

    # O conftest define DATABASE_URL para um sqlite temporário antes do import
    from src.main import app as flask_app
    from src.models.user import db
    flask_app.config.update(TESTING=True)
    with flask_app.app_context():
        db.drop_all()
        db.create_all()
    yield flask_app


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def token(client):
    r = client.post('/api/v2/auth/registrar', json={
        'nome': 'Professor Teste', 'email': 'prof@escola.com', 'senha': 'segredo123',
    })
    assert r.status_code == 201, r.get_json()
    return r.get_json()['token']


def _auth(token):
    return {'Authorization': f'Bearer {token}'}


def _gabarito(n):
    return {str(i): ALTS[(i - 1) % 5] for i in range(1, n + 1)}


def _imagem_b64(n=20, **kwargs):
    respostas = kwargs.pop('respostas', {i: ALTS[(i - 1) % 5] for i in range(1, n + 1)})
    img = CartaoSintetico(num_questoes=n).gerar(respostas, **kwargs)
    ok, buf = cv2.imencode('.jpg', img)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf).decode()


def _payload(n=20, **kwargs):
    return {
        'turma': '1N', 'aluno': 'Aluno Teste',
        'imagem': _imagem_b64(n, **kwargs),
        'gabarito_oficial': _gabarito(n),
        'layout': {'num_questoes': n, 'num_alternativas': 5, 'num_colunas': 2},
    }


# ---------- autenticação ----------

def test_correcao_exige_autenticacao(client):
    r = client.post('/api/v2/correcoes', json=_payload())
    assert r.status_code == 401


def test_login_invalido(client, token):
    r = client.post('/api/v2/auth/login',
                    json={'email': 'prof@escola.com', 'senha': 'errada'})
    assert r.status_code == 401
    assert r.get_json()['codigo'] == 'CREDENCIAIS_INVALIDAS'


def test_login_valido(client, token):
    r = client.post('/api/v2/auth/login',
                    json={'email': 'prof@escola.com', 'senha': 'segredo123'})
    assert r.status_code == 200
    assert 'token' in r.get_json()


# ---------- correção ----------

def test_correcao_completa_confirma_automaticamente(client, token):
    r = client.post('/api/v2/correcoes', json=_payload(), headers=_auth(token))
    assert r.status_code == 200, r.get_json()
    corpo = r.get_json()
    assert corpo['status'] == 'CONFIRMADA'
    assert corpo['nota_final'] == 10.0
    assert corpo['resultado']['resumo']['pendentes_revisao'] == 0


def test_gabarito_invalido_rejeitado(client, token):
    payload = _payload()
    payload['gabarito_oficial']['3'] = 'X'
    r = client.post('/api/v2/correcoes', json=payload, headers=_auth(token))
    assert r.status_code == 400
    assert r.get_json()['codigo'] == 'GABARITO_INVALIDO'


def test_imagem_invalida_rejeitada(client, token):
    payload = _payload()
    payload['imagem'] = 'data:image/jpeg;base64,QUJDRA=='
    r = client.post('/api/v2/correcoes', json=payload, headers=_auth(token))
    assert r.status_code == 400


def test_fluxo_revisao_e_confirmacao(client, token):
    # cartão com marcação dupla na questão 3 → pendência
    payload = _payload(marcas_duplas={3: 'E'})
    r = client.post('/api/v2/correcoes', json=payload, headers=_auth(token))
    corpo = r.get_json()
    assert corpo['status'] == 'PRECISA_REVISAO'
    assert corpo['nota_final'] is None
    cid = corpo['id']

    # confirmar antes de revisar deve ser BLOQUEADO
    r = client.post(f'/api/v2/correcoes/{cid}/confirmar', headers=_auth(token))
    assert r.status_code == 409
    assert r.get_json()['codigo'] == 'PENDENCIAS_DE_REVISAO'

    # professor revisa a questão 3 (decide que a resposta válida é a correta)
    gab = _gabarito(20)
    r = client.patch(f'/api/v2/correcoes/{cid}/questoes/3',
                     json={'alternativa': gab['3']}, headers=_auth(token))
    assert r.status_code == 200
    assert r.get_json()['resumo']['pendentes_revisao'] == 0

    # agora a confirmação passa e registra auditoria
    r = client.post(f'/api/v2/correcoes/{cid}/confirmar', headers=_auth(token))
    assert r.status_code == 200
    corpo = r.get_json()
    assert corpo['status'] == 'CONFIRMADA'
    assert corpo['nota_final'] == 10.0
    assert corpo['confirmada_por'] == 'prof@escola.com'
    assert corpo['confirmada_em'] is not None

    # correção confirmada não pode mais ser alterada
    r = client.patch(f'/api/v2/correcoes/{cid}/questoes/3',
                     json={'alternativa': 'A'}, headers=_auth(token))
    assert r.status_code == 409


def test_historico_e_export_csv(client, token):
    client.post('/api/v2/correcoes', json=_payload(), headers=_auth(token))

    r = client.get('/api/v2/correcoes?turma=1N', headers=_auth(token))
    assert r.status_code == 200
    assert len(r.get_json()['correcoes']) == 1

    r = client.get('/api/v2/correcoes/export?turma=1N', headers=_auth(token))
    assert r.status_code == 200
    assert 'text/csv' in r.content_type
    linhas = r.data.decode('utf-8-sig').strip().splitlines()
    assert linhas[0].startswith('turma;aluno;status')
    assert len(linhas) == 2
