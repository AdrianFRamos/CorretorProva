
import cv2
import numpy as np

# Caminho da imagem de prova (troque pelo nome da foto tirada)
img_path = "fotos/teste.jpg"
img = cv2.imread(img_path)
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# Pré-processamento
blur = cv2.GaussianBlur(gray, (5, 5), 0)
thresh = cv2.adaptiveThreshold(blur, 255, cv2.ADAPTIVE_THRESH_MEAN_C,
                               cv2.THRESH_BINARY_INV, 11, 3)

# Encontrar contornos
contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
questoes_detectadas = []

for cnt in contours:
    x, y, w, h = cv2.boundingRect(cnt)
    area = w * h
    aspect_ratio = w / float(h)
    if 1800 < area < 10000 and 4.0 < aspect_ratio < 10.0:
        questoes_detectadas.append((x, y, w, h))

questoes_ordenadas = sorted(questoes_detectadas, key=lambda r: (r[1] // 10, r[0]))

# Gabarito de exemplo (substitua pelo correto)
gabarito = ["C", "B", "D", "D", "E", "C", "B", "A", "A", "D",
            "C", "B", "D", "D", "E", "C", "B", "A", "A", "D",
            "C", "B", "D", "D", "E", "C", "B", "A", "A", "D",
            "C", "B", "D", "D", "E", "C", "B", "A", "A", "D",
            "C", "B", "D", "D"]

respostas = []
acertos = 0
img_resultado = img.copy()

for i, (x, y, w, h) in enumerate(questoes_ordenadas[:44]):
    questao_num = i + 1
    area_questao = gray[y:y+h, x:x+w]
    largura_alt = w // 5
    opcoes = []
    for j in range(5):
        recorte = area_questao[0:h, j*largura_alt:(j+1)*largura_alt]
        _, binaria = cv2.threshold(recorte, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        preenchimento = cv2.countNonZero(binaria)
        opcoes.append(preenchimento)

    marcada_idx = np.argmax(opcoes)
    letra_marcada = chr(65 + marcada_idx)
    letra_correta = gabarito[i]

    if letra_marcada == letra_correta:
        acertos += 1

    cv2.rectangle(img_resultado, (x, y), (x+w, y+h), (0, 255, 0) if letra_marcada == letra_correta else (0, 0, 255), 2)
    cv2.putText(img_resultado, f"{questao_num:02d}: {letra_marcada}", (x+5, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                (0, 0, 255), 1)

nota = round(acertos / len(gabarito) * 10, 2)
cv2.putText(img_resultado, f"Nota: {nota} ({acertos}/{len(gabarito)})", (50, 50), cv2.FONT_HERSHEY_SIMPLEX, 1,
            (255, 0, 0), 2)

cv2.namedWindow("Resultado", cv2.WINDOW_NORMAL)
cv2.imshow("Resultado", img_resultado)
cv2.waitKey(0)
cv2.destroyAllWindows()
