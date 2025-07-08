import pytesseract
import cv2

# Caminho do Tesseract no Windows
pytesseract.pytesseract.tesseract_cmd = r"C:\\Program Files\\Tesseract-OCR\\tesseract.exe"

# Carrega imagem da folha
img = cv2.imread("fotos/teste1.jpg")

# Recorta área onde fica o nome e turma
nome_crop = img[100:180, 50:600]
turma_crop = img[180:250, 50:600]

# OCR
nome = pytesseract.image_to_string(nome_crop).strip()
turma = pytesseract.image_to_string(turma_crop).strip()

print(f"Nome detectado: {nome}")
print(f"Turma detectada: {turma}")
