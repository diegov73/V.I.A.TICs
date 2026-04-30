#include <Arduino.h>
#include "setup/wifi.h"
#include "setup/camera.h"
#include "setup/server.h"
#include "setup/display.h"
#include "setup/buton.h"
#include "setup/buzzer.h"
#include "setup/laser.h"

const char* ssid = "Catalina";
const char* pswd = "Cata141592";

bool ultimoEstadoBoton = false;
int pressed = 0;

void setup(){
  Serial.begin(115200);
  Serial.println();

  Serial.println("ESP32-cam activo");

  initDisplay();
  initButton();
  initBuzzer();
  initLaser();
  
  delay(200);
  connectWifi(ssid, pswd);
  
  
  //initFlash();
  //initCamera();
  //startServer();
}

void loop() {
  //handleWebClient();
  bool actualEstadoBoton = isButtonPressed();
  int dist = getDistance();

  Serial.print(dist);

  if(dist != -1){
    show(0, "distancia: " + String(dist) + "mm");
  }
  
  if(isButtonPressed() == true && ultimoEstadoBoton == false){
    pressed = pressed + 1;
    Serial.println("boton presionado");
  }

  show(1, "veces pulsado: " + pressed);
  delay(50);
  ultimoEstadoBoton = actualEstadoBoton;

  playTone(440, 100);

  delay(500);
}
