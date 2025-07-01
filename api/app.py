# app.py
from fastapi import FastAPI, UploadFile, Form
from fastapi.responses import JSONResponse
from services.corretor import corrigir_prova
import shutil
import os

app = FastAPI()

UPLOAD_DIR = "uploads/respostas"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.post("/corrigir")
async def corrigir(turma: str = Form(...), aluno: str = Form(...), file: UploadFile = None):
    if file is None:
        return JSONResponse(status_code=400, content={"erro": "Arquivo de imagem não enviado."})

    caminho = f"{UPLOAD_DIR}/{aluno}_{file.filename}"
    with open(caminho, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    resultado = corrigir_prova(turma, aluno, caminho)
    return resultado
