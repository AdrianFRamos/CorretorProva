"""Gerador de cartões-resposta sintéticos para testes e medição de acurácia.

Permite simular: marcação normal, fraca, dupla, em branco, rotação leve,
sombra e ruído — cobrindo os cenários reais de fotos de prova.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional

import cv2
import numpy as np


@dataclass
class CartaoSintetico:
    num_questoes: int = 20
    num_alternativas: int = 5
    num_colunas: int = 2
    largura: int = 1240
    altura: int = 1754  # proporção A4
    alternativas: List[str] = field(default_factory=lambda: ['A', 'B', 'C', 'D', 'E'])

    def gerar(self,
              respostas: Dict[int, Optional[str]],
              marcas_fracas: Optional[Dict[int, str]] = None,
              marcas_duplas: Optional[Dict[int, str]] = None,
              rotacao_graus: float = 0.0,
              sombra: bool = False,
              ruido: float = 0.0,
              com_borda_folha: bool = True) -> np.ndarray:
        """Gera a imagem BGR do cartão preenchido.

        respostas: {questao: 'A'..'E' ou None (em branco)}
        marcas_fracas: questões com preenchimento parcial (~30%)
        marcas_duplas: segunda alternativa pintada além da resposta
        """
        marcas_fracas = marcas_fracas or {}
        marcas_duplas = marcas_duplas or {}

        img = np.full((self.altura, self.largura, 3), 255, np.uint8)
        questoes_por_coluna = -(-self.num_questoes // self.num_colunas)

        margem_topo = int(self.altura * 0.12)
        margem_base = int(self.altura * 0.05)
        cv2.putText(img, 'CARTAO RESPOSTA', (int(self.largura * 0.3), int(self.altura * 0.06)),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 0), 2)

        raio = 14
        for col in range(self.num_colunas):
            x0 = int(col * self.largura / self.num_colunas)
            x1 = int((col + 1) * self.largura / self.num_colunas)
            area_x0 = x0 + int((x1 - x0) * 0.30)
            area_x1 = x1 - int((x1 - x0) * 0.08)
            passo_y = (self.altura - margem_topo - margem_base) / questoes_por_coluna
            passo_x = (area_x1 - area_x0) / self.num_alternativas

            for i in range(questoes_por_coluna):
                numero = col * questoes_por_coluna + i + 1
                if numero > self.num_questoes:
                    break
                cy = int(margem_topo + (i + 0.5) * passo_y)
                cv2.putText(img, f'{numero:02d}', (x0 + int((x1 - x0) * 0.10), cy + 8),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)

                for j, alt in enumerate(self.alternativas):
                    cx = int(area_x0 + (j + 0.5) * passo_x)
                    cv2.circle(img, (cx, cy), raio, (60, 60, 60), 2)  # anel impresso

                    marcada = respostas.get(numero) == alt
                    dupla = marcas_duplas.get(numero) == alt
                    fraca = marcas_fracas.get(numero) == alt
                    if fraca:
                        cv2.circle(img, (cx, cy), int(raio * 0.5), (40, 40, 40), -1)
                    elif marcada or dupla:
                        cv2.circle(img, (cx, cy), raio - 2, (20, 20, 20), -1)

        if sombra:
            grad = np.tile(np.linspace(1.0, 0.55, self.largura), (self.altura, 1))
            img = (img * grad[..., None]).astype(np.uint8)

        if ruido > 0:
            n = np.random.default_rng(42).normal(0, ruido * 255, img.shape)
            img = np.clip(img.astype(np.float64) + n, 0, 255).astype(np.uint8)

        if abs(rotacao_graus) > 0.01:
            m = cv2.getRotationMatrix2D((self.largura / 2, self.altura / 2), rotacao_graus, 1.0)
            img = cv2.warpAffine(img, m, (self.largura, self.altura),
                                 borderValue=(255, 255, 255))

        if com_borda_folha:
            # Coloca a folha sobre um fundo escuro (simula a mesa) com perspectiva leve
            fundo = np.full((int(self.altura * 1.25), int(self.largura * 1.25), 3), 40, np.uint8)
            ox = int(self.largura * 0.12)
            oy = int(self.altura * 0.12)
            fundo[oy:oy + self.altura, ox:ox + self.largura] = img
            img = fundo

        return img
