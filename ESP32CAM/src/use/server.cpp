#include <Arduino.h>
#include <WiFi.h>
#include "esp_camera.h"
#include "../setup/server.h"

WiFiServer server(80);

void startServer() {
  server.begin();
  Serial.println("Servidor iniciado.");
}

void handleWebClient() {
  WiFiClient client = server.available();
  if (!client) return;

  String currentLine = "";

  while (client.connected()) {
    if (client.available()) {
      char c = client.read();

      if (c == '\n') {
        if (currentLine.length() == 0) {

          camera_fb_t * fb = esp_camera_fb_get();
          
          if (!fb) {
            client.println("HTTP/1.1 500 Internal Server Error");
            client.println();
            break;
          }

          client.println("HTTP/1.1 200 OK");
          client.println("Content-type: image/jpeg");
          client.println("Connection: close");
          client.println();
          client.write(fb->buf, fb->len);
          esp_camera_fb_return(fb);
          break;
        }
        
        else {
          currentLine = "";
        }
      
      } else if (c != '\r') {
        currentLine += c;
      }
    }
  }
  client.stop();
}