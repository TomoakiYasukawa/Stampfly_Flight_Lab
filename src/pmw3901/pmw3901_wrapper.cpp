/*
 * pmw3901_wrapper.cpp - C wrapper around the Bitcraze PMW3901 Arduino driver.
 *
 * Presents the StampFly block's C interface (pmw3901_setup / pmw3901_step, see
 * pmw3901_driver.h) but backs it with the upstream Bitcraze_PMW3901 class in
 * src/pmw3901/upstream (github.com/bitcraze/Bitcraze_PMW3901), carrying ONE
 * local modification: its SPI clock is lowered from 4 MHz to the 2 MHz maximum
 * the PMW3901MB datasheet allows. The class is used for bring-up only (power-up
 * reset, product-ID check, PixArt performance-register sequence); the per-step
 * read is done here with the datasheet's Motion_Burst command.
 *
 * Bus     : shared StampFly global `SPI` (MOSI=14 SCK=44 MISO=43), CS=12,
 *           brought up by the common spi_esp32 layer (see spi_esp32.h). The
 *           Bitcraze class calls the pin-less SPI.begin() internally, which is a
 *           no-op once stampfly_spi_init() has configured the bus -> the
 *           StampFly pins persist and the BMI270 shares the same SPIClass.
 * Read    : one Motion_Burst (register 0x16) transaction per step returns
 *           Motion, Observation, Delta_X, Delta_Y, SQUAL, RawData_Sum,
 *           Maximum/Minimum_RawData and Shutter_Upper/Lower - 12 bytes in a
 *           single chip-select assertion. Compared with the seven separate
 *           register reads the upstream readMotionCount() + SQUAL + shutter
 *           path needed (each with ~200 us of datasheet inter-byte delays),
 *           this cuts the blocking time per step from ~1.4 ms to ~0.2 ms and
 *           guarantees the motion, quality and shutter fields come from the
 *           same frame.
 * Host MEX: stubbed (returns zeros) so the System object compiles for sim; the
 *           Arduino driver is only added to the ESP32 codegen build.
 */
#include "pmw3901_driver.h"
#include <string.h>

#ifndef MATLAB_MEX_FILE
/* ============================ TARGET (ESP32) ============================ */
#include <Arduino.h>
#include <SPI.h>
#include "spi_esp32.h"
#include "Bitcraze_PMW3901.h"

#define PMW3901_CS_PIN        STAMPFLY_SPI_CS_PMW3901   /* 12 */
#define PMW3901_SPI_HZ        2000000UL                 /* datasheet max SCLK */
#define PMW3901_MOTION_BURST  0x16u                     /* Motion_Burst register */
#define PMW3901_BURST_LEN     12u

/* Motion_Burst byte order (PMW3901MB datasheet, "Motion_Burst" register):
 *   0 Motion  1 Observation  2 Delta_X_L  3 Delta_X_H  4 Delta_Y_L  5 Delta_Y_H
 *   6 SQUAL   7 RawData_Sum  8 Maximum_RawData  9 Minimum_RawData
 *  10 Shutter_Upper  11 Shutter_Lower */
#define PMW3901_B_MOTION      0u
#define PMW3901_B_DX_L        2u
#define PMW3901_B_DX_H        3u
#define PMW3901_B_DY_L        4u
#define PMW3901_B_DY_H        5u
#define PMW3901_B_SQUAL       6u
#define PMW3901_B_SHUT_UP     10u

static Bitcraze_PMW3901 s_flow(PMW3901_CS_PIN);
static bool             s_ready = false;
static uint32_t s_samples = 0, s_max_us = 0, s_total_x = 0, s_total_y = 0;

/* One Motion_Burst read. Timing follows the datasheet / Crazyflie firmware:
 * tNCS-SCLK setup, tSRAD-MOTBR (>= 35 us) between the address and the first
 * data byte, and a short hold before NCS is released. Reading the burst also
 * latches/clears the motion registers, exactly like reading Motion (0x02). */
