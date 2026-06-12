"""API v2 de correção de provas.

Contrato estruturado, persistência com auditoria, revisão manual por questão
e exportação de notas da turma.

Endpoints (prefixo /api/v2):
- POST   /correcoes                      processa e salva uma correção
- GET    /correcoes?turma=X              histórico (resumo)
- GET    /correcoes/<id>                 correção completa
- PATCH  /correcoes/<id>/questoes/<n>    revisão manual de uma questão
- POST   /correcoes/<id>/confirmar       confirma a nota (bloqueado se houver pendência)
- POST   /correcoes/<id>/reprocessar     reexecuta o pipeline na imagem original
- GET    /correcoes/export?turma=X       exporta notas da turma em CSV
"""

import base64
import csv
import io
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import cv2
import numpy as np
from flask import Blueprint, Response, jsonify, request

from src.ai_omr import resultado_por_ia
from src.models.correcao import Correcao
from src.models.user import db
from src.omr import LayoutProva
from src.omr.classifier import STATUS_OK, STATUS_EM_BRANCO
from src.omr.pipeline import STATUS_APROVADA, STATUS_REVISAO, STATUS_REJEITADA
from src.routes.auth import requer_login

logger = logging.getLogger('api.correcao')

correcao_bp = Blueprint('correcao', __name__)

STORAGE_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'storage')
STATUS_CONFIRMADA = 'CONFIRMADA'


def _erro(mensagem: str, codigo: str, http: int):
    return jsonify({'erro': mensagem, 'codigo': codigo}), http


def _decodificar_imagem(imagem_b64: str):
    """Decodifica imagem base64 (com ou sem prefixo data:) em ndarray BGR."""
    if ',' in imagem_b64 and imagem_b64.strip().startswith('data:'):
        imagem_b64 = imagem_b64.split(',', 1)[1]
    image_bytes = base64.b64decode(imagem_b64)
    nparr = np.frombuffer(image_bytes, np.uint8)
    return cv2.imdecode(nparr, cv2.IMREAD_COLOR)


def _salvar_imagem(image, sufixo: str) -> str:
    os.makedirs(STORAGE_DIR, exist_ok=True)
    nome = f'{uuid.uuid4().hex}_{sufixo}.jpg'
    caminho = os.path.join(STORAGE_DIR, nome)
    cv2.imwrite(caminho, image)
    return caminho


def _validar_gabarito(gabarito, alternativas):
    if not isinstance(gabarito, dict) or not gabarito:
        return 'Gabarito oficial é obrigatório e não pode estar vazio.'
    for chave, valor in gabarito.items():
        if not str(chave).isdigit():
            return f"Chave de questão inválida no gabarito: '{chave}'."
        if valor not in alternativas:
            return (f"Questão {chave}: resposta '{valor}' inválida. "
                    f"Use: {', '.join(alternativas)}.")
    return None


def _recalcular_resumo(resultado: dict, revisoes: dict) -> dict:
    """Recalcula acertos/nota aplicando as revisões manuais por cima da leitura."""
    gabarito = resultado.get('gabarito_usado', {})
    total = resultado['resumo']['total_questoes']
    acertos = erros = em_branco = pendentes = 0

    for q in resultado['questoes']:
        numero = str(q['numero'])
        if numero in revisoes:
            resposta = revisoes[numero]['alternativa']  # None = em branco confirmado
            if resposta is None:
                em_branco += 1
                erros += 1
            elif resposta == gabarito.get(numero):
                acertos += 1
            else:
                erros += 1
        elif q['precisa_revisao']:
            pendentes += 1
        elif q['status'] == STATUS_EM_BRANCO:
            em_branco += 1
            erros += 1
        else:
            acertos += int(bool(q['acertou']))
            erros += int(not q['acertou'])

    nota = round(acertos / total * 10, 2) if total else 0.0
    return {
        'total_questoes': total,
        'acertos': acertos,
        'erros': erros,
        'em_branco': em_branco,
        'pendentes_revisao': pendentes,
        'nota_provisoria': nota,
        'nota_maxima_possivel': round((acertos + pendentes) / total * 10, 2) if total else 0.0,
        'nota_confirmada': nota if pendentes == 0 else None,
    }


