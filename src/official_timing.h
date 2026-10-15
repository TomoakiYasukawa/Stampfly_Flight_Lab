#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_timing_end(uint32_t start,uint8_t fresh,const uint8_t applied[4],const uint32_t pwm[4],uint32_t result[8]);
#ifdef __cplusplus
}
#endif
