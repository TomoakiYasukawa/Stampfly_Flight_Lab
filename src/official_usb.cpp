#include "official_usb.h"
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <string.h>
#include "official_scheduler.h"
namespace {
QueueHandle_t queue=nullptr;
struct Packet {uint16_t length;uint8_t bytes[256];};
uint32_t dropped=0;
portMUX_TYPE dropLock=portMUX_INITIALIZER_UNLOCKED;
void countDrop(){portENTER_CRITICAL(&dropLock);++dropped;portEXIT_CRITICAL(&dropLock);}
uint32_t dropCount(){portENTER_CRITICAL(&dropLock);uint32_t n=dropped;portEXIT_CRITICAL(&dropLock);return n;}
bool hostConnected() {
#if ARDUINO_USB_CDC_ON_BOOT && ARDUINO_USB_MODE
  return HWCDC::isConnected();
#else
  return true;
#endif
}
void logger(void*) {
  Packet packet;
  for(;;) {
    if(xQueueReceive(queue,&packet,portMAX_DELAY)==pdTRUE) {
      // USBがない飛行中はドライバーへ書かず、無線ログだけを継続します。
      if(!hostConnected()){countDrop();continue;}
      // 部分書き込みは最大20msだけ再試行し、停止したPCで永久に待ちません。
      size_t offset=0;
      const TickType_t begun=xTaskGetTickCount();
      while(offset<packet.length && hostConnected() &&
            xTaskGetTickCount()-begun<pdMS_TO_TICKS(20)) {
        size_t written=Serial.write(packet.bytes+offset,packet.length-offset);
        offset+=written;
        if(offset<packet.length)vTaskDelay(pdMS_TO_TICKS(1));
      }
      if(offset<packet.length)countDrop();
    }
  }
}
}
#endif
extern "C" void official_usb_setup(void) {
#if defined(ARDUINO_ARCH_ESP32)
  Serial.setTxBufferSize(4096);Serial.begin(921600);queue=xQueueCreate(16,sizeof(Packet));
#if ARDUINO_USB_CDC_ON_BOOT && ARDUINO_USB_MODE
  Serial.setTxTimeoutMs(2);
#endif
  official_runtime_setup();
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
  if(!hostConnected())return dropCount();
  if(!queue || xQueueSend(queue,&packet,0)!=pdTRUE)countDrop();
  return dropCount();
#else
  return 0;
#endif
}
