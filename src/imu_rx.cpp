#include "imu_rx.h"
#include <Arduino.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_netif.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <nvs_flash.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

namespace {
constexpr size_t kMaxFrameBytes = 246;
constexpr size_t kQueueDepth = 64;
constexpr uint8_t kBroadcast[6] = {255, 255, 255, 255, 255, 255};
struct RadioFrame {
  uint8_t length;
  uint8_t bytes[kMaxFrameBytes];
};
QueueHandle_t rxQueue = nullptr;
uint8_t radioChannel = 3;
uint32_t forwardedCount = 0;
char command[160]{};
size_t commandLength = 0;
bool statusPeerReady = false;

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

void onReceive(const esp_now_recv_info_t *, const uint8_t *data, int length) {
  if (rxQueue == nullptr || data == nullptr) return;
  const bool isV1 = length == 37 && memcmp(data, "SFI1", 4) == 0;
  const bool isV2 = length == 63 && memcmp(data, "SFI2", 4) == 0;
  const bool isV3 = length == 93 && memcmp(data, "SFI3", 4) == 0;
  const bool isV4 = length == 106 && memcmp(data, "SFI4", 4) == 0;
  const bool isV5 = length == 111 && memcmp(data, "SFI5", 4) == 0;
  const bool isV6 = length == 114 && memcmp(data, "SFI6", 4) == 0;
  const bool isV7 = length == 182 && memcmp(data, "SFI7", 4) == 0;
  const bool isV8 = length == 190 && memcmp(data, "SFI8", 4) == 0;
  const bool isCommands = length == 190 && memcmp(data, "SFIX", 4) == 0;
  const bool isSensors = length == 246 && memcmp(data, "SFIY", 4) == 0;
  if (!isV1 && !isV2 && !isV3 && !isV4 && !isV5 && !isV6 &&
      !isV7 && !isV8 && !isCommands && !isSensors) return;
  const uint16_t expected = static_cast<uint16_t>(data[length - 2]) |
                            (static_cast<uint16_t>(data[length - 1]) << 8);
  if (crc16(data, static_cast<size_t>(length - 2)) != expected) return;
  RadioFrame frame{};
  frame.length = static_cast<uint8_t>(length);
  memcpy(frame.bytes, data, static_cast<size_t>(length));
  xQueueSend(rxQueue, &frame, 0);
}

bool broadcastLedState(uint8_t mode) {
  if (!statusPeerReady) return false;
  uint8_t message[7] = {'S', 'F', 'L', '1', mode, 0, 0};
  const uint16_t crc = crc16(message, 5);
  message[5] = static_cast<uint8_t>(crc);
  message[6] = static_cast<uint8_t>(crc >> 8);
  return esp_now_send(kBroadcast, message, sizeof(message)) == ESP_OK;
}

bool broadcastFlightCommand(uint16_t sequence, uint8_t operation,
                            uint16_t climb, uint16_t hover, uint16_t land) {
  if (!statusPeerReady) return false;
  uint8_t message[15] = {'S', 'F', 'C', '1',
                         static_cast<uint8_t>(sequence),
                         static_cast<uint8_t>(sequence >> 8), operation,
                         static_cast<uint8_t>(climb),
                         static_cast<uint8_t>(climb >> 8),
                         static_cast<uint8_t>(hover),
                         static_cast<uint8_t>(hover >> 8),
                         static_cast<uint8_t>(land),
                         static_cast<uint8_t>(land >> 8), 0, 0};
  const uint16_t crc = crc16(message, 13);
  message[13] = static_cast<uint8_t>(crc);
  message[14] = static_cast<uint8_t>(crc >> 8);
  return esp_now_send(kBroadcast, message, sizeof(message)) == ESP_OK;
}

bool broadcastHeightTuning(uint16_t sequence,const int16_t *values) {
  if (!statusPeerReady || values == nullptr) return false;
  uint8_t message[28] = {'S','F','P','1',
                         static_cast<uint8_t>(sequence),
                         static_cast<uint8_t>(sequence >> 8),1,9};
  for (int k = 0; k < 9; ++k) {
    const uint16_t value = static_cast<uint16_t>(values[k]);
    message[8 + 2*k] = static_cast<uint8_t>(value);
    message[9 + 2*k] = static_cast<uint8_t>(value >> 8);
  }
  const uint16_t crc = crc16(message,26);
  message[26] = static_cast<uint8_t>(crc);
  message[27] = static_cast<uint8_t>(crc >> 8);
  return esp_now_send(kBroadcast,message,sizeof(message)) == ESP_OK;
}

void handleCommand() {
  command[commandLength] = '\0';
  if (strcmp(command, "PING") == 0) {
    Serial.print("PONG,");
    Serial.println(radioChannel);
  } else if (strncmp(command, "CH=", 3) == 0) {
    char *end = nullptr;
    const long requested = strtol(command + 3, &end, 10);
    if (end != nullptr && *end == '\0' && requested >= 1 && requested <= 13) {
      const esp_err_t result = esp_wifi_set_channel(
          static_cast<uint8_t>(requested), WIFI_SECOND_CHAN_NONE);
      if (result == ESP_OK) {
        radioChannel = static_cast<uint8_t>(requested);
        Serial.print("OK,");
        Serial.println(radioChannel);
      } else {
        Serial.println("ERR,CHANNEL");
      }
    } else {
      Serial.println("ERR,CHANNEL");
    }
  } else if (strcmp(command, "LED=0") == 0 ||
             strcmp(command, "LED=1") == 0 ||
             strcmp(command, "LED=2") == 0) {
    const uint8_t mode = static_cast<uint8_t>(command[4] - '0');
    if (broadcastLedState(mode)) {
      Serial.print("LEDACK,");
      Serial.println(mode);
    } else {
      Serial.println("ERR,LED");
    }
  } else if (strncmp(command, "TUNE,", 5) == 0) {
    unsigned int sequence = 0, nameSpace = 0, count = 0;
    unsigned int p[9]{};
    char extra = 0;
    const int fields = sscanf(command,
        "TUNE,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u%c",
        &sequence,&nameSpace,&count,&p[0],&p[1],&p[2],&p[3],&p[4],
        &p[5],&p[6],&p[7],&p[8],&extra);
    bool valid = fields == 12 && sequence <= 65535 &&
                 nameSpace == 1 && count == 9;
    int16_t values[9]{};
    for (int k = 0; k < 9; ++k) {
      valid = valid && p[k] <= 32767;
      values[k] = static_cast<int16_t>(p[k]);
    }
    if (!valid) {
      Serial.println("ERR,TUNE");
    } else if (broadcastHeightTuning(static_cast<uint16_t>(sequence),values)) {
      Serial.print("TUNEACK,");
      Serial.println(sequence);
    } else {
      Serial.println("ERR,TUNE_SEND");
    }
  } else if (strncmp(command, "CTL,", 4) == 0) {
    unsigned int sequence = 0, operation = 0, climb = 0, hover = 0, land = 0;
    char extra = 0;
    const int fields = sscanf(command, "CTL,%u,%u,%u,%u,%u%c",
                              &sequence, &operation, &climb, &hover, &land,
                              &extra);
    if (fields != 5 || sequence > 65535 || operation > 4 ||
        climb < 1 || climb > 1000 || hover < 20 || hover > 500 ||
        land < 1 || land > 1000) {
      Serial.println("ERR,CTL");
    } else if (broadcastFlightCommand(static_cast<uint16_t>(sequence),
                 static_cast<uint8_t>(operation),
                 static_cast<uint16_t>(climb),
                 static_cast<uint16_t>(hover),
                 static_cast<uint16_t>(land))) {
      Serial.print("CTLACK,");
      Serial.println(sequence);
    } else {
      Serial.println("ERR,CTL_SEND");
    }
  } else {
    Serial.println("ERR,COMMAND");
  }
  commandLength = 0;
}

void pollCommands() {
  for (int i = 0; i < 32 && Serial.available() > 0; ++i) {
    const char c = static_cast<char>(Serial.read());
    if (c == '\n' || c == '\r') {
      if (commandLength > 0) handleCommand();
    } else if (commandLength < sizeof(command) - 1) {
      command[commandLength++] = c;
    } else {
      commandLength = 0;
    }
  }
}
}

