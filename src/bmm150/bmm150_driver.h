/*
 * bmm150_driver.h - Bosch BMM150 3-axis magnetometer for StampFly_lib.
 *
 * Bus    : I2C (shared Wire1: SDA=3 SCL=4 @ 400 kHz). The 7-bit address is
 *          selectable on the part via the SDO/CSB pins (0x10..0x13); the Bosch
 *          default is 0x10 (BMM150_DEFAULT_I2C_ADDRESS).
 * Outputs: compensated magnetic field [uT] for the X/Y/Z axes, in the BMM150
 *          sensor frame (apply body-axis remap downstream).
 *
 * The heavy lifting (chip detection, trim readout, temperature-compensated
 * field calculation in micro-tesla) is done by the official Bosch BMM150
 * SensorAPI (src/bmm150/upstream). This thin wrapper binds that API to the
 * shared StampFly I2C layer, so the same code compiles for host MEX simulation
 * (hardware stubbed -> zeros) and for ESP32 code generation.
 */
#ifndef BMM150_DRIVER_H
#define BMM150_DRIVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One-time init: bring up the shared I2C bus, detect the BMM150 at `i2c_addr`
 * (7-bit, 0x10..0x13), apply the "Enhanced regular" repetition preset
 * (nXY=15, nZ=27), raise the data rate to the 30 Hz device maximum and enter
 * Normal (continuous) power mode. Call from the System object's setup method.
 *
 * Output rate: the Bosch presets recommend 10 Hz but the ODR register goes to
 * 30 Hz, and Enhanced's 16.7 ms measurement time fits the 33 ms period. Poll
 * the block at or below 30 Hz; faster only re-reads the same sample. */
void bmm150_mag_setup(uint8_t i2c_addr);

/* Acquire one sample.
 *   mag    : [3] compensated magnetic field (micro-tesla, sensor X/Y/Z)
 *   status : [1] 1 = read OK, 0 = not ready / error
 */
void bmm150_mag_step(float mag[3], uint8_t status[1]);

/* Caller owns the complete shared Wire1 transaction via official_i2c mutex.
 * Return Bosch result; fresh is set only when device DRDY was set. */
int8_t bmm150_mag_poll(float mag[3], uint8_t fresh[1]);

#ifdef __cplusplus
}
#endif

#endif /* BMM150_DRIVER_H */
