#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void bmm150_logger_setup(uint8_t address);
/* Base rate only copies a cache and notifies core0; it never waits for I2C.
 * flags: valid, new since previous base tick, last error code.
 * info: samples, time us, age us, last read us, max read us, errors. */
void bmm150_logger_step(float mag[3], uint8_t flags[3], uint32_t info[6]);
#ifdef __cplusplus
}
#endif