extern "C" void imu_rx_init(uint8_t channel, uint32_t baudRate) {
  if (channel < 1 || channel > 13) channel = 3;
  radioChannel = channel;
  Serial.setTxBufferSize(1024);
  Serial.begin(baudRate);
  rxQueue = xQueueCreate(kQueueDepth, sizeof(RadioFrame));
  if (rxQueue == nullptr) return;
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
      esp_wifi_set_channel(radioChannel, WIFI_SECOND_CHAN_NONE);
  if (channelResult != ESP_OK || esp_now_init() != ESP_OK) return;
  esp_now_peer_info_t peer{};
  memcpy(peer.peer_addr, kBroadcast, sizeof(kBroadcast));
  peer.channel = 0;  // Follow the channel selected by the PC app.
  peer.ifidx = WIFI_IF_STA;
  peer.encrypt = false;
  statusPeerReady = esp_now_add_peer(&peer) == ESP_OK ||
                    esp_now_is_peer_exist(kBroadcast);
  esp_now_register_recv_cb(onReceive);
  Serial.print("READY,");
  Serial.println(radioChannel);
}

extern "C" void imu_rx_step(uint32_t *forwarded, uint8_t *channel) {
  pollCommands();
  RadioFrame frame{};
  for (int i = 0; i < 4; ++i) {
    if (rxQueue == nullptr || uxQueueMessagesWaiting(rxQueue) == 0 ||
        Serial.availableForWrite() < static_cast<int>(kMaxFrameBytes)) break;
    if (xQueueReceive(rxQueue, &frame, 0) != pdTRUE) break;
    if (Serial.write(frame.bytes, frame.length) == frame.length)
      ++forwardedCount;
  }
  if (forwarded != nullptr) *forwarded = forwardedCount;
  if (channel != nullptr) *channel = radioChannel;
}
