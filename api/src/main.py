import logging
import os
import sys
# DON'T CHANGE THIS !!!
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from flask import Flask, send_from_directory
from flask_cors import CORS
from src.models.user import db
from src.models.correcao import Correcao  # noqa: F401 (registra a tabela)
from src.routes.user import user_bp
from src.routes.gabarito import gabarito_bp
from src.routes.auth import auth_bp
from src.routes.correcao import correcao_bp

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [%(name)s] %(message)s',
)

app = Flask(__name__, static_folder=os.path.join(os.path.dirname(__file__), 'static'))
# Em produção defina a variável de ambiente SECRET_KEY (Render → Environment)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-only-troque-em-producao')

# Configurar CORS para permitir requisições de qualquer origem
CORS(app)

app.register_blueprint(user_bp, url_prefix='/api')
app.register_blueprint(gabarito_bp, url_prefix='/api/gabarito')   # v1 (legado)
app.register_blueprint(auth_bp, url_prefix='/api/v2/auth')
app.register_blueprint(correcao_bp, url_prefix='/api/v2')

# DATABASE_URL permite apontar para outro banco (testes, produção)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL',
    f"sqlite:///{os.path.join(os.path.dirname(__file__), 'database', 'app.db')}",
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)
with app.app_context():
    db.create_all()
    # Migração leve: create_all não altera tabelas existentes, então bancos
    # antigos não têm a coluna password_hash em user. Adiciona se faltar.
    from sqlalchemy import inspect, text
    colunas = [c['name'] for c in inspect(db.engine).get_columns('user')]
    if 'password_hash' not in colunas:
        with db.engine.begin() as conn:
            conn.execute(text('ALTER TABLE user ADD COLUMN password_hash VARCHAR(255)'))

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    static_folder_path = app.static_folder
    if static_folder_path is None:
            return "Static folder not configured", 404

    if path != "" and os.path.exists(os.path.join(static_folder_path, path)):
        return send_from_directory(static_folder_path, path)
    else:
        index_path = os.path.join(static_folder_path, 'index.html')
        if os.path.exists(index_path):
            return send_from_directory(static_folder_path, 'index.html')
        else:
            return "index.html not found", 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
