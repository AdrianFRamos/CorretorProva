"""Pré-processamento: normalização de iluminação, detecção da folha,
correção de perspectiva e binarização adaptativa.
"""

import cv2
import numpy as np
from dataclasses import dataclass
from typing import Optional, Tuple

# A folha precisa ocupar uma fração mínima da foto para o quadrilátero ser confiável
AREA_MINIMA_FOLHA = 0.25
LARGURA_PADRAO = 1200  # largura de trabalho após o warp


@dataclass
class ResultadoPreprocessamento:
    imagem_corrigida: np.ndarray        # BGR, perspectiva corrigida
    imagem_binaria: np.ndarray          # binária invertida (marcações = branco)
    folha_detectada: bool
    metodo: str                          # 'quadrilatero' | 'imagem_completa'


def _ordenar_pontos(pts: np.ndarray) -> np.ndarray:
    """Ordena 4 pontos: top-left, top-right, bottom-right, bottom-left."""
    rect = np.zeros((4, 2), dtype='float32')
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect


def normalizar_iluminacao(gray: np.ndarray) -> np.ndarray:
    """Remove gradientes de sombra dividindo pela estimativa do fundo.

    O fundo (papel) é estimado com fechamento morfológico de kernel grande;
    a divisão aplaina sombras e iluminação desigual sem apagar as marcações.
    """
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (51, 51))
    fundo = cv2.morphologyEx(gray, cv2.MORPH_CLOSE, kernel)
    fundo = np.where(fundo == 0, 1, fundo)
    normalizada = cv2.divide(gray, fundo, scale=255)
    return cv2.normalize(normalizada, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)


def _encontrar_quadrilatero_folha(gray: np.ndarray) -> Optional[np.ndarray]:
    """Procura o contorno quadrilátero da folha. Retorna 4 pontos ou None.

    Diferente da versão antiga, valida área mínima e convexidade em vez de
    assumir cegamente que o maior contorno é a folha.
    """
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    bordas = cv2.Canny(blur, 50, 150)
    bordas = cv2.dilate(bordas, np.ones((3, 3), np.uint8), iterations=2)

    contornos, _ = cv2.findContours(bordas, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contornos:
        return None

    area_imagem = gray.shape[0] * gray.shape[1]
    for c in sorted(contornos, key=cv2.contourArea, reverse=True)[:5]:
        area = cv2.contourArea(c)
        if area < AREA_MINIMA_FOLHA * area_imagem:
            break  # contornos seguintes são menores ainda
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        if len(approx) == 4 and cv2.isContourConvex(approx):
            return approx.reshape(4, 2).astype(np.float32)
    return None


def _warp(image: np.ndarray, quad: np.ndarray) -> np.ndarray:
    rect = _ordenar_pontos(quad)
    (tl, tr, br, bl) = rect
    largura = max(int(np.linalg.norm(br - bl)), int(np.linalg.norm(tr - tl)))
    altura = max(int(np.linalg.norm(tr - br)), int(np.linalg.norm(tl - bl)))
    dst = np.array([[0, 0], [largura - 1, 0], [largura - 1, altura - 1], [0, altura - 1]],
                   dtype='float32')
    m = cv2.getPerspectiveTransform(rect, dst)
    return cv2.warpPerspective(image, m, (largura, altura))


def binarizar(gray: np.ndarray) -> np.ndarray:
    """Binarização adaptativa (robusta a sombra residual). Marcações ficam brancas."""
    suave = cv2.GaussianBlur(gray, (5, 5), 0)
    binaria = cv2.adaptiveThreshold(
        suave, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV, blockSize=51, C=12,
    )
    # Abre para remover ruído pontual (sal e pimenta)
    return cv2.morphologyEx(binaria, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))


def preprocessar(image: np.ndarray) -> ResultadoPreprocessamento:
    """Pipeline completo de pré-processamento."""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # A borda da folha é procurada no cinza ORIGINAL: a normalização de
    # iluminação aplaina o contraste folha/fundo e apagaria a borda.
    quad = _encontrar_quadrilatero_folha(gray)
    if quad is not None:
        corrigida = _warp(image, quad)
        folha_detectada = True
        metodo = 'quadrilatero'
    else:
        # Foto provavelmente já enquadrada na folha: segue sem warp,
        # mas o pipeline registra isso e reduz a confiança global.
        corrigida = image.copy()
        folha_detectada = False
        metodo = 'imagem_completa'

    # Redimensiona para largura de trabalho padronizada (estabiliza thresholds)
    escala = LARGURA_PADRAO / corrigida.shape[1]
    corrigida = cv2.resize(corrigida, None, fx=escala, fy=escala,
                           interpolation=cv2.INTER_AREA if escala < 1 else cv2.INTER_CUBIC)

    gray_corr = cv2.cvtColor(corrigida, cv2.COLOR_BGR2GRAY)
    gray_corr = normalizar_iluminacao(gray_corr)
    binaria = binarizar(gray_corr)

    return ResultadoPreprocessamento(
        imagem_corrigida=corrigida,
        imagem_binaria=binaria,
        folha_detectada=folha_detectada,
        metodo=metodo,
    )
