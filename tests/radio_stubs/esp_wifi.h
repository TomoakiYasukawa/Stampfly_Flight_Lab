#pragma once
#include <stdint.h>
#include <string.h>
inline int esp_wifi_get_mac(int,uint8_t* mac){const uint8_t value[6]={0x70,0xaf,0x09,0xdf,0xa6,0xc4};memcpy(mac,value,6);return 0;}
