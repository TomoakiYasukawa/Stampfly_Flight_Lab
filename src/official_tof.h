#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void official_tof_setup(void);
void official_tof_step(uint8_t mode,int16_t bottom[1],uint8_t newData[1],int16_t front[1],uint8_t status[1]);
/* Continuous bottom acquisition after sensor initialization; no flight-mode gate. */
void official_tof_source_step(int16_t bottom[1],uint8_t newData[1],int16_t front[1],uint8_t status[1]);
/* Same Wire1 bus; base-rate users try the mutex without waiting. */
uint8_t official_i2c_try_lock(void);
void official_i2c_unlock(void);
void official_tof_info(uint32_t info[4]);
/* Completed front frames, valid frames, mm, range status, ready, fault. */
void official_front_info(uint32_t info[6]);
void official_tof_debug(int32_t info[5]);
void official_tof_bus_info(uint32_t info[4]);
/* Frames, valid, errors, selected mm, raw mm, status, objects, stream, error, ready. */
void official_bottom_info(int32_t info[10]);
#ifdef __cplusplus
}
#endif
