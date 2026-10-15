#include "imu_tx.h"
#include "official_radio.h"
#include <Arduino.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_netif.h>
#include <nvs_flash.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <string.h>

namespace {
constexpr uint8_t kBroadcast[6] = {255, 255, 255, 255, 255, 255};
bool ready = false;
struct RadioPacket {uint8_t destination[6];uint16_t length;uint8_t bytes[250];};
QueueHandle_t radioQueue=nullptr;
void radioWorker(void*) {
  RadioPacket p;
  for(;;)if(xQueueReceive(radioQueue,&p,portMAX_DELAY)==pdTRUE)
    esp_now_send(p.destination,p.bytes,p.length);
}
volatile uint8_t remoteLedMode = 0;
volatile uint32_t remoteLedAtMs = 0;
portMUX_TYPE flightLock = portMUX_INITIALIZER_UNLOCKED;
uint8_t flightOperation = 0;
uint16_t flightSequence = 0;
uint16_t climbMmPerS = 100;
uint16_t hoverMm = 150;
uint16_t landMmPerS = 80;
uint32_t flightLastAtMs = 0;
bool flightReceived = false;
bool emergencyLatched = false;
int16_t tuningValues[9]{};
uint16_t tuningSequence = 0;
bool tuningReceived = false;

uint16_t crc16(const uint8_t *bytes, size_t count) {
  uint16_t crc = 0xffff;
  for (size_t i = 0; i < count; ++i) {
    crc ^= static_cast<uint16_t>(bytes[i]) << 8;
    for (uint8_t bit = 0; bit < 8; ++bit)
      crc = (crc & 0x8000) ? static_cast<uint16_t>((crc << 1) ^ 0x1021)
                           : static_cast<uint16_t>(crc << 1);
  }
  return crc;
}

void onStatus(const esp_now_recv_info_t *info, const uint8_t *data, int length) {
  if (data == nullptr) return;
  if (length == 25) {
    official_radio_receive(info->src_addr,data,length);
    return;
  }
  // Count other traffic for diagnostics; it does not renew the flight link.
  official_radio_receive(info->src_addr,data,length);
  if (length == 28 && memcmp(data, "SFP1", 4) == 0 &&
      data[6] == 1 && data[7] == 9) {
    const uint16_t expected = static_cast<uint16_t>(data[26]) |
                              (static_cast<uint16_t>(data[27]) << 8);
    if (crc16(data, 26) != expected) return;
    const uint16_t sequence = static_cast<uint16_t>(data[4]) |
                              (static_cast<uint16_t>(data[5]) << 8);
    portENTER_CRITICAL(&flightLock);
    if (!tuningReceived || sequence == tuningSequence ||
        static_cast<uint16_t>(sequence - tuningSequence) < 32768) {
      for (int k = 0; k < 9; ++k) {
        tuningValues[k] = static_cast<int16_t>(
            static_cast<uint16_t>(data[8 + 2*k]) |
            (static_cast<uint16_t>(data[9 + 2*k]) << 8));
      }
      tuningSequence = sequence;
      tuningReceived = true;
    }
    portEXIT_CRITICAL(&flightLock);
    return;
  }
  if (length == 7 && memcmp(data, "SFL1", 4) == 0 && data[4] <= 2) {
    const uint16_t expected = static_cast<uint16_t>(data[5]) |
                              (static_cast<uint16_t>(data[6]) << 8);
    if (crc16(data, 5) != expected) return;
    remoteLedMode = data[4];
    remoteLedAtMs = millis();
    return;
  }
  if (length != 15 || memcmp(data, "SFC1", 4) != 0 || data[6] > 4) return;
  const uint16_t expected = static_cast<uint16_t>(data[13]) |
                            (static_cast<uint16_t>(data[14]) << 8);
  if (crc16(data, 13) != expected) return;
  const uint16_t sequence = static_cast<uint16_t>(data[4]) |
                            (static_cast<uint16_t>(data[5]) << 8);
  const uint16_t climb = static_cast<uint16_t>(data[7]) |
                         (static_cast<uint16_t>(data[8]) << 8);
  const uint16_t hover = static_cast<uint16_t>(data[9]) |
                         (static_cast<uint16_t>(data[10]) << 8);
  const uint16_t land = static_cast<uint16_t>(data[11]) |
                        (static_cast<uint16_t>(data[12]) << 8);
  if (climb < 1 || climb > 1000 || hover < 20 || hover > 500 ||
      land < 1 || land > 1000) return;
  portENTER_CRITICAL(&flightLock);
  if (data[6] == 0) {
    flightLastAtMs = millis();
  } else if (!flightReceived || sequence == flightSequence ||
             static_cast<uint16_t>(sequence - flightSequence) < 32768) {
    flightOperation = data[6];
    flightSequence = sequence;
    climbMmPerS = climb;
    hoverMm = hover;
    landMmPerS = land;
    flightLastAtMs = millis();
    flightReceived = true;
    if (data[6] == 3) emergencyLatched = true;
    if (data[6] == 4) emergencyLatched = false;
  }
  portEXIT_CRITICAL(&flightLock);
}
}

