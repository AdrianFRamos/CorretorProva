"""Validação de qualidade da imagem antes de qualquer tentativa de correção.

Uma imagem reprovada aqui NUNCA chega ao corretor automático — o professor
recebe o motivo e orientação para capturar novamente.
"""

import cv2
import numpy as np
from dataclasses import dataclass, field
from typing import List

# Limites mínimos calibrados para cartões A4 fotografados com celular
RESOLUCAO_MINIMA = 600           # menor lado em pixels
NITIDEZ_MINIMA = 60.0            # variância do Laplaciano (borrado < 60)
BRILHO_MINIMO = 50.0             # média de cinza (0-255)
BRILHO_MAXIMO = 235.0
CONTRASTE_MINIMO = 25.0          # desvio padrão de cinza
SOMBRA_MAX_DESVIO = 90.0         # desvio entre blocos de iluminação


@dataclass
class ResultadoQualidade:
    aprovada: bool = True
    nitidez: float = 0.0
    brilho: float = 0.0
    contraste: float = 0.0
    desvio_iluminacao: float = 0.0
    largura: int = 0
    altura: int = 0
    problemas: List[str] = field(default_factory=list)

    def to_dict(self):
        return {
            'aprovada': self.aprovada,
            'nitidez': round(self.nitidez, 1),
            'brilho': round(self.brilho, 1),
            'contraste': round(self.contraste, 1),
            'desvio_iluminacao': round(self.desvio_iluminacao, 1),
            'resolucao': [self.largura, self.altura],
            'problemas': self.problemas,
        }


def validar_imagem(image: np.ndarray) -> ResultadoQualidade:
    """Valida nitidez, iluminação, contraste e resolução da imagem."""
    r = ResultadoQualidade()
    r.altura, r.largura = image.shape[:2]

    if min(r.largura, r.altura) < RESOLUCAO_MINIMA:
        r.problemas.append(
            f'Resolução insuficiente ({r.largura}x{r.altura}). '
            f'O menor lado deve ter pelo menos {RESOLUCAO_MINIMA}px.'
        )

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY) if image.ndim == 3 else image

    # Nitidez: variância do Laplaciano (medida clássica de foco)
    r.nitidez = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    if r.nitidez < NITIDEZ_MINIMA:
        r.problemas.append(
            'Imagem desfocada/borrada. Refaça a foto mantendo o celular estável '
            'e aguarde o foco automático.'
        )

    # Iluminação global
    r.brilho = float(gray.mean())
    if r.brilho < BRILHO_MINIMO:
        r.problemas.append('Imagem muito escura. Fotografe em ambiente mais iluminado.')
    elif r.brilho > BRILHO_MAXIMO:
        r.problemas.append('Imagem estourada/clara demais. Evite flash direto ou luz forte refletida.')

    r.contraste = float(gray.std())
    if r.contraste < CONTRASTE_MINIMO:
        r.problemas.append('Contraste muito baixo. Verifique iluminação e foco.')

    # Iluminação desigual (sombra forte): compara brilho médio de blocos 4x4
    h, w = gray.shape
    blocos = [
        gray[i * h // 4:(i + 1) * h // 4, j * w // 4:(j + 1) * w // 4].mean()
        for i in range(4) for j in range(4)
    ]
    r.desvio_iluminacao = float(max(blocos) - min(blocos))
    if r.desvio_iluminacao > SOMBRA_MAX_DESVIO:
        # Sombra não reprova sozinha (o pré-processamento normaliza), mas é registrada
        r.problemas.append(
            'Iluminação desigual/sombra detectada. O sistema tentará compensar, '
            'mas questões nessa região podem exigir revisão manual.'
        )

    # Só os problemas estruturais reprovam; sombra é apenas aviso
    problemas_bloqueantes = [p for p in r.problemas if not p.startswith('Iluminação desigual')]
    r.aprovada = len(problemas_bloqueantes) == 0
    return r
