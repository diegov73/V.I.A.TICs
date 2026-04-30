import { useState, useEffect } from 'react';

function App() {
  const [aiText, setAiText] = useState("Conectando con el servidor...");
  const [imageSrc, setImageSrc] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(0);

  useEffect(() => {
    // Función que pregunta al servidor
    const fetchLatestData = async () => {
      try {
        // Cambia 'localhost' por la IP de tu Arch Linux si abres esto en otro dispositivo
        const response = await fetch('http://localhost:5000/latest-info');
        const data = await response.json();

        // Si el timestamp es nuevo, actualizamos la pantalla
        if (data.timestamp > lastUpdate) {
          setAiText(data.description);
          
          // Truco clave: le sumamos el timestamp a la URL de la imagen.
          // Esto evita que el navegador use una imagen guardada en caché y lo obliga a descargar la nueva.
          setImageSrc(`http://localhost:5000/latest-image?t=${data.timestamp}`);
          setLastUpdate(data.timestamp);
        }
      } catch (error) {
        console.error("Error consultando al servidor:", error);
      }
    };

    // Ejecutar inmediatamente al abrir la página
    fetchLatestData();

    // Crear un ciclo que se repita cada 2 segundos (2000 ms)
    const intervalId = setInterval(fetchLatestData, 2000);

    // Limpiar el ciclo si cerramos la página
    return () => clearInterval(intervalId);
  }, [lastUpdate]);

  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif', maxWidth: '600px', margin: '0 auto' }}>
      <h2>Monitor de Visión 👁️</h2>
      
      <div style={{ padding: '15px', backgroundColor: '#eef2f5', borderRadius: '8px', marginBottom: '20px' }}>
        <h3 style={{ marginTop: 0, color: '#333' }}>Estado de la IA:</h3>
        <p style={{ whiteSpace: 'pre-wrap', fontSize: '1.1em', lineHeight: '1.5' }}>
          {aiText}
        </p>
      </div>

      {imageSrc ? (
        <div>
          <h4 style={{ color: '#555' }}>Última captura:</h4>
          <img 
            src={imageSrc} 
            alt="Última foto del ESP32" 
            style={{ width: '100%', maxHeight: '450px', objectFit: 'cover', borderRadius: '8px', border: '2px solid #ccc' }} 
          />
        </div>
      ) : (
        <div style={{ textAlign: 'center', padding: '50px', border: '2px dashed #ccc', borderRadius: '8px', color: '#888' }}>
          Esperando que la cámara envíe una foto...
        </div>
      )}
    </div>
  );
}

export default App;