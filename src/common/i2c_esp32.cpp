/*
 * i2c_esp32.cpp - Shared ESP32 / Arduino I2C implementation for StampFly_lib.
 *
 * Target build  : real Wire1 driver (SDA=3, SCL=4, 400 kHz).
 * Host MEX build : stubbed so the S-functions compile for simulation
 *                  (simulation returns zeros).
 */
#include "i2c_esp32.h"

#define STAMPFLY_I2C_SDA  3
#define STAMPFLY_I2C_SCL  4
#define STAMPFLY_I2C_HZ   400000UL

#ifndef MATLAB_MEX_FILE
/* ============================ TARGET (ESP32) ============================ */
#include <Arduino.h>
#include <Wire.h>

static bool s_i2c_ready = false;

extern "C" void stampfly_i2c_init(void)
{
    if (s_i2c_ready) { return; }            /* shared bus: begin only once */
    Wire1.begin(STAMPFLY_I2C_SDA, STAMPFLY_I2C_SCL, STAMPFLY_I2C_HZ);
    s_i2c_ready = true;
}

extern "C" int8_t stampfly_i2c_read(uint8_t addr, uint8_t reg, uint8_t *data, uint32_t len)
{
    Wire1.beginTransmission(addr);
    Wire1.write(reg);
    if (Wire1.endTransmission(false) != 0) { return -1; }   /* repeated start */
    uint32_t got = Wire1.requestFrom((int)addr, (int)len);
    if (got != len) { return -2; }
    for (uint32_t i = 0; i < len; i++) { data[i] = (uint8_t)Wire1.read(); }
    return 0;
}

extern "C" int8_t stampfly_i2c_write(uint8_t addr, uint8_t reg, const uint8_t *data, uint32_t len)
{
    Wire1.beginTransmission(addr);
    Wire1.write(reg);
    for (uint32_t i = 0; i < len; i++) { Wire1.write(data[i]); }
    return (Wire1.endTransmission(true) == 0) ? 0 : -1;
}

extern "C" int8_t stampfly_i2c_read16(uint8_t addr, uint16_t reg, uint8_t *data, uint32_t len)
{
    Wire1.beginTransmission(addr);
    Wire1.write((uint8_t)(reg >> 8));                       /* register MSB first */
    Wire1.write((uint8_t)(reg & 0xFFu));
    if (Wire1.endTransmission(false) != 0) { return -1; }   /* repeated start */
    uint32_t got = Wire1.requestFrom((int)addr, (int)len);
    if (got != len) { return -2; }
    for (uint32_t i = 0; i < len; i++) { data[i] = (uint8_t)Wire1.read(); }
    return 0;
}

extern "C" int8_t stampfly_i2c_write16(uint8_t addr, uint16_t reg, const uint8_t *data, uint32_t len)
{
    Wire1.beginTransmission(addr);
    Wire1.write((uint8_t)(reg >> 8));                       /* register MSB first */
    Wire1.write((uint8_t)(reg & 0xFFu));
    for (uint32_t i = 0; i < len; i++) { Wire1.write(data[i]); }
    return (Wire1.endTransmission(true) == 0) ? 0 : -1;
}

extern "C" void stampfly_delay_us(uint32_t us)
{
    delayMicroseconds(us);
}

#else
/* ============================ HOST (MEX sim) ============================ */
extern "C" void stampfly_i2c_init(void) { }

extern "C" int8_t stampfly_i2c_read(uint8_t addr, uint8_t reg, uint8_t *data, uint32_t len)
{
    (void)addr; (void)reg;
    for (uint32_t i = 0; i < len; i++) { data[i] = 0; }
    return 0;
}

extern "C" int8_t stampfly_i2c_write(uint8_t addr, uint8_t reg, const uint8_t *data, uint32_t len)
{
    (void)addr; (void)reg; (void)data; (void)len;
    return 0;
}

extern "C" int8_t stampfly_i2c_read16(uint8_t addr, uint16_t reg, uint8_t *data, uint32_t len)
{
    (void)addr; (void)reg;
    for (uint32_t i = 0; i < len; i++) { data[i] = 0; }
    return 0;
}

extern "C" int8_t stampfly_i2c_write16(uint8_t addr, uint16_t reg, const uint8_t *data, uint32_t len)
{
    (void)addr; (void)reg; (void)data; (void)len;
    return 0;
}

extern "C" void stampfly_delay_us(uint32_t us) { (void)us; }

#endif /* MATLAB_MEX_FILE */
