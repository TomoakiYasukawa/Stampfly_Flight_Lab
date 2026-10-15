/*
 * i2c_esp32.h - Shared ESP32 (Arduino) I2C hardware layer for StampFly_lib.
 *
 * One bus instance (Wire1: SDA=3, SCL=4, 400 kHz) is shared by every I2C device
 * block (INA3221, and later VL53L3CX / BMM150). The C-linkage functions are the
 * only hardware-specific part; during host (MEX) simulation they are stubbed so
 * the S-functions compile and return zeros.
 *
 * StampFly I2C wiring:  SDA=3  SCL=4  (Wire1 @ 400 kHz)
 */
#ifndef I2C_ESP32_H
#define I2C_ESP32_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One-time init of the shared StampFly I2C bus. Idempotent: safe to call from
 * every device block's Start method; only the first call begins the bus. */
void stampfly_i2c_init(void);

/* Read `len` bytes from 7-bit device `addr`, starting at register `reg`
 * (repeated-start). Returns 0 on success, negative on error. */
int8_t stampfly_i2c_read(uint8_t addr, uint8_t reg, uint8_t *data, uint32_t len);

/* Write `len` bytes to 7-bit device `addr`, starting at register `reg`.
 * Returns 0 on success, negative on error. */
int8_t stampfly_i2c_write(uint8_t addr, uint8_t reg, const uint8_t *data, uint32_t len);

/* 16-bit register-index variants (register address sent MSB first, repeated
 * start for reads). Required by the VL53Lx ToF family, which uses 16-bit
 * register indices rather than the 8-bit indices used by the INA3221.
 * Returns 0 on success, negative on error. */
int8_t stampfly_i2c_read16(uint8_t addr, uint16_t reg, uint8_t *data, uint32_t len);
int8_t stampfly_i2c_write16(uint8_t addr, uint16_t reg, const uint8_t *data, uint32_t len);

/* Busy/blocking microsecond delay. Needed by sensor APIs that take a delay
 * callback (e.g. the Bosch BMM150 SensorAPI). On the host MEX build it is a
 * no-op. */
void stampfly_delay_us(uint32_t us);

#ifdef __cplusplus
}
#endif

#endif /* I2C_ESP32_H */
