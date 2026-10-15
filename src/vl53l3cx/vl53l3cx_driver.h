/*
 * vl53l3cx_driver.h - ST VL53L3CX time-of-flight distance sensor for StampFly_lib.
 *
 * Bus : I2C (shared Wire1, SDA=3 SCL=4 @ 400 kHz). The 7-bit device address is
 *       passed in, so several VL53L3CX can share the bus at distinct addresses
 *       (StampFly carries two: e.g. a downward and a forward sensor).
 *
 * Implementation note
 * -------------------
 * This C interface is implemented by vl53l3cx_uld_wrapper.cpp, a thin wrapper
 * over ST's full VL53L3CX Ultra-Lite Driver (ULD: histogram post-processing,
 * multi-target, crosstalk/offset calibration) as packaged by stm32duino's
 * VL53LX class. The ULD sources live UNMODIFIED in src/vl53l3cx/uld
 * (github.com/stm32duino/VL53L3CX); only the wrapper is StampFly-specific.
 *
 * Multiple sensors: the part has no hardware address-select pin and every unit
 * powers up at 0x29, so two on one bus must be brought up at distinct addresses
 * before ranging (XSHUT sequencing + a write to I2C_SLAVE__DEVICE_ADDRESS).
 * vl53l3cx_bringup() performs that sequence (bottom GPIO 7 keeps 0x29, front
 * GPIO 9 moves to 0x2A); vl53l3cx_setup()/vl53l3cx_step() then init and read
 * the sensor at the given 7-bit address.
 *
 * Update rate
 * -----------
 * The VL53L3CX ranges continuously (BACKTOBACK), so the output rate is set by
 * the measurement timing budget alone - there is no inter-measurement period in
 * play. The ULD splits the budget into six internal ranging periods:
 *
 *   timing_budget_us = 6 * range_config_timeout_us + 1700
 *
 * ST's VL53LX_DataInit() leaves the budget at 33333 us (~30 Hz), and the
 * M5StampFly firmware keeps that value; it is a default, NOT a device limit.
 * Halving it roughly doubles the rate:
 *
 *   budget    rate     note
 *   33 ms     ~30 Hz   ULD / M5StampFly default
 *   20 ms     ~50 Hz   StampFly default here
 *   15 ms     ~65 Hz
 *   10 ms    ~100 Hz   short range only; verify signal quality
 *
 * IMPORTANT: the ULD only rejects a budget below its 1700 us guard. Anything
 * above that is accepted even when the sensor cannot integrate enough signal,
 * in which case max range and accuracy degrade SILENTLY - RangeStatus starts
 * reporting sigma/signal failures instead of an error at setup. Lower the
 * budget one step at a time and watch RangeStatus. Shorter distance modes
 * tolerate shorter budgets.
 *
 * Note also that the histogram post-processing merges up to six consecutive
 * measurements for range extension (ULD tuning HIST_MERGE_MAX_SIZE = 6), so the
 * reported range carries some inherent smoothing on top of the budget period.
 */
#ifndef VL53L3CX_DRIVER_H
#define VL53L3CX_DRIVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Default (power-up) 7-bit I2C address shared by every VL53L3CX. */
#define VL53L3CX_DEFAULT_ADDR  0x29u

/* StampFly final 7-bit addresses after bring-up (see vl53l3cx_bringup). */
#define VL53L3CX_BOTTOM_ADDR   0x29u   /* downward sensor (XSHUT GPIO 7) */
#define VL53L3CX_FRONT_ADDR    0x2Au   /* forward  sensor (XSHUT GPIO 9) */

/* StampFly two-sensor bring-up, mirroring the M5StampFly firmware tof_init():
 * hold both ToF in reset (XSHUT low), raise the front sensor (GPIO 9) and move
 * it from 0x29 to 0x2A, then raise the bottom sensor (GPIO 7) which keeps 0x29.
 * Idempotent (runs the sequence at most once) and a no-op during host MEX
 * simulation, so every VL53L3CX block can call it before vl53l3cx_setup(). */
void vl53l3cx_bringup(void);

/* Distance-mode selector for vl53l3cx_setup(). AUTO keeps the historical
 * StampFly split (bottom = MEDIUM, front = LONG) so existing models are
 * unaffected; the explicit modes override it per block. */
#define VL53L3CX_DM_AUTO    0u
#define VL53L3CX_DM_SHORT   1u
#define VL53L3CX_DM_MEDIUM  2u
#define VL53L3CX_DM_LONG    3u

/* Target-selection selector for vl53l3cx_setup(). The VL53L3CX histogram
 * engine can report up to four objects per measurement. FARTHEST is right for
 * the downward sensor: the nearer returns are the crosstalk phantom from the
 * cover/frame, and the floor is the farthest valid target (what the M5StampFly
 * firmware does). NEAREST is right for the forward sensor, where the closest
 * obstacle is the one that matters. AUTO applies exactly that split by slot. */
#define VL53L3CX_TS_AUTO      0u
#define VL53L3CX_TS_NEAREST   1u
#define VL53L3CX_TS_FARTHEST  2u

/* One-time init for the sensor at 7-bit address `i2c_addr`: bring up the shared
 * I2C bus, load the default configuration and start continuous ranging. Several
 * sensors (distinct addresses) may each be set up. Call from the System object.
 *
 *   distance_mode    : one of the VL53L3CX_DM_* selectors above
 *   timing_budget_us : measurement timing budget (see "Update rate" above);
 *                      0 leaves the ULD default (33333 us) untouched
 *   target_select    : one of the VL53L3CX_TS_* selectors above
 */
void vl53l3cx_setup(uint8_t i2c_addr, uint8_t distance_mode,
                    uint32_t timing_budget_us, uint8_t target_select);

/* Acquire one sample from the sensor at `i2c_addr` (non-blocking: returns the
 * most recent completed range).
 *   range_m      : [1] distance to target (metres)
 *   range_status : [1] WHY: the sensor's own quality code for this measurement
 *                      (0/6/11 valid; 1 sigma, 2 signal, 13 min-range, 255 no
 *                      target), or a driver fault (90 I2C, 101..105 setup stage
 *                      1..5). Codes <= 14 and 255 are the sensor's, >= 90 ours.
 *   status       : [1] 1 = range_m is valid (stays high between measurements
 *                      while the last range is still good), 0 = dropout /
 *                      not ready / I2C error
 */
void vl53l3cx_step(uint8_t i2c_addr, float range_m[1],
                   uint8_t range_status[1], uint8_t status[1]);

#ifdef __cplusplus
}
#endif

#endif /* VL53L3CX_DRIVER_H */
