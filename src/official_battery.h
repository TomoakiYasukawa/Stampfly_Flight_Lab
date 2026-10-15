#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_battery_setup(void);
void official_battery_step(float voltage[1],uint8_t valid[1]);
#ifdef __cplusplus
}
#endif