static void flow_read_burst(uint8_t buf[PMW3901_BURST_LEN])
{
    uint8_t i;
    SPI.beginTransaction(SPISettings(PMW3901_SPI_HZ, MSBFIRST, SPI_MODE3));
    digitalWrite(PMW3901_CS_PIN, LOW);
    delayMicroseconds(50);
    SPI.transfer(PMW3901_MOTION_BURST);          /* MSB clear = read */
    delayMicroseconds(50);                       /* tSRAD-MOTBR */
    for (i = 0u; i < PMW3901_BURST_LEN; i++) {
        buf[i] = SPI.transfer(0x00);
    }
    delayMicroseconds(50);
    digitalWrite(PMW3901_CS_PIN, HIGH);
    SPI.endTransaction();
}

extern "C" void pmw3901_setup(void)
{
    stampfly_spi_init();             /* shared global SPI bus on StampFly pins */
    s_ready = s_flow.begin();        /* Bitcraze power-up reset + ID check + init */
    s_samples = s_max_us = s_total_x = s_total_y = 0;
}

extern "C" void pmw3901_logger_step(float flow[2], uint16_t raw[8],
                                    uint32_t info[4], uint32_t totals[2])
{
    memset(flow, 0, 2 * sizeof(float));
    memset(raw, 0, 8 * sizeof(uint16_t));
    memset(info, 0, 4 * sizeof(uint32_t));
    totals[0] = s_total_x; totals[1] = s_total_y;
    if (!s_ready) return;
    uint8_t b[PMW3901_BURST_LEN];
    const uint32_t start = micros();
    flow_read_burst(b);
    const uint32_t sampled_at = micros();
    const uint32_t duration = sampled_at - start;
    const int16_t dx = (int16_t)((uint16_t(b[3]) << 8) | b[2]);
    const int16_t dy = (int16_t)((uint16_t(b[5]) << 8) | b[4]);
    flow[0] = float(dx); flow[1] = float(dy);
    raw[0] = b[6]; raw[1] = (uint16_t(b[10]) << 8) | b[11];
    raw[2] = b[0]; raw[3] = b[1]; raw[4] = b[7];
    raw[5] = b[8]; raw[6] = b[9]; raw[7] = 1;
    ++s_samples;
    if (duration > s_max_us) s_max_us = duration;
    s_total_x += uint32_t(int32_t(dx)); s_total_y += uint32_t(int32_t(dy));
    info[0] = s_samples; info[1] = duration; info[2] = s_max_us;
    info[3] = sampled_at;
    totals[0] = s_total_x; totals[1] = s_total_y;
}

extern "C" void pmw3901_step(float flow[2], uint8_t quality[1], uint8_t status[1],
                             uint8_t shutter[1])
{
    uint8_t b[PMW3901_BURST_LEN];
    int16_t dx, dy;

    flow[0]    = 0.0f;
    flow[1]    = 0.0f;
    quality[0] = 0u;
    status[0]  = 0u;
    shutter[0] = 0u;

    if (!s_ready) { return; }

    flow_read_burst(b);

    dx = (int16_t)(((uint16_t)b[PMW3901_B_DX_H] << 8) | b[PMW3901_B_DX_L]);
    dy = (int16_t)(((uint16_t)b[PMW3901_B_DY_H] << 8) | b[PMW3901_B_DY_L]);

    flow[0]    = (float)dx;          /* accumulated motion since last read */
    flow[1]    = (float)dy;
    quality[0] = b[PMW3901_B_SQUAL];
    shutter[0] = b[PMW3901_B_SHUT_UP];
    status[0]  = 1u;                 /* valid frame read; zero motion is valid */
    (void)b[PMW3901_B_MOTION];       /* MOT bit not exposed: 0 counts are data */
}

#else
/* ============================ HOST (MEX sim) ============================ */
extern "C" void pmw3901_setup(void) { }

extern "C" void pmw3901_logger_step(float flow[2], uint16_t raw[8],
                                    uint32_t info[4], uint32_t totals[2])
{
    memset(flow, 0, 2 * sizeof(float));
    memset(raw, 0, 8 * sizeof(uint16_t));
    memset(info, 0, 4 * sizeof(uint32_t));
    totals[0] = totals[1] = 0;
}

extern "C" void pmw3901_step(float flow[2], uint8_t quality[1], uint8_t status[1],
                             uint8_t shutter[1])
{
    flow[0] = 0.0f;
    flow[1] = 0.0f;
    quality[0] = 0u;
    status[0] = 0u;
    shutter[0] = 0u;
}

#endif /* MATLAB_MEX_FILE */
