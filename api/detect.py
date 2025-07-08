from ultralytics import YOLO
import cv2
import os

# Carrega o modelo treinado
model = YOLO("modelo-yolo/best.pt")

# Caminho da imagem a ser processada
image_path = "fotos/teste4.jpg"

# Executa a detecção
results = model(image_path)

# Salva a imagem com os bounding boxes
results[0].save(filename="fotos/deteccao.jpg")

# Mostra as detecções
for r in results:
    for box in r.boxes:
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        conf = float(box.conf[0])
        print(f"BOLINHA detectada em x={x1}, y={y1} | Confiança: {conf:.2f}")
