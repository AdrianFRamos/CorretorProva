import cv2
import numpy as np
import json
import os

GABARITO_PATH = "data/gabaritos.json"

def carregar_gabarito(turma):
    if not os.path.exists(GABARITO_PATH):
        raise Exception("Arquivo de gabaritos não encontrado.")
    
    with open(GABARITO_PATH, "r", encoding="utf-8") as f:
        gabaritos = json.load(f)
    
    if turma not in gabaritos:
        raise Exception(f"Gabarito da turma {turma} não encontrado.")
    
    return gabaritos[turma]

def detectar_respostas(imagem_path, total_questoes=44):
    imagem = cv2.imread(imagem_path)
    imagem_cinza = cv2.cvtColor(imagem, cv2.COLOR_BGR2GRAY)
    imagem_cinza = cv2.medianBlur(imagem_cinza, 5)

    circles = cv2.HoughCircles(
        imagem_cinza,
        cv2.HOUGH_GRADIENT,
        dp=1.2,
        minDist=20,
        param1=50,
        param2=30,
        minRadius=10,
        maxRadius=20
    )

    if circles is None:
        return None

    circles = np.uint16(np.around(circles[0, :]))
    circles = sorted(circles, key=lambda c: (c[1], c[0]))

    alternativas = ['A', 'B', 'C', 'D', 'E']
    respostas = [''] * total_questoes
    linhas_detectadas = {}

    for (x, y, r) in circles:
        linha = int(round((y - 400) / 40))  # ajuste fino conforme layout

        if linha < 0 or linha >= total_questoes:
            continue

        recorte = imagem_cinza[y - r:y + r, x - r:x + r]
        if recorte.size == 0:
            continue

        intensidade = np.sum(255 - recorte)

        if linha not in linhas_detectadas:
            linhas_detectadas[linha] = []

        linhas_detectadas[linha].append((x, intensidade))

    for linha, bolhas in linhas_detectadas.items():
        bolhas = sorted(bolhas, key=lambda b: b[0])
        if len(bolhas) != 5:
            continue
        indice = np.argmax([b[1] for b in bolhas])
        respostas[linha] = alternativas[indice]

    return respostas

def corrigir_prova(turma, aluno, caminho_imagem):
    try:
        gabarito = carregar_gabarito(turma)
        respostas_extraidas = detectar_respostas(caminho_imagem, total_questoes=len(gabarito))

        if respostas_extraidas is None:
            return {"erro": "Não foi possível detectar bolhas na imagem."}

        total = len(gabarito)
        acertos = sum([1 for i in range(total) if respostas_extraidas[i] == gabarito[i]])
        erros = total - acertos
        nota = round((acertos / total) * 10, 2)

        return {
            "aluno": aluno,
            "turma": turma,
            "acertos": acertos,
            "erros": erros,
            "nota": nota,
            "respostas": respostas_extraidas,
            "gabarito": gabarito
        }

    except Exception as e:
        return {"erro": str(e)}
