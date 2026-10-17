#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_profile_record(uint8_t section,uint32_t start);
uint32_t official_profile_max(uint8_t section);
uint32_t official_now_us(void);
void official_scheduler_info(uint32_t info[4]);
// ESP32 reset reason is read-only telemetry; zero in host simulation.
uint8_t official_reset_reason(void);
void official_runtime_setup(void);
void official_runtime_info(uint32_t info[7]);
#ifdef __cplusplus
}
#endif
