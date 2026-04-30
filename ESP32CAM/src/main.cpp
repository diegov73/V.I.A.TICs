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

int obtenerIntervalo(int distancia){
    if(distancia <= 0 || distancia > 1000){
      return 0; 
    }

  int intervalo = map(distancia, 50, 1000, 50, 600);

  return constrain(intervalo, 50, 600);
}

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
  int d = getDistance(); 
    int msEspera = obtenerIntervalo(d);

    if (msEspera > 0){
        digitalWrite(BUZZER_PIN, HIGH);
        delay(40);
        digitalWrite(BUZZER_PIN, LOW);
        delay(msEspera); 
    }

    if (d != -1) {
        show(0, "Dist: " + String(d) + "mm");
        show(1, "Inter: " + String(msEspera) + "ms");
    }
}

