#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_radio_setup(uint8_t channel);
void official_radio_receive(const uint8_t source[6],const uint8_t* data,int length);
void official_radio_step(float stick[6],uint8_t arm[1],uint8_t connected[1],uint8_t ahrs[1]);
void official_radio_events(uint8_t flip[1],uint8_t newPacket[1],uint8_t error[1]);
void official_radio_basic_events(uint8_t newPacket[1],uint8_t error[1]);
void official_radio_info(uint32_t info[8],float stick[6]);
void official_radio_telemetry(const float values[27],uint8_t altFlag,uint8_t state,uint16_t front);
uint8_t official_radio_send(const float values[27],const float gains[20],uint8_t altFlag,uint8_t state,uint16_t front);
#ifdef __cplusplus
}
#endif