extern "C" void imu_tx_init(uint8_t channel) {
  if (ready || channel < 1 || channel > 13) return;
  nvs_flash_init();
  esp_netif_init();
  esp_event_loop_create_default();
  esp_netif_create_default_wifi_sta();
  wifi_init_config_t config = WIFI_INIT_CONFIG_DEFAULT();
  if (esp_wifi_init(&config) != ESP_OK) return;
  esp_wifi_set_storage(WIFI_STORAGE_RAM);
  esp_wifi_set_mode(WIFI_MODE_STA);
  if (esp_wifi_start() != ESP_OK) return;
  const esp_err_t channelResult =
      esp_wifi_set_channel(channel, WIFI_SECOND_CHAN_NONE);
  if (channelResult != ESP_OK || esp_now_init() != ESP_OK) return;
  esp_now_peer_info_t peer{};
  memcpy(peer.peer_addr, kBroadcast, sizeof(kBroadcast));
  peer.channel = channel;
  peer.ifidx = WIFI_IF_STA;
  peer.encrypt = false;
  ready = esp_now_add_peer(&peer) == ESP_OK ||
          esp_now_is_peer_exist(kBroadcast);
  esp_now_register_recv_cb(onStatus);
  radioQueue=xQueueCreate(16,sizeof(RadioPacket));
  if(radioQueue)xTaskCreatePinnedToCore(radioWorker,"SFRadio",4096,nullptr,2,nullptr,0);
}

extern "C" uint8_t imu_tx_radio_queue(const uint8_t destination[6],const uint8_t* bytes,uint16_t length) {
  if(!ready || !radioQueue || !bytes || length>250)return 0;
  RadioPacket p{};memcpy(p.destination,destination,6);p.length=length;memcpy(p.bytes,bytes,length);
  return xQueueSend(radioQueue,&p,0)==pdTRUE;
}

extern "C" uint8_t imu_tx_send(const uint8_t *frame, uint16_t length) {
  if (!ready || frame == nullptr ||
      (length != 37 && length != 63 && length != 93 && length != 106 &&
       length != 111 && length != 114 && length != 182 &&
       length != 190)) return 0;
  // 1 means queued by ESP-NOW; it does not prove the receiver got the frame.
  return imu_tx_radio_queue(kBroadcast,frame,length);
}

extern "C" uint8_t imu_tx_led_mode(void) {
  const uint8_t mode = remoteLedMode;
  if (mode == 0 || static_cast<uint32_t>(millis() - remoteLedAtMs) > 2500)
    return 0;
  return mode;
}

extern "C" void imu_tx_flight_command(uint8_t *operation, uint16_t *sequence,
                                      uint16_t *climb, uint16_t *hover,
                                      uint16_t *land, uint8_t *linkAlive,
                                      uint8_t *emergencyStop) {
  portENTER_CRITICAL(&flightLock);
  if (operation) *operation = flightOperation;
  if (sequence) *sequence = flightSequence;
  if (climb) *climb = climbMmPerS;
  if (hover) *hover = hoverMm;
  if (land) *land = landMmPerS;
  if (linkAlive) *linkAlive = flightReceived &&
      static_cast<uint32_t>(millis() - flightLastAtMs) <= 1500 ? 1 : 0;
  if (emergencyStop) *emergencyStop = emergencyLatched ? 1 : 0;
  portEXIT_CRITICAL(&flightLock);
}

extern "C" void imu_tx_tuning_request(int16_t *values9,
                                        uint16_t *sequence,
                                        uint8_t *pending) {
  portENTER_CRITICAL(&flightLock);
  if (values9 != nullptr)
    memcpy(values9, tuningValues, sizeof(tuningValues));
  if (sequence != nullptr) *sequence = tuningSequence;
  if (pending != nullptr) *pending = tuningReceived ? 1 : 0;
  portEXIT_CRITICAL(&flightLock);
}
