/*
 * spi_esp32.h - Shared ESP32 (Arduino) SPI bus for StampFly_lib.
 *
 * StampFly's BMI270 IMU and PMW3901MB optical-flow sensor share one FSPI bus
 * (MOSI=14 SCK=44 MISO=43), each on its own chip-select (BMI270 CS=46,
 * PMW3901 CS=12). To avoid two SPIClass objects fighting over the same
 * peripheral, every device uses the single global Arduino `SPI` instance; this
 * module initialises that bus once (with the StampFly pins) and parks both chip
 * selects high. Per-transfer clock/mode are set by each driver via
 * SPI.beginTransaction(), so the two devices coexist on the shared bus.
 *
 * Calling stampfly_spi_init() before the global `SPI` is used with explicit pins
 * also makes libraries that call the pin-less `SPI.begin()` internally (e.g. the
 * Bitcraze PMW3901 driver) a no-op there: ESP32's SPIClass::begin() returns
 * early once the bus is already initialised, so the StampFly pins persist.
 *
 * Host (MEX) simulation: stubbed to a no-op (see the .cpp).
 */
#ifndef STAMPFLY_SPI_ESP32_H
#define STAMPFLY_SPI_ESP32_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* StampFly shared-SPI chip selects (also usable by the device drivers). */
#define STAMPFLY_SPI_CS_BMI270    46
#define STAMPFLY_SPI_CS_PMW3901   12

/* One-time init of the shared global `SPI` bus on the StampFly FSPI pins, with
 * both chip selects driven high (deselected). Idempotent: safe to call from
 * every device's setup; only the first call touches the hardware. */
void stampfly_spi_init(void);

#ifdef __cplusplus
}
#endif

#endif /* STAMPFLY_SPI_ESP32_H */
