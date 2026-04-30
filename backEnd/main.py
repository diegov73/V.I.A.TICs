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

# --- NUEVO: Variables para guardar el estado actual ---
ESTADO_ACTUAL = {
    "descripcion": "Esperando la primera conexión del ESP32...",
    "timestamp": 0
}
RUTA_ULTIMA_FOTO = "latest.jpg"
# -----------------------------------------------------

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