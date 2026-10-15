/*
 * bmi270_spi_esp32.h - ESP32 (Arduino) SPI hardware layer for the BMI270.
 *
 * These C-linkage functions are the only hardware-specific part of the block.
 * The real Arduino/SPI implementation is compiled only for the target build;
 * during host (MEX) simulation the functions are stubbed (see the .cpp).
 *
 * StampFly BMI270 SPI wiring:  MOSI=14  SCK=44  MISO=43  CS=46
 */
#ifndef BMI270_SPI_ESP32_H
#define BMI270_SPI_ESP32_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One-time SPI bus / CS pin initialisation. */
void bmi270_hw_init(void);

/* Raw SPI read: send register byte (read-mask already applied by the Bosch
 * API), then clock out `len` bytes into `data`. Returns 0 on success. */
int8_t bmi270_hw_read(uint8_t reg, uint8_t *data, uint32_t len);

/* Raw SPI write: send register byte, then `len` data bytes. Returns 0. */
int8_t bmi270_hw_write(uint8_t reg, const uint8_t *data, uint32_t len);

/* Busy-wait delay in microseconds. */
void bmi270_hw_delay_us(uint32_t us);

/* Print a setup diagnostic over the USB serial console (no-op on host MEX).
 * `stage` identifies the init step, `code` is the result/value to report. */
void bmi270_hw_debug(int32_t stage, int32_t code);

#ifdef __cplusplus
}
#endif

#endif /* BMI270_SPI_ESP32_H */
