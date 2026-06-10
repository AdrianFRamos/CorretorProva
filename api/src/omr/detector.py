"""Localização das bolhas do cartão-resposta.

Estratégia em duas camadas:
1. Detecção por contornos circulares (robusta a variações de layout): procura
   todos os círculos plausíveis e tenta organizá-los na grade esperada
   (questões x alternativas, em N colunas de questões).
2. Fallback de grade matemática configurável, usado quando a detecção por
   contornos não encontra uma grade consistente. O pipeline registra qual
   método foi usado — o fallback reduz a confiança e força revisão mais cedo.
"""

import cv2
import numpy as np
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple


@dataclass
class Bolha:
    questao: int
    alternativa: str
    cx: int
    cy: int
    raio: int


@dataclass
class ResultadoDeteccao:
    bolhas: List[Bolha] = field(default_factory=list)
    metodo: str = 'nenhum'          # 'contornos' | 'grade' | 'nenhum'
    completa: bool = False           # encontrou todas as questões x alternativas


def _candidatas_circulares(binaria: np.ndarray) -> List[Tuple[int, int, int]]:
    """Encontra centros (cx, cy, raio) de formas aproximadamente circulares."""
    # Fecha para unir o anel impresso da bolha vazia em um blob detectável
    fechada = cv2.morphologyEx(binaria, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    contornos, _ = cv2.findContours(fechada, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)

    h, w = binaria.shape
    area_img = h * w
    candidatas = []
    for c in contornos:
        area = cv2.contourArea(c)
        # bolhas típicas: entre 0,005% e 0,5% da imagem de trabalho
        if not (area_img * 5e-5 < area < area_img * 5e-3):
            continue
        peri = cv2.arcLength(c, True)
        if peri == 0:
            continue
        circularidade = 4 * np.pi * area / (peri * peri)
        x, y, cw, ch = cv2.boundingRect(c)
        proporcao = cw / ch if ch else 0
        if circularidade > 0.55 and 0.65 < proporcao < 1.55:
            candidatas.append((x + cw // 2, y + ch // 2, max(cw, ch) // 2))
    return _deduplicar(candidatas)


def _deduplicar(candidatas: List[Tuple[int, int, int]]) -> List[Tuple[int, int, int]]:
    """Remove duplicatas de centro próximo: o anel de uma bolha vazia gera dois
    contornos (borda externa e furo interno) com praticamente o mesmo centro."""
    candidatas = sorted(candidatas, key=lambda c: -c[2])  # maiores primeiro
    unicas: List[Tuple[int, int, int]] = []
    for cx, cy, r in candidatas:
        repetida = any((cx - ux) ** 2 + (cy - uy) ** 2 < (max(ur, r) * 0.8) ** 2
                       for ux, uy, ur in unicas)
        if not repetida:
            unicas.append((cx, cy, r))
    return unicas


def _agrupar_eixo(valores: List[int], tolerancia: int) -> List[List[int]]:
    """Agrupa índices de valores próximos (clusterização 1D simples)."""
    indices = sorted(range(len(valores)), key=lambda i: valores[i])
    grupos: List[List[int]] = []
    for i in indices:
        if grupos and valores[i] - valores[grupos[-1][-1]] <= tolerancia:
            grupos[-1].append(i)
        else:
            grupos.append([i])
    return grupos


def detectar_por_contornos(binaria: np.ndarray, num_questoes: int,
                           num_alternativas: int, num_colunas: int,
                           alternativas: List[str]) -> Optional[ResultadoDeteccao]:
    """Tenta montar a grade a partir de círculos detectados na imagem."""
    candidatas = _candidatas_circulares(binaria)
    esperado = num_questoes * num_alternativas
    if len(candidatas) < int(esperado * 0.9):
        return None

    # Filtra por raio coerente (mediana ± 60%)
    raios = sorted(r for _, _, r in candidatas)
    raio_med = raios[len(raios) // 2]
    candidatas = [c for c in candidatas if 0.4 * raio_med <= c[2] <= 1.6 * raio_med]
    if len(candidatas) < int(esperado * 0.9):
        return None

    # Agrupa por linha (eixo Y)
    ys = [c[1] for c in candidatas]
    linhas = _agrupar_eixo(ys, max(4, raio_med))
    questoes_por_coluna = -(-num_questoes // num_colunas)  # ceil

    # Cada linha física contém num_colunas * num_alternativas bolhas.
    # Aceita sobras (ex.: dígito "0" do número da questão também é circular);
    # o excesso é descartado por coluna mais adiante.
    bolhas_por_linha = num_colunas * num_alternativas
    folga = num_colunas * 2
    linhas_validas = [l for l in linhas
                      if bolhas_por_linha - 1 <= len(l) <= bolhas_por_linha + folga]
    if len(linhas_validas) < questoes_por_coluna:
        return None

    # Ordena linhas de cima para baixo e usa as primeiras questoes_por_coluna
    linhas_validas.sort(key=lambda l: np.mean([candidatas[i][1] for i in l]))
    linhas_validas = linhas_validas[:questoes_por_coluna]

    resultado = ResultadoDeteccao(metodo='contornos')
    largura = binaria.shape[1]
    for idx_linha, linha in enumerate(linhas_validas):
        pontos = sorted((candidatas[i] for i in linha), key=lambda c: c[0])
        # Divide os pontos da linha entre as colunas de questões pela posição X
        for col in range(num_colunas):
            x_ini = col * largura / num_colunas
            x_fim = (col + 1) * largura / num_colunas
            pontos_col = [p for p in pontos if x_ini <= p[0] < x_fim]
            if len(pontos_col) > num_alternativas:
                # Sobras à esquerda são tipicamente os dígitos do número da
                # questão; as bolhas de resposta são os círculos mais à direita.
                pontos_col = pontos_col[-num_alternativas:]
            if len(pontos_col) != num_alternativas:
                continue  # questão incompleta nesta coluna — ficará sem leitura
            numero = col * questoes_por_coluna + idx_linha + 1
            if numero > num_questoes:
                continue
            for j, (cx, cy, r) in enumerate(pontos_col):
                resultado.bolhas.append(Bolha(numero, alternativas[j], cx, cy, r))

    encontradas = {b.questao for b in resultado.bolhas}
    resultado.completa = len(encontradas) == num_questoes
    # Exige pelo menos 90% das questões mapeadas para confiar na grade
    if len(encontradas) < int(num_questoes * 0.9):
        return None
    return resultado


def detectar_por_grade(binaria: np.ndarray, num_questoes: int,
                       num_alternativas: int, num_colunas: int,
                       alternativas: List[str],
                       margens: Dict[str, float]) -> ResultadoDeteccao:
    """Fallback: grade matemática configurável (margens relativas por coluna)."""
    h, w = binaria.shape
    questoes_por_coluna = -(-num_questoes // num_colunas)
    resultado = ResultadoDeteccao(metodo='grade')

    for col in range(num_colunas):
        x0 = int(col * w / num_colunas)
        x1 = int((col + 1) * w / num_colunas)
        # área útil dentro da coluna (desconta cabeçalho e números das questões)
        ax0 = x0 + int((x1 - x0) * margens.get('esquerda', 0.30))
        ax1 = x1 - int((x1 - x0) * margens.get('direita', 0.02))
        ay0 = int(h * margens.get('superior', 0.20))
        ay1 = h - int(h * margens.get('inferior', 0.02))

        altura_q = (ay1 - ay0) / questoes_por_coluna
        largura_o = (ax1 - ax0) / num_alternativas
        raio = int(min(altura_q, largura_o) * 0.30)

        for i in range(questoes_por_coluna):
            numero = col * questoes_por_coluna + i + 1
            if numero > num_questoes:
                break
            cy = int(ay0 + (i + 0.5) * altura_q)
            for j, alt in enumerate(alternativas):
                cx = int(ax0 + (j + 0.5) * largura_o)
                resultado.bolhas.append(Bolha(numero, alt, cx, cy, raio))

    resultado.completa = True
    return resultado


def medir_preenchimentos(binaria: np.ndarray,
                         bolhas: List[Bolha]) -> Dict[int, Dict[str, float]]:
    """Mede o percentual de pixels marcados dentro de cada bolha.

    Usa máscara circular para não contar o quadrado ao redor da bolha.
    """
    preenchimentos: Dict[int, Dict[str, float]] = {}
    h, w = binaria.shape
    for b in bolhas:
        r = max(3, int(b.raio * 0.85))  # encolhe levemente para ignorar o anel impresso
        mascara = np.zeros((2 * r + 1, 2 * r + 1), np.uint8)
        cv2.circle(mascara, (r, r), r, 255, -1)

        y0, y1 = max(0, b.cy - r), min(h, b.cy + r + 1)
        x0, x1 = max(0, b.cx - r), min(w, b.cx + r + 1)
        roi = binaria[y0:y1, x0:x1]
        m = mascara[(y0 - (b.cy - r)):(y0 - (b.cy - r)) + roi.shape[0],
                    (x0 - (b.cx - r)):(x0 - (b.cx - r)) + roi.shape[1]]
        total = cv2.countNonZero(m)
        marcados = cv2.countNonZero(cv2.bitwise_and(roi, roi, mask=m)) if total else 0
        preenchimentos.setdefault(b.questao, {})[b.alternativa] = (
            marcados / total if total else 0.0
        )
    return preenchimentos
