
from ultralytics import YOLO
import json
import os

# === CONFIGURAÇÕES ===
imagem_path = "fotos/teste4.jpg"
modelo_path = "modelo-yolo/best.pt"
gabarito_path = "gabarito.json"

# === DETECÇÃO COM YOLO ===
model = YOLO(modelo_path)
results = model(imagem_path)
res = results[0]

# === EXTRAÇÃO E ORDENAÇÃO DAS RESPOSTAS ===

# Parâmetros manuais (ajuste conforme seu layout)
QUESTOES = 44
ALTERNATIVAS = ['A', 'B', 'C', 'D', 'E']

# Pega todas as detecções e organiza por Y (linha)
detected_boxes = []
for box in res.boxes:
    x1, y1, x2, y2 = box.xyxy[0].tolist()
    xc = (x1 + x2) / 2
    yc = (y1 + y2) / 2
    detected_boxes.append((xc, yc))

# Ordenar por Y para agrupar por linha (questões)
detected_boxes.sort(key=lambda b: b[1])  # ordenar por Y

# Agrupar por questão assumindo espaçamento fixo
respostas_detectadas = {}
linha_atual = []
questao_num = 1
linha_limite = 20  # ajuste conforme seu layout

for i, (x, y) in enumerate(detected_boxes):
    if not linha_atual:
        linha_atual.append((x, y))
    elif abs(y - linha_atual[0][1]) < linha_limite:
        linha_atual.append((x, y))
    else:
        # Ordenar por X (coluna: A–E)
        linha_atual.sort(key=lambda b: b[0])
        if len(linha_atual) == 5:
            respostas_detectadas[str(questao_num)] = ALTERNATIVAS[linha_atual.index(min(linha_atual, key=lambda b: b[0]))]
        questao_num += 1
        linha_atual = [(x, y)]

# última linha
if linha_atual and questao_num <= QUESTOES:
    linha_atual.sort(key=lambda b: b[0])
    if len(linha_atual) == 5:
        respostas_detectadas[str(questao_num)] = ALTERNATIVAS[linha_atual.index(min(linha_atual, key=lambda b: b[0]))]

# === COMPARAÇÃO COM GABARITO ===
with open(gabarito_path, "r") as f:
    gabarito = json.load(f)

respostas_certas = gabarito["respostas"]
acertos = 0
total = len(respostas_certas)

print("\n===== CORREÇÃO DA PROVA =====")
for questao, gabarito_correto in respostas_certas.items():
    resposta_aluno = respostas_detectadas.get(questao)
    status = "✔️" if resposta_aluno == gabarito_correto else "❌"
    print(f"Questão {questao.zfill(2)}: aluno marcou {resposta_aluno} | Gabarito: {gabarito_correto} {status}")
    if resposta_aluno == gabarito_correto:
        acertos += 1

print(f"\nNota final: {acertos}/{total}")
