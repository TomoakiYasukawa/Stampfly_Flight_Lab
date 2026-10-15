#include "official_usb.h"
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <string.h>
namespace {
QueueHandle_t queue=nullptr;
struct Packet {uint16_t length;uint8_t bytes[256];};
uint32_t dropped=0;
void logger(void*) {
  Packet packet;
  for(;;) {
    if(xQueueReceive(queue,&packet,portMAX_DELAY)==pdTRUE)Serial.write(packet.bytes,packet.length);
  }
}
}
#endif
extern "C" void official_usb_setup(void) {
#if defined(ARDUINO_ARCH_ESP32)
  Serial.begin(921600);queue=xQueueCreate(16,sizeof(Packet));
  if(queue)xTaskCreatePinnedToCore(logger,"SFI8USB",4096,nullptr,1,nullptr,0);
#endif
}
extern "C" uint32_t official_usb_queue(const uint8_t frame[190]) {
#if defined(ARDUINO_ARCH_ESP32)
  return official_usb_bytes(frame,190);
#else
  return 0;
#endif
}
extern "C" uint32_t official_usb_bytes(const uint8_t* bytes,uint16_t length) {
#if defined(ARDUINO_ARCH_ESP32)
  Packet packet{};packet.length=length>256?256:length;
  memcpy(packet.bytes,bytes,packet.length);
  if(!queue || xQueueSend(queue,&packet,0)!=pdTRUE)++dropped;
  return dropped;
#else
  return 0;
#endif
}
