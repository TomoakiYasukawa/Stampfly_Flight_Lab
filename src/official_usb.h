#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_usb_setup(void);
uint32_t official_usb_queue(const uint8_t frame[190]);
uint32_t official_usb_bytes(const uint8_t* bytes,uint16_t length);
#ifdef __cplusplus
}
#endif
