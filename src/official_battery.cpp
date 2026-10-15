#include "official_battery.h"
#include "official_tof.h"
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#include <Wire.h>
#include <freertos/task.h>
extern "C" int vl53lx_wire_i2c_init(void);
namespace {
portMUX_TYPE batteryLock=portMUX_INITIALIZER_UNLOCKED;
TaskHandle_t batteryTask=nullptr;
float heldVoltage=0;
uint32_t sampledAt=0;
bool sampleValid=false,pending=false;
void readBattery() {
  while(!official_i2c_try_lock())vTaskDelay(1);
  Wire1.beginTransmission(0x40);Wire1.write(4);
  bool ok=Wire1.endTransmission(false)==0 && Wire1.requestFrom(0x40,2,true)==2;
  float voltage=0;
  if(ok) {
    int16_t raw=(static_cast<uint16_t>(Wire1.read())<<8)|Wire1.read();
    voltage=static_cast<float>(raw>>3)*0.008f;
  }
  official_i2c_unlock();
  portENTER_CRITICAL(&batteryLock);
  if(ok)heldVoltage=voltage;
  sampleValid=ok;sampledAt=micros();pending=false;
  portEXIT_CRITICAL(&batteryLock);
}
void batteryWorker(void*) {
  for(;;) {
    ulTaskNotifyTake(pdTRUE,portMAX_DELAY);
    readBattery();
  }
}
}
#endif
extern "C" void official_battery_setup(void) {
#if defined(ARDUINO_ARCH_ESP32)
  vl53lx_wire_i2c_init();
  // INA3221 reset bit; other defaults match the official library reset().
  Wire1.beginTransmission(0x40);Wire1.write(0);Wire1.write(0x80);Wire1.write(0);Wire1.endTransmission();
  heldVoltage=0;sampleValid=false;pending=false;
  // Seed the voltage before the control timer starts. Runtime reads use core0.
  delay(20);readBattery();
  if(xTaskCreatePinnedToCore(batteryWorker,"SFBattery",3072,nullptr,2,&batteryTask,0)!=pdPASS)
    batteryTask=nullptr;
#endif
}
extern "C" void official_battery_step(float voltage[1],uint8_t valid[1]) {
  voltage[0]=0;valid[0]=0;
#if defined(ARDUINO_ARCH_ESP32)
  portENTER_CRITICAL(&batteryLock);
  voltage[0]=heldVoltage;
  valid[0]=sampleValid && uint32_t(micros()-sampledAt)<100000u;
  bool request=batteryTask && !pending;
  if(request)pending=true;
  portEXIT_CRITICAL(&batteryLock);
  if(request)xTaskNotifyGive(batteryTask);
#endif
}
