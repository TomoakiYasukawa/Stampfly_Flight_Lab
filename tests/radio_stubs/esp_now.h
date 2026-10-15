#pragma once
#include <stdint.h>
#define ESP_OK 0
#define WIFI_IF_STA 0
struct esp_now_peer_info_t{uint8_t peer_addr[6];uint8_t channel;uint8_t ifidx;};
inline int esp_now_add_peer(const esp_now_peer_info_t*){return 0;}
inline bool esp_now_is_peer_exist(const uint8_t*){return true;}
