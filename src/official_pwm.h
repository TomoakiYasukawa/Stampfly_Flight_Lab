#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_pwm_setup(void);
void official_pwm_step(const uint8_t counts[4], uint8_t enabled,
                       uint8_t applied[4], uint32_t info[4]);
void official_pwm_stop(void);
#ifdef __cplusplus
}
#endif
