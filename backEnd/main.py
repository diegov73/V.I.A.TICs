import os
import io
import base64
import time
from fastapi import FastAPI, Request, HTTPException, BackgroundTasks
from fastapi.responses import PlainTextResponse, JSONResponse, FileResponse # <-- NUEVO: Importar JSONResponse y FileResponse
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from openai import OpenAI
from dotenv import load_dotenv
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from fastapi import HTTPException
from supabase import create_client
#FIN NUEVOS CAMBIOS
load_dotenv()
# --- 1. DISEÑO DE TABLAS ---
class UsuarioRequest(BaseModel):
    nombre: str
    correo: str
    contrasena: str

class LoginRequest(BaseModel):
    correo: str
    contrasena: str

class MensajeRequest(BaseModel):
    texto: str
    id_usuario: str  # UUID como string

class DispositivoRequest(BaseModel):
    id_usuario: str
    nombre: str = 'V.I.A ESP32'
    bateria: int
    conectado: bool = False

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
app = FastAPI(title="Servidor de Visión VIA")
supabase = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 4.(ENDPOINTS) ---
@app.get("/")
def bienvenida():
    return {"mensaje": "backend ya funcionando y la base de datos fue creada."}

# POST
@app.post("/registro")
def registrar_usuario(nuevo_usuario: UsuarioRequest):
    try:
        # Verificar si ya existe el correo
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
        else:
            return {"estado": "error", "mensaje": "Correo o contraseña incorrectos"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


#  MUESTRE EL HISTORIAL EN LA APP SEGUN USUARIO
@app.get("/historial/{id_usuario}")
def obtener_historial(id_usuario: int):
    with Session(motor) as session:
        # Buscamos todos los mensajes que pertenezcan a ese ID de usuario
        statement = select(Mensaje).where(Mensaje.id_usuario == id_usuario)
        resultados = session.exec(statement).all()
        
        return resultados


#  Variables para guardar el estado actual
ESTADO_ACTUAL = {
    "descripcion": "Esperando la primera conexión del ESP32...",
    "timestamp": 0
}
RUTA_ULTIMA_FOTO = "latest.jpg"


def optimizar_desde_bytes(datos_binarios: bytes) -> str:
    img = Image.open(io.BytesIO(datos_binarios))
    img.thumbnail((320, 320)) 
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=70)
    return base64.b64encode(buffer.getvalue()).decode('utf-8')

def procesar_imagen_en_fondo(img_data: bytes):
    try:
        img_b64 = optimizar_desde_bytes(img_data)
        
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Actua como guia para un ciego y rellena la siguiente plantilla: peligros:[describir] o objetos relevantes:[listar], obstaculos (si es etiqueta explicala, si es libro leelo)."},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}", "detail": "high"}},
                    ],
                }
            ],
            max_tokens=100,
            temperatura=0
        )
        
        descripcion = response.choices[0].message.content
        print(f"📝 Resultado IA:\n{descripcion}")
        
        # --- NUEVO: Actualizamos el texto global ---
        ESTADO_ACTUAL["descripcion"] = descripcion
        ESTADO_ACTUAL["timestamp"] = time.time()
        
    except Exception as e:
        print(f"❌ Error en IA: {e}")
        ESTADO_ACTUAL["descripcion"] = "Error al analizar la imagen con OpenAI."

@app.post("/upload", response_class=PlainTextResponse)
async def upload(request: Request, background_tasks: BackgroundTasks):
    img_data = await request.body()
    if not img_data:
        raise HTTPException(status_code=400, detail="No hay datos")

    # --- NUEVO: Guardamos la foto física en el PC ---
    with open(RUTA_ULTIMA_FOTO, "wb") as f:
        f.write(img_data)
        
    # Cambiamos el mensaje temporalmente mientras la IA piensa
    ESTADO_ACTUAL["descripcion"] = "🧠 Procesando nueva imagen, por favor espera..."
    ESTADO_ACTUAL["timestamp"] = time.time()

    background_tasks.add_task(procesar_imagen_en_fondo, img_data)
    return "OK"

# --- NUEVAS RUTAS PARA EL FRONTEND DE REACT ---
@app.get("/latest-info")
def get_latest_info():
    """Devuelve el texto actual y la marca de tiempo"""
    return JSONResponse(content=ESTADO_ACTUAL)

@app.get("/latest-image")
def get_latest_image():
    """Devuelve el archivo de la última foto si existe"""
    if os.path.exists(RUTA_ULTIMA_FOTO):
        return FileResponse(RUTA_ULTIMA_FOTO)
    return HTTPException(status_code=404, detail="Aún no hay fotos")
# ----------------------------------------------
