"""Modelo de persistência das correções (histórico, auditoria, revisão)."""

import json
from datetime import datetime, timezone

from .user import db


class Correcao(db.Model):
    __tablename__ = 'correcoes'

    id = db.Column(db.Integer, primary_key=True)
    professor_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    turma = db.Column(db.String(80), nullable=False)
    aluno = db.Column(db.String(120), nullable=False)

    # Status: APROVADA_AUTOMATICA | PRECISA_REVISAO | CONFIRMADA | REJEITADA_QUALIDADE
    status = db.Column(db.String(40), nullable=False)

    gabarito_json = db.Column(db.Text, nullable=False)        # gabarito oficial usado
    resultado_json = db.Column(db.Text, nullable=False)       # resultado completo do pipeline
    revisoes_json = db.Column(db.Text, nullable=True)         # alterações manuais do professor

    nota_provisoria = db.Column(db.Float, nullable=True)
    nota_final = db.Column(db.Float, nullable=True)            # só preenchida ao confirmar

    imagem_original_path = db.Column(db.String(255), nullable=True)
    imagem_processada_path = db.Column(db.String(255), nullable=True)

    criada_em = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    confirmada_em = db.Column(db.DateTime, nullable=True)
    confirmada_por = db.Column(db.String(120), nullable=True)
    versao_algoritmo = db.Column(db.String(20), default='4.0')

    # ---- helpers JSON ----
    @property
    def gabarito(self):
        return json.loads(self.gabarito_json) if self.gabarito_json else {}

    @property
    def resultado(self):
        return json.loads(self.resultado_json) if self.resultado_json else {}

    @property
    def revisoes(self):
        return json.loads(self.revisoes_json) if self.revisoes_json else {}

    def to_dict(self, incluir_resultado: bool = False):
        d = {
            'id': self.id,
            'professor_id': self.professor_id,
            'turma': self.turma,
            'aluno': self.aluno,
            'status': self.status,
            'nota_provisoria': self.nota_provisoria,
            'nota_final': self.nota_final,
            'criada_em': self.criada_em.isoformat() if self.criada_em else None,
            'confirmada_em': self.confirmada_em.isoformat() if self.confirmada_em else None,
            'confirmada_por': self.confirmada_por,
            'versao_algoritmo': self.versao_algoritmo,
            'revisoes': self.revisoes,
        }
        if incluir_resultado:
            d['resultado'] = self.resultado
            d['gabarito'] = self.gabarito
        return d
