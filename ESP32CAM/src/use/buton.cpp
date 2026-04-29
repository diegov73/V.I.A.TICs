#include <Arduino.h>
#include "../setup/buton.h"

void initButton() {
    // Usamos PULLUP interno para no necesitar resistencias físicas
    pinMode(BUTTON_PIN, INPUT_PULLUP);
}

bool isButtonPressed() {
    // Retorna true solo si el pin cae a LOW (botón presionado)
    return (digitalRead(BUTTON_PIN) == LOW);
}