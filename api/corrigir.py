import json

# Simulando coordenadas de bolinhas detectadas (exemplo)
bolinhas_detectadas = {
    "1": "C",
    "2": "A",
    "3": "E",
    "4": "B",
    "5": "A"  # Errada
}

# Carrega o gabarito
with open("gabarito.json", "r") as f:
    gabarito = json.load(f)

respostas_certas = gabarito["respostas"]

# Corrige
acertos = 0
total = len(respostas_certas)

for questao, gabarito_correto in respostas_certas.items():
    resposta_aluno = bolinhas_detectadas.get(questao)
    if resposta_aluno == gabarito_correto:
        acertos += 1
    print(f"Questão {questao}: aluno marcou {resposta_aluno} | Gabarito: {gabarito_correto}")

print(f"\nNota final: {acertos}/{total}")
