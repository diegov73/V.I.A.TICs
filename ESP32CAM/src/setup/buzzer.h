#ifndef BUZZER_H
#define BUZZER_H

#include <Arduino.h>

#define BUZZER_PIN 16

void initBuzzer();
void beep(int duration = 100);

#endif