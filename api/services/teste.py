import cv2
import pytesseract
import re

# 📸 Carrega imagem
imagem_path = "uploads/respostas/teste.jpg"
imagem = cv2.imread(imagem_path)
if imagem is None:
    print("❌ ERRO: imagem não encontrada.")
    exit()

# Escala de cinza
imagem_cinza = cv2.cvtColor(imagem, cv2.COLOR_BGR2GRAY)

# Binarização
_, imagem_bin = cv2.threshold(imagem_cinza, 150, 255, cv2.THRESH_BINARY_INV)

# 🔲 Define área de interesse (retângulo das questões)
x_roi, y_roi, w_roi, h_roi = 130, 2000, 2900, 2000
area_questoes = imagem_bin[y_roi:y_roi+h_roi, x_roi:x_roi+w_roi]

# 🧪 Salvar recorte para debug se quiser
cv2.imwrite("debug_area_questoes.jpg", area_questoes)

# Rodar OCR apenas dentro da área
custom_config = r'-c tessedit_char_whitelist=0123456789 --psm 6'
dados = pytesseract.image_to_data(area_questoes, output_type=pytesseract.Output.DICT, config=custom_config)

# Marcações e posição no original
posicoes_questoes = {}

for i in range(len(dados["text"])):
    texto = dados["text"][i].strip()
    if not texto:
        continue

    texto_corrigido = texto.replace("O", "0").replace("I", "1").replace("S", "5")

    if re.fullmatch(r"\d{2}", texto_corrigido):
        numero = int(texto_corrigido)
        if 1 <= numero <= 44:
            x = x_roi + dados["left"][i]
            y = y_roi + dados["top"][i]
            w = dados["width"][i]
            h = dados["height"][i]

            posicoes_questoes[numero] = (x, y)
            cv2.rectangle(imagem, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(imagem, texto_corrigido, (x, y - 5),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

# 🔲 Desenha o retângulo principal da área de leitura
cv2.rectangle(imagem, (x_roi, y_roi), (x_roi + w_roi, y_roi + h_roi), (255, 0, 0), 3)

# Salva imagem final
cv2.imwrite("questoes_detectadas_area_limitada.jpg", imagem)

# Exibe resultados
print("✅ Questões detectadas dentro da área:")
for num in sorted(posicoes_questoes.keys()):
    print(f"Questão {num:02} → posição: {posicoes_questoes[num]}")

print("📸 Imagens geradas:")
print("- debug_area_questoes.jpg → só a área das questões")
print("- questoes_detectadas_area_limitada.jpg → com marcações no original")
