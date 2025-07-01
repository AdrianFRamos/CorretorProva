# services/corretor.py
import cv2
import pytesseract
import json
import random
import numpy as np
import os

# Caminho para os gabaritos
GABARITO_PATH = "data/gabaritos.json"

# Carrega os gabaritos do arquivo
def carregar_gabarito(turma):
    if not os.path.exists(GABARITO_PATH):
        raise Exception("Arquivo de gabaritos não encontrado.")
    
    with open(GABARITO_PATH, "r", encoding="utf-8") as f:
        gabaritos = json.load(f)
    
    if turma not in gabaritos:
        raise Exception(f"Gabarito da turma {turma} não encontrado.")
    
    return gabaritos[turma]

# Função principal de correção
def corrigir_prova(turma, aluno, caminho_imagem):
    try:
        gabarito = carregar_gabarito(turma)
        total_questoes = len(gabarito)

        imagem = cv2.imread(caminho_imagem)
        imagem_cinza = cv2.cvtColor(imagem, cv2.COLOR_BGR2GRAY)
        _, binarizada = cv2.threshold(imagem_cinza, 150, 255, cv2.THRESH_BINARY_INV)

        # Aqui definimos posições simuladas para bolhas
        # Ex: 44 questões em colunas, 5 alternativas cada
        respostas_extraidas = []

        altura, largura = binarizada.shape
        altura_inicial = 200  # onde começa a 1ª questão
        espacamento_vertical = 50
        espacamento_horizontal = 70
        bolha_radius = 15

        for i in range(total_questoes):
            linha_y = altura_inicial + i * espacamento_vertical
            alternativas = ['A', 'B', 'C', 'D', 'E']
            intensidade = []

            for j in range(5):  # 5 alternativas
                coluna_x = 100 + j * espacamento_horizontal
                recorte = binarizada[linha_y-bolha_radius:linha_y+bolha_radius,
                                     coluna_x-bolha_radius:coluna_x+bolha_radius]
                soma = np.sum(recorte)
                intensidade.append(soma)

            # A bolha com maior soma de preto (mais escura) → marcada
            indice_escolhido = np.argmax(intensidade)
            respostas_extraidas.append(alternativas[indice_escolhido])

        # Comparar com o gabarito
        acertos = sum([1 for i, r in enumerate(respostas_extraidas) if r == gabarito[i]])
        erros = total_questoes - acertos
        nota = round((acertos / total_questoes) * 10, 2)

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
