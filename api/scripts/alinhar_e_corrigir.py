
import cv2
import numpy as np
import json

modelo_path = "modelo/gabarito_base.png"
prova_path = "fotos/teste.jpg"
coordenadas_path = "modelo/coordenadas_questoes.json"
gabarito_path = "gabaritos/turma1N.json"

def alinhar_imagem(img_alvo, img_base):
    orb = cv2.ORB_create(5000)
    kp1, des1 = orb.detectAndCompute(img_base, None)
    kp2, des2 = orb.detectAndCompute(img_alvo, None)
    bf = cv2.BFMatcher(cv2.NORM_HAMMING)
    matches = bf.match(des1, des2)
    matches = sorted(matches, key=lambda x: x.distance)
    src_pts = np.float32([kp1[m.queryIdx].pt for m in matches[:50]]).reshape(-1, 1, 2)
    dst_pts = np.float32([kp2[m.trainIdx].pt for m in matches[:50]]).reshape(-1, 1, 2)
    M, _ = cv2.findHomography(dst_pts, src_pts, cv2.RANSAC, 5.0)
    h, w = img_base.shape[:2]
    return cv2.warpPerspective(img_alvo, M, (w, h))

def detectar_marcada(imagem, alternativas, limiar_pixels=800):
    max_preto = -1
    letra_marcada = "-"
    for alt in alternativas:
        x, y, w, h = alt["x"], alt["y"], alt["w"], alt["h"]
        recorte = imagem[y:y+h, x:x+w]
        _, binaria = cv2.threshold(recorte, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        pixels_pretos = cv2.countNonZero(binaria)
        if pixels_pretos > max_preto:
            max_preto = pixels_pretos
            letra_marcada = alt["letra"]
    if max_preto < limiar_pixels:
        return "-"
    return letra_marcada

img_base = cv2.imread(modelo_path, 0)
img_prova = cv2.imread(prova_path, 0)
img_alinhada = alinhar_imagem(img_prova, img_base)

with open(coordenadas_path, "r") as f:
    questoes = json.load(f)

with open(gabarito_path, "r") as f:
    gabarito = json.load(f)["respostas"]

respostas_marcadas = []
acertos = 0

for i, q in enumerate(questoes):
    marcada = detectar_marcada(img_alinhada, q["alternativas"], limiar_pixels=800)
    correta = gabarito[i] if i < len(gabarito) else "-"
    acertou = marcada == correta
    respostas_marcadas.append({
        "questao": q["numero"],
        "marcada": marcada,
        "correta": correta,
        "acertou": acertou
    })
    if acertou:
        acertos += 1

nota = round((acertos / len(questoes)) * 10, 2)
print(f"Nota: {nota} ({acertos} acertos de {len(questoes)})")

for r in respostas_marcadas:
    print(
        f"Q{r['questao']:02d}: marcada={r['marcada']} correta={r['correta']} {'✓' if r['acertou'] else '✗'}"
    )

img_vis = cv2.cvtColor(img_alinhada, cv2.COLOR_GRAY2BGR)

for i, q in enumerate(questoes):
    marcada = respostas_marcadas[i]["marcada"]
    for alt in q["alternativas"]:
        x, y, w, h = alt["x"], alt["y"], alt["w"], alt["h"]
        if marcada == "-":
            cor = (0, 0, 255)
        else:
            cor = (0, 255, 0) if alt["letra"] == marcada else (255, 0, 0)
        cv2.rectangle(img_vis, (x, y), (x+w, y+h), cor, 4)
        cv2.putText(img_vis, alt["letra"], (x+5, y+15), cv2.FONT_HERSHEY_SIMPLEX, 0.5, cor, 1)

h, w = img_vis.shape[:2]
escala = 1000 / max(h, w)
img_vis_resized = cv2.resize(img_vis, (int(w * escala), int(h * escala)))

cv2.namedWindow("Respostas Detectadas", cv2.WINDOW_NORMAL)
cv2.imshow("Respostas Detectadas", img_vis)
cv2.waitKey(0)
cv2.destroyAllWindows()
