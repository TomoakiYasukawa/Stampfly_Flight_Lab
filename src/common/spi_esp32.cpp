/*
 * spi_esp32.cpp - Shared ESP32 / Arduino SPI bus implementation for StampFly_lib.
 *
 * Target build  : global `SPI` on FSPI pins (MOSI=14 SCK=44 MISO=43); both chip
 *                 selects (BMI270 CS=46, PMW3901 CS=12) parked high.
 * Host MEX build: stubbed so the System objects compile for simulation.
 */
#include "spi_esp32.h"

#define STAMPFLY_SPI_SCK   44
#define STAMPFLY_SPI_MISO  43
#define STAMPFLY_SPI_MOSI  14

#ifndef MATLAB_MEX_FILE
/* ============================ TARGET (ESP32) ============================ */
#include <Arduino.h>
#include <SPI.h>

static bool s_spi_ready = false;

extern "C" void stampfly_spi_init(void)
{
    if (s_spi_ready) { return; }            /* shared bus: begin only once */

    /* Park both chip selects high before the bus is driven, so neither device
     * is selected while the other transacts. */
    pinMode(STAMPFLY_SPI_CS_BMI270, OUTPUT);
    digitalWrite(STAMPFLY_SPI_CS_BMI270, HIGH);
    pinMode(STAMPFLY_SPI_CS_PMW3901, OUTPUT);
    digitalWrite(STAMPFLY_SPI_CS_PMW3901, HIGH);

    SPI.begin(STAMPFLY_SPI_SCK, STAMPFLY_SPI_MISO, STAMPFLY_SPI_MOSI);
    s_spi_ready = true;
}

#else
/* ============================ HOST (MEX sim) ============================ */
extern "C" void stampfly_spi_init(void) { }

#endif /* MATLAB_MEX_FILE */