@correcao_bp.route('/correcoes', methods=['POST'])
@requer_login
def criar_correcao():
    data = request.get_json(silent=True)
    if not data:
        return _erro('Corpo JSON ausente ou inválido.', 'PAYLOAD_INVALIDO', 400)
    if 'imagem' not in data:
        return _erro('Campo "imagem" (base64) é obrigatório.', 'IMAGEM_AUSENTE', 400)

    layout = LayoutProva.from_dict(data.get('layout'))
    gabarito = data.get('gabarito_oficial') or {}
    erro_gabarito = _validar_gabarito(gabarito, layout.alternativas)
    if erro_gabarito:
        return _erro(erro_gabarito, 'GABARITO_INVALIDO', 400)
    layout.num_questoes = max(int(k) for k in gabarito.keys())

    try:
        image = _decodificar_imagem(data['imagem'])
    except Exception:
        return _erro('Não foi possível decodificar a imagem base64.', 'IMAGEM_INVALIDA', 400)
    if image is None:
        return _erro('Formato de imagem não suportado.', 'IMAGEM_INVALIDA', 400)

    try:
        resultado = resultado_por_ia(image, gabarito, layout)
    except Exception as exc:
        logger.exception('Falha na leitura por IA')
        return _erro(
            f'Nao foi possivel corrigir com IA: {exc}',
            'IA_CORRECAO_FALHOU',
            503,
        )

    # Auditoria: salva imagem original sempre (permite reprocessar depois)
    caminho_original = _salvar_imagem(image, 'original')

    correcao = Correcao(
        professor_id=request.usuario_atual.id,
        turma=str(data.get('turma') or 'sem_turma'),
        aluno=str(data.get('aluno') or 'sem_nome'),
        status=resultado['status'],
        gabarito_json=json.dumps(gabarito),
        resultado_json=json.dumps(resultado),
        nota_provisoria=(resultado['resumo'] or {}).get('nota_provisoria'),
        nota_final=None,
        imagem_original_path=caminho_original,
    )
    # Nota só é final automaticamente quando não há nenhuma pendência
    if resultado['status'] == STATUS_APROVADA:
        correcao.nota_final = resultado['resumo']['nota_confirmada']
        correcao.status = STATUS_CONFIRMADA
        correcao.confirmada_em = datetime.now(timezone.utc)
        correcao.confirmada_por = 'sistema (correção automática íntegra)'

    db.session.add(correcao)
    db.session.commit()
    logger.info('Correção %s criada: status=%s aluno=%s turma=%s',
                correcao.id, correcao.status, correcao.aluno, correcao.turma)

    resposta = correcao.to_dict(incluir_resultado=True)
    http = 200 if resultado['status'] != STATUS_REJEITADA else 422
    return jsonify(resposta), http


@correcao_bp.route('/correcoes', methods=['GET'])
@requer_login
def listar_correcoes():
    consulta = Correcao.query
    turma = request.args.get('turma')
    if turma:
        consulta = consulta.filter_by(turma=turma)
    status = request.args.get('status')
    if status:
        consulta = consulta.filter_by(status=status)
    correcoes = consulta.order_by(Correcao.criada_em.desc()).limit(500).all()
    return jsonify({'correcoes': [c.to_dict() for c in correcoes]})


@correcao_bp.route('/correcoes/<int:correcao_id>', methods=['GET'])
@requer_login
def obter_correcao(correcao_id):
    correcao = db.session.get(Correcao, correcao_id)
    if correcao is None:
        return _erro('Correção não encontrada.', 'NAO_ENCONTRADA', 404)
    return jsonify(correcao.to_dict(incluir_resultado=True))


@correcao_bp.route('/correcoes/<int:correcao_id>/questoes/<int:numero>', methods=['PATCH'])
@requer_login
def revisar_questao(correcao_id, numero):
    """Professor define manualmente a resposta de UMA questão duvidosa."""
    correcao = db.session.get(Correcao, correcao_id)
    if correcao is None:
        return _erro('Correção não encontrada.', 'NAO_ENCONTRADA', 404)
    if correcao.status == STATUS_CONFIRMADA:
        return _erro('Correção já confirmada; não pode mais ser alterada.',
                     'JA_CONFIRMADA', 409)

    data = request.get_json(silent=True) or {}
    if 'alternativa' not in data:
        return _erro('Campo "alternativa" é obrigatório (use null para em branco).',
                     'PAYLOAD_INVALIDO', 400)
    alternativa = data['alternativa']

    resultado = correcao.resultado
    numeros_validos = {q['numero'] for q in resultado.get('questoes', [])}
    if numero not in numeros_validos:
        return _erro(f'Questão {numero} não existe nesta correção.', 'QUESTAO_INVALIDA', 400)

    alternativas_validas = sorted({a for q in resultado['questoes']
                                   for a in (q.get('preenchimentos') or {})}) or \
                           ['A', 'B', 'C', 'D', 'E']
    if alternativa is not None and alternativa not in alternativas_validas:
        return _erro(f"Alternativa '{alternativa}' inválida.", 'ALTERNATIVA_INVALIDA', 400)

    revisoes = correcao.revisoes
    revisoes[str(numero)] = {
        'alternativa': alternativa,
        'revisado_por': request.usuario_atual.email,
        'revisado_em': datetime.now(timezone.utc).isoformat(),
    }
    correcao.revisoes_json = json.dumps(revisoes)

    resumo = _recalcular_resumo(resultado, revisoes)
    resultado['resumo'] = resumo
    correcao.resultado_json = json.dumps(resultado)
    correcao.nota_provisoria = resumo['nota_provisoria']
    db.session.commit()

    return jsonify({'questao': numero, 'revisao': revisoes[str(numero)], 'resumo': resumo})


