"""Autenticação de professores (cadastro, login e proteção de rotas).

Usa tokens assinados com itsdangerous (já presente nas dependências do Flask),
com expiração de 12 horas.
"""

from functools import wraps

from flask import Blueprint, current_app, jsonify, request
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from src.models.user import User, db

auth_bp = Blueprint('auth', __name__)

TOKEN_VALIDADE_SEGUNDOS = 12 * 3600


def _serializer():
    return URLSafeTimedSerializer(current_app.config['SECRET_KEY'], salt='auth-token')


def gerar_token(user: User) -> str:
    return _serializer().dumps({'id': user.id, 'email': user.email})


def requer_login(f):
    """Decorator: exige header Authorization: Bearer <token>."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        header = request.headers.get('Authorization', '')
        if not header.startswith('Bearer '):
            return jsonify({'erro': 'Token de autenticação ausente.',
                            'codigo': 'NAO_AUTENTICADO'}), 401
        try:
            dados = _serializer().loads(header[7:], max_age=TOKEN_VALIDADE_SEGUNDOS)
        except SignatureExpired:
            return jsonify({'erro': 'Sessão expirada. Faça login novamente.',
                            'codigo': 'TOKEN_EXPIRADO'}), 401
        except BadSignature:
            return jsonify({'erro': 'Token inválido.', 'codigo': 'TOKEN_INVALIDO'}), 401

        user = db.session.get(User, dados.get('id'))
        if user is None:
            return jsonify({'erro': 'Usuário não encontrado.', 'codigo': 'TOKEN_INVALIDO'}), 401
        request.usuario_atual = user
        return f(*args, **kwargs)
    return wrapper


@auth_bp.route('/registrar', methods=['POST'])
def registrar():
    data = request.get_json(silent=True) or {}
    nome = (data.get('nome') or '').strip()
    email = (data.get('email') or '').strip().lower()
    senha = data.get('senha') or ''

    if not nome or not email or len(senha) < 6:
        return jsonify({'erro': 'Informe nome, email e senha (mínimo 6 caracteres).',
                        'codigo': 'DADOS_INVALIDOS'}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({'erro': 'Já existe uma conta com este email.',
                        'codigo': 'EMAIL_EM_USO'}), 409

    user = User(username=nome, email=email)
    user.set_password(senha)
    db.session.add(user)
    db.session.commit()
    return jsonify({'token': gerar_token(user), 'usuario': user.to_dict()}), 201


@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip().lower()
    senha = data.get('senha') or ''

    user = User.query.filter_by(email=email).first()
    if user is None or not user.check_password(senha):
        return jsonify({'erro': 'Email ou senha incorretos.',
                        'codigo': 'CREDENCIAIS_INVALIDAS'}), 401
    return jsonify({'token': gerar_token(user), 'usuario': user.to_dict()})
