/*
 * bmi270_spi_esp32.cpp - ESP32-S3 / Arduino SPI implementation for the BMI270.
 *
 * Target build  : shared global `SPI` bus (MOSI=14, SCK=44, MISO=43, CS=46),
 *                 set up by the common spi_esp32 layer so the BMI270 and the
 *                 PMW3901 optical-flow sensor coexist on one SPIClass.
 * Host MEX build : stubbed out so the S-function compiles for simulation
 *                  (simulation returns zero sensor data).
 *
 * The Bosch BMI2 API has already applied the SPI read mask (0x80) to the
 * register address for reads and added the dummy byte to `len`, so these
 * functions only perform a raw, addressed SPI burst.
 */
#include "bmi270_spi_esp32.h"

#ifndef MATLAB_MEX_FILE
/* ============================ TARGET (ESP32) ============================ */
#include <Arduino.h>
#include <SPI.h>
#include "spi_esp32.h"               /* shared StampFly SPI bus + CS pins */

#define BMI270_CS_PIN   STAMPFLY_SPI_CS_BMI270
#define BMI270_SPI_HZ   8000000UL    /* 8 MHz, matching the original StampFly firmware */

extern "C" void bmi270_hw_init(void)
{
    /* No Serial.begin() here: in External mode the XCP/rtiostream daemon owns
     * the serial link, and the MathWorks prebuilt libcore.a does not export the
     * USB-CDC `Serial` (HWCDCSerial) instance -> linker error if referenced. */
    stampfly_spi_init();             /* shared global SPI bus; parks both CS high */
}

extern "C" void bmi270_hw_debug(int32_t stage, int32_t code)
{
    /* No-op: `Serial` (HWCDCSerial) is unavailable in the prebuilt core and the
     * serial link is reserved for External-mode telemetry. Kept for ABI parity
     * with the driver's debug calls. */
    (void)stage; (void)code;
}

extern "C" int8_t bmi270_hw_read(uint8_t reg, uint8_t *data, uint32_t len)
{
    SPI.beginTransaction(SPISettings(BMI270_SPI_HZ, MSBFIRST, SPI_MODE0));
    digitalWrite(BMI270_CS_PIN, LOW);
    SPI.transfer(reg);                           /* read mask already set by API */
    for (uint32_t i = 0; i < len; i++) {
        data[i] = SPI.transfer(0x00);
    }
    digitalWrite(BMI270_CS_PIN, HIGH);
    SPI.endTransaction();
    return 0;
}

extern "C" int8_t bmi270_hw_write(uint8_t reg, const uint8_t *data, uint32_t len)
{
    SPI.beginTransaction(SPISettings(BMI270_SPI_HZ, MSBFIRST, SPI_MODE0));
    digitalWrite(BMI270_CS_PIN, LOW);
    SPI.transfer(reg);
    for (uint32_t i = 0; i < len; i++) {
        SPI.transfer(data[i]);
    }
    digitalWrite(BMI270_CS_PIN, HIGH);
    SPI.endTransaction();
    return 0;
}

extern "C" void bmi270_hw_delay_us(uint32_t us)
{
    delayMicroseconds(us);
}

#else
/* ============================ HOST (MEX sim) ============================ */
extern "C" void bmi270_hw_init(void) { }

extern "C" int8_t bmi270_hw_read(uint8_t reg, uint8_t *data, uint32_t len)
{
    (void)reg;
    for (uint32_t i = 0; i < len; i++) { data[i] = 0; }
    return 0;
}

extern "C" int8_t bmi270_hw_write(uint8_t reg, const uint8_t *data, uint32_t len)
{
    (void)reg; (void)data; (void)len;
    return 0;
}

extern "C" void bmi270_hw_delay_us(uint32_t us) { (void)us; }

extern "C" void bmi270_hw_debug(int32_t stage, int32_t code) { (void)stage; (void)code; }

#endif /* MATLAB_MEX_FILE */
