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
#NUEVOS IMPORT
from fastapi import FastAPI
from sqlmodel import SQLModel, Field, Relationship, create_engine, Session, select
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from fastapi import HTTPException
# --- 1. DISEÑO DE TABLAS ---
class Usuario(SQLModel, table=True):
    id_usuario: Optional[int] = Field(default=None, primary_key=True)
    rut: str = Field(unique=True, index=True)
    nombre: str
    correo: str = Field(unique=True)
    contrasena: str
    edad: int
    telefono: str
    mensajes: List["Mensaje"] = Relationship(back_populates="usuario")

class Mensaje(SQLModel, table=True):
    id_mensaje: Optional[int] = Field(default=None, primary_key=True)
    texto: str
    fecha: datetime = Field(default_factory=datetime.now)
    id_usuario: int = Field(foreign_key="usuario.id_usuario")
    usuario: Optional[Usuario] = Relationship(back_populates="mensajes")

class LoginRequest(BaseModel):
    correo: str
    contrasena: str
# --- 2. CONFIGURACIÓN DE LA BASE DE DATOS ---
# Esta wea crea un archivo llamado via.db
nombre_archivo_db = "via.db"
url_db = f"sqlite:///{nombre_archivo_db}"
motor = create_engine(url_db)

# --- 3. CREACIÓN DE LA APLICACIÓN FASTAPI ---
app = FastAPI()

# Esta instrucción le dice a FastAPI que cree el archivo y las tablas al encenderse
@app.on_event("startup")
def iniciar_base_datos():
    SQLModel.metadata.create_all(motor)

# --- 4.(ENDPOINTS) ---
@app.get("/")
def bienvenida():
    return {"mensaje": "backend ya funcionando y la base de datos fue creada."}

# POST
@app.post("/registro")
def registrar_usuario(nuevo_usuario: Usuario):
    with Session(motor) as session:
        session.add(nuevo_usuario)
        session.commit()
        session.refresh(nuevo_usuario)
        return {
            "estado": "exito", 
            "mensaje": f"¡Usuario {nuevo_usuario.nombre} registrado correctamente!"
        }

@app.post("/login")
def iniciar_sesion(credenciales: LoginRequest):
    with Session(motor) as session:
        statement = select(Usuario).where(Usuario.correo == credenciales.correo)
        usuario_db = session.exec(statement).first()

        if usuario_db and usuario_db.contrasena == credenciales.contrasena:
            return {
                "estado": "exito",
                "mensaje": "Login correcto",
                "datos_usuario": {
                    "id_usuario": usuario_db.id_usuario,
                    "nombre": usuario_db.nombre, 
                    "correo": usuario_db.correo
                }
            }
        else:
            return {"estado": "error", "mensaje": "Correo o contraseña incorrectos"}

#LOGGEO
@app.post("/mensaje")
def recibir_mensaje(mensaje_data: Mensaje):
    with Session(motor) as session:
        
        usuario_existe = session.get(Usuario, mensaje_data.id_usuario)

        
        if not usuario_existe:
        
            raise HTTPException(
                status_code=404, 
                detail=f"Error: El usuario con ID {mensaje_data.id_usuario} no existe en la base de datos."
            )

        
        session.add(mensaje_data)
        session.commit()
        session.refresh(mensaje_data)
        
        return {
            "estado": "exito", 
            "mensaje_id": mensaje_data.id_mensaje,
            "propietario": usuario_existe.nombre # Opcional: para confirmar de quién es
        }

#  MUESTRE EL HISTORIAL EN LA APP SEGUN USUARIO
@app.get("/historial/{id_usuario}")
def obtener_historial(id_usuario: int):
    with Session(motor) as session:
        # Buscamos todos los mensajes que pertenezcan a ese ID de usuario
        statement = select(Mensaje).where(Mensaje.id_usuario == id_usuario)
        resultados = session.exec(statement).all()
        
        return resultados
#FIN NUEVOS CAMBIOS
load_dotenv()
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

app = FastAPI(title="Servidor de Visión VIA")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_b64}", "detail": "low"}},
                    ],
                }
            ],
            max_tokens=100
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

if __name__ == '__main__':
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=True)
