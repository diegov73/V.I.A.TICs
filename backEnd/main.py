import os
import io
import base64
import time
from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from fastapi.responses import PlainTextResponse, JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import google.generativeai as genai
from dotenv import load_dotenv
import uvicorn
from pydantic import BaseModel
from typing import Optional
from supabase import create_client

load_dotenv()

# --- MODELOS ---
class UsuarioRequest(BaseModel):
    nombre: str
    correo: str
    contrasena: str

class LoginRequest(BaseModel):
    correo: str
    contrasena: str

class MensajeRequest(BaseModel):
    texto: str
    id_usuario: str

class DispositivoRequest(BaseModel):
    id_usuario: str
    nombre: str = 'V.I.A ESP32'
    bateria: int
    conectado: bool = False

class HeartbeatRequest(BaseModel):
    bateria: Optional[int] = None

# --- APP ---
app = FastAPI(title="Servidor de Visión VIA")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- CLIENTES ---
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
client = genai.GenerativeModel("gemini-2.0-flash")
supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)

# --- ESTADO GLOBAL ---
ESTADO_ACTUAL = {
    "descripcion": "Esperando la primera conexión del ESP32...",
    "timestamp": 0,
    "ultimo_latido": 0.0,
    "bateria": None
}
RUTA_ULTIMA_FOTO = "latest.jpg"

# --- ENDPOINTS USUARIOS ---
@app.get("/")
def bienvenida():
    return {"mensaje": "backend funcionando."}

@app.post("/registro")
def registrar_usuario(nuevo_usuario: UsuarioRequest):
    try:
        existente = supabase.table("usuario").select("id").eq("correo", nuevo_usuario.correo).execute()
        if existente.data:
            return {"estado": "error", "mensaje": "El correo ya está registrado"}
        supabase.table("usuario").insert(nuevo_usuario.model_dump()).execute()
        return {"estado": "exito", "mensaje": f"Usuario {nuevo_usuario.nombre} registrado."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/login")
def iniciar_sesion(credenciales: LoginRequest):
    try:
        llamada = supabase.table("usuario").select("id", "nombre").eq("correo", credenciales.correo).eq("contrasena", credenciales.contrasena).execute()
        if llamada.data:
            return {"estado": "exito", "usuario": llamada.data[0]}
        return {"estado": "error", "mensaje": "Correo o contraseña incorrectos"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/mensaje")
def recibir_mensaje(msg: MensajeRequest):
    try:
        supabase.table("mensaje").insert(msg.model_dump()).execute()
        return {"estado": "exito"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/historial/{id_usuario}")
def obtener_historial(id_usuario: str):
    try:
        resultado = supabase.table("mensaje").select("*").eq("id_usuario", id_usuario).execute()
        return resultado.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# --- ENDPOINTS ESP32 ---
@app.post("/esp32/heartbeat")
def esp32_heartbeat(datos: HeartbeatRequest = None):
    ESTADO_ACTUAL["ultimo_latido"] = time.time()
    if datos and datos.bateria is not None:
        ESTADO_ACTUAL["bateria"] = datos.bateria
    return {"estado": "ok", "mensaje": "Latido recibido"}

@app.get("/esp32/status")
def obtener_estado_esp32():
    ahora = time.time()
    ultimo_latido = ESTADO_ACTUAL["ultimo_latido"]
    UMBRAL_OFFLINE_SEGUNDOS = 45

    if ultimo_latido == 0.0:
        activo = False
        mensaje = "El dispositivo nunca se ha conectado."
    elif (ahora - ultimo_latido) < UMBRAL_OFFLINE_SEGUNDOS:
        activo = True
        mensaje = "Dispositivo activo"
    else:
        activo = False
        mensaje = f"Dispositivo inactivo. Última señal hace {int(ahora - ultimo_latido)} segundos."

    return {
        "activo": activo,
        "mensaje": mensaje,
        "bateria": ESTADO_ACTUAL["bateria"],
        "ultimo_latido_timestamp": ultimo_latido
    }

# --- ENDPOINTS VISIÓN ---
def procesar_imagen_en_fondo(img_data: bytes):
    try:
        img = Image.open(io.BytesIO(img_data))
        img.thumbnail((320, 320))

        response = client.generate_content([
            "Actua como guia para un ciego en máximo 2 oraciones. Indica: peligros u obstáculos en la trayectoria, objetos relevantes, semáforos, señales o texto visible.",
            img
        ])

        descripcion = response.text
        print(f"Resultado IA:\n{descripcion}")
        ESTADO_ACTUAL["descripcion"] = descripcion
        ESTADO_ACTUAL["timestamp"] = time.time()

    except Exception as e:
        print(f"Error en IA: {e}")
        ESTADO_ACTUAL["descripcion"] = "Error al analizar la imagen."

@app.post("/upload", response_class=PlainTextResponse)
async def upload(request: Request, background_tasks: BackgroundTasks):
    img_data = await request.body()
    if not img_data:
        raise HTTPException(status_code=400, detail="No hay datos")
    with open(RUTA_ULTIMA_FOTO, "wb") as f:
        f.write(img_data)
    ESTADO_ACTUAL["descripcion"] = "Procesando imagen, por favor espera..."
    ESTADO_ACTUAL["timestamp"] = time.time()
    background_tasks.add_task(procesar_imagen_en_fondo, img_data)
    return "OK"

@app.get("/latest-info")
def get_latest_info():
    return JSONResponse(content=ESTADO_ACTUAL)

@app.get("/latest-image")
def get_latest_image():
    if os.path.exists(RUTA_ULTIMA_FOTO):
        return FileResponse(RUTA_ULTIMA_FOTO)
    raise HTTPException(status_code=404, detail="Aún no hay fotos")

if __name__ == '__main__':
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)