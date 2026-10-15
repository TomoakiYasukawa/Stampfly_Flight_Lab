#ifndef VL53L3CX_BOTTOM_OFFICIAL128_DRIVER_H
#define VL53L3CX_BOTTOM_OFFICIAL128_DRIVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void vl53l3cx_bottom_official128_setup(void);

/*
 * metrics[0] signal rate (MCPS)
 * metrics[1] ambient rate (MCPS)
 * metrics[2] sigma (mm)
 * raw_range_m is the farthest positive target from the latest completed
 * measurement regardless of RangeStatus; zero means no target this step.
 * metrics[3] number of objects
 * metrics[4] effective SPAD count
 * metrics[5] stream count
 * metrics[6] completed measurement count
 * metrics[7] accepted status-0 measurement count
 * metrics[8] no-object measurement count
 * metrics[9] status-12 measurement count
 */
void vl53l3cx_bottom_official128_step(
    float range_m[1],
    float raw_range_m[1],
    uint8_t range_status[1],
    uint8_t fresh_valid[1],
    uint8_t new_data[1],
    float metrics[10]);

#ifdef __cplusplus
}
#endif

#endif
