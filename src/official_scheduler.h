#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_profile_record(uint8_t section,uint32_t start);
uint32_t official_profile_max(uint8_t section);
uint32_t official_now_us(void);
void official_scheduler_info(uint32_t info[4]);
#ifdef __cplusplus
}
#endif
