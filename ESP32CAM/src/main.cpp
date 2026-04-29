#include <Arduino.h>
#include "setup/wifi.h"
#include "setup/camera.h"
#include "setup/server.h"
#include "setup/display.h"
#include "setup/buton.h"

const char* ssid = "Catalina";
const char* pswd = "Cata141592";

bool estado;

void setup(){
  Serial.begin(115200);
  Serial.println();

  Serial.println("ESP32-cam activo");

  initDisplay();
  showMessage("pantalla inicializada");
  delay(200);
  
  initFlash();
  showMessage("flash");
  delay(200);

  initButton();
  estado = isButtonPressed();
  showMessage("inicio boton estado:" + estado);
  delay(200);

  connectWifi(ssid, pswd);


  delay(1000);
  //initCamera()

  //startServer();
}

void loop() {
  //handleWebClient();

  int fotos = 5;
  int intervaloMs = 500;

  if(isButtonPressed()){
    takeBurst(fotos, intervaloMs);

    showMessage("imagenes tomadas: " + String(fotos));
    delay(3000);
  }

  showMessage("Probando OLED...\nSegundos: " + String(millis() / 1000));
  delay(1000);
}
