#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_status_setup(void);
uint8_t official_user_button(void);
void official_status_write(uint32_t color1,uint32_t color2,uint32_t frequency,uint8_t restart);
#ifdef __cplusplus
}
#endif