@correcao_bp.route('/correcoes/<int:correcao_id>/confirmar', methods=['POST'])
@requer_login
def confirmar_correcao(correcao_id):
    """Confirma a nota final. BLOQUEADO enquanto houver questão pendente."""
    correcao = db.session.get(Correcao, correcao_id)
    if correcao is None:
        return _erro('Correção não encontrada.', 'NAO_ENCONTRADA', 404)
    if correcao.status == STATUS_CONFIRMADA:
        return _erro('Correção já confirmada.', 'JA_CONFIRMADA', 409)
    if correcao.status == STATUS_REJEITADA:
        return _erro('Correção rejeitada por qualidade de imagem; refaça a captura.',
                     'REJEITADA_QUALIDADE', 409)

    resultado = correcao.resultado
    resumo = _recalcular_resumo(resultado, correcao.revisoes)
    if resumo['pendentes_revisao'] > 0:
        return _erro(
            f"Há {resumo['pendentes_revisao']} questão(ões) pendente(s) de revisão "
            'manual. Revise todas antes de confirmar a nota.',
            'PENDENCIAS_DE_REVISAO', 409,
        )

    correcao.nota_final = resumo['nota_confirmada']
    correcao.status = STATUS_CONFIRMADA
    correcao.confirmada_em = datetime.now(timezone.utc)
    correcao.confirmada_por = request.usuario_atual.email
    resultado['resumo'] = resumo
    correcao.resultado_json = json.dumps(resultado)
    db.session.commit()

    logger.info('Correção %s confirmada por %s: nota=%.2f',
                correcao.id, correcao.confirmada_por, correcao.nota_final)
    return jsonify(correcao.to_dict())


@correcao_bp.route('/correcoes/<int:correcao_id>/reprocessar', methods=['POST'])
@requer_login
def reprocessar_correcao(correcao_id):
    """Reexecuta o pipeline na imagem original (ex.: após melhoria do algoritmo)."""
    correcao = db.session.get(Correcao, correcao_id)
    if correcao is None:
        return _erro('Correção não encontrada.', 'NAO_ENCONTRADA', 404)
    if correcao.status == STATUS_CONFIRMADA:
        return _erro('Correção confirmada não pode ser reprocessada.', 'JA_CONFIRMADA', 409)
    if not correcao.imagem_original_path or not os.path.exists(correcao.imagem_original_path):
        return _erro('Imagem original não está mais disponível.', 'IMAGEM_INDISPONIVEL', 410)

    image = cv2.imread(correcao.imagem_original_path)
    gabarito = correcao.gabarito
    layout = LayoutProva(num_questoes=max(int(k) for k in gabarito.keys()))
    try:
        resultado = resultado_por_ia(image, gabarito, layout)
    except Exception as exc:
        logger.exception('Falha ao reprocessar por IA')
        return _erro(
            f'Nao foi possivel reprocessar com IA: {exc}',
            'IA_CORRECAO_FALHOU',
            503,
        )

    correcao.resultado_json = json.dumps(resultado)
    correcao.revisoes_json = None  # leitura mudou; revisões antigas não valem mais
    correcao.status = resultado['status']
    correcao.nota_provisoria = (resultado['resumo'] or {}).get('nota_provisoria')
    db.session.commit()
    return jsonify(correcao.to_dict(incluir_resultado=True))


@correcao_bp.route('/correcoes/export', methods=['GET'])
@requer_login
def exportar_notas():
    """Exporta as notas da turma em CSV (uma linha por correção)."""
    turma = request.args.get('turma')
    consulta = Correcao.query
    if turma:
        consulta = consulta.filter_by(turma=turma)
    correcoes = consulta.order_by(Correcao.aluno.asc(), Correcao.criada_em.desc()).all()

    buffer = io.StringIO()
    writer = csv.writer(buffer, delimiter=';')
    writer.writerow(['turma', 'aluno', 'status', 'nota_final', 'nota_provisoria',
                     'acertos', 'erros', 'em_branco', 'pendentes_revisao',
                     'criada_em', 'confirmada_em', 'confirmada_por'])
    for c in correcoes:
        resumo = (c.resultado or {}).get('resumo') or {}
        writer.writerow([
            c.turma, c.aluno, c.status,
            c.nota_final if c.nota_final is not None else '',
            c.nota_provisoria if c.nota_provisoria is not None else '',
            resumo.get('acertos', ''), resumo.get('erros', ''),
            resumo.get('em_branco', ''), resumo.get('pendentes_revisao', ''),
            c.criada_em.isoformat() if c.criada_em else '',
            c.confirmada_em.isoformat() if c.confirmada_em else '',
            c.confirmada_por or '',
        ])

    nome = f"notas_{turma or 'todas'}_{datetime.now().strftime('%Y%m%d_%H%M')}.csv"
    return Response(
        buffer.getvalue().encode('utf-8-sig'),  # BOM para abrir certo no Excel
        mimetype='text/csv',
        headers={'Content-Disposition': f'attachment; filename="{nome}"'},
    )
