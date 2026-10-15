/*
 * bmm150_driver.c - Bosch BMM150 SensorAPI wrapper for the BMM150 block.
 *
 * Uses the official Bosch BMM150_SensorAPI (upstream/bmm150.c). The I2C bus
 * access and the microsecond delay are delegated to the shared StampFly
 * hardware layer (common/i2c_esp32.*), so the same code compiles for host MEX
 * simulation (hardware stubbed -> zeros) and ESP32 codegen (real Wire1).
 *
 * NOTE: this component is compiled with BMM150_USE_FLOATING_POINT defined (see
 * the System object's updateBuildInfo), so struct bmm150_mag_data carries the
 * compensated field as float micro-tesla.
 */
#include "bmm150_driver.h"
#include "i2c_esp32.h"
#include "bmm150.h"
#include "bmm150_defs.h"

static struct bmm150_dev s_dev;
static uint8_t           s_addr  = BMM150_DEFAULT_I2C_ADDRESS;  /* intf_ptr target */
static uint8_t           s_ready = 0;

/* ----- Bosch API interface callbacks bridging to the StampFly I2C layer ----- */
static BMM150_INTF_RET_TYPE i2c_read(uint8_t reg, uint8_t *data, uint32_t len, void *ip)
{
    uint8_t addr = *(uint8_t *)ip;
    return (BMM150_INTF_RET_TYPE)stampfly_i2c_read(addr, reg, data, len);
}

static BMM150_INTF_RET_TYPE i2c_write(uint8_t reg, const uint8_t *data, uint32_t len, void *ip)
{
    uint8_t addr = *(uint8_t *)ip;
    return (BMM150_INTF_RET_TYPE)stampfly_i2c_write(addr, reg, data, len);
}

static void delay_us(uint32_t period, void *ip)
{
    (void)ip;
    stampfly_delay_us(period);
}

void bmm150_mag_setup(uint8_t i2c_addr)
{
    int8_t rslt;
    struct bmm150_settings settings = { 0 };

    s_ready = 0;
    s_addr  = i2c_addr;

    /* Official bottom-ToF owns Wire1 initialization. The logger worker owns
     * official_i2c's mutex before entering this API. Do not restart the bus. */

    /* Bind the Bosch device structure to the shared I2C interface. The address
     * travels through intf_ptr so the read/write callbacks know which slave. */
    s_dev.intf     = BMM150_I2C_INTF;
    s_dev.read     = i2c_read;
    s_dev.write    = i2c_write;
    s_dev.delay_us = delay_us;
    s_dev.intf_ptr = (void *)&s_addr;

    rslt = bmm150_init(&s_dev);             /* detects chip id 0x32, reads trim */
    if (rslt != BMM150_OK) { return; }

    /* "Enhanced regular" preset: nXY=15, nZ=27 repetitions (0.5 uT RMS noise
     * vs 0.6 uT for "Regular"). The Bosch API pins every preset's data rate at
     * 10 Hz (20 Hz for High accuracy), which is only a recommendation: the
     * part's ODR ceiling is set by the repetition count through
     *   t_measure = 145 us * nXY + 500 us * nZ + 980 us  = 16.7 ms here,
     * which fits inside the 33 ms period of the 30 Hz maximum ODR. High
     * accuracy (nXY=47, nZ=83, 49 ms) would not, so it is capped at 20 Hz. */
    settings.preset_mode = BMM150_PRESETMODE_ENHANCED;
    rslt = bmm150_set_presetmode(&settings, &s_dev);
    if (rslt != BMM150_OK) { return; }

    /* Override the preset's 10 Hz with the device maximum, 30 Hz. Must follow
     * the preset (which writes the rate) and precede Normal mode. */
    settings.data_rate = BMM150_DATA_RATE_30HZ;
    rslt = bmm150_set_sensor_settings(BMM150_SEL_DATA_RATE, &settings, &s_dev);
    if (rslt != BMM150_OK) { return; }

    /* Continuous measurement. */
    settings.pwr_mode = BMM150_POWERMODE_NORMAL;
    rslt = bmm150_set_op_mode(&settings, &s_dev);
    if (rslt != BMM150_OK) { return; }

    s_ready = 1;
}

void bmm150_mag_step(float mag[3], uint8_t status[1])
{
    struct bmm150_mag_data data;

    mag[0] = mag[1] = mag[2] = 0.0f;
    status[0] = 0u;

    if (!s_ready) { return; }

    /* read_mag_data burst-reads 0x42..0x49 and returns compensated micro-tesla. */
    if (bmm150_read_mag_data(&data, &s_dev) != BMM150_OK) { return; }

    mag[0] = data.x;
    mag[1] = data.y;
    mag[2] = data.z;
    status[0] = 1u;
}

int8_t bmm150_mag_poll(float mag[3], uint8_t fresh[1])
{
    uint8_t ready = 0;
    struct bmm150_mag_data data;
    fresh[0] = 0;
    if (!s_ready) return BMM150_E_DEV_NOT_FOUND;
    int8_t result = bmm150_get_regs(BMM150_REG_DATA_READY_STATUS, &ready, 1, &s_dev);
    if (result != BMM150_OK || !(ready & BMM150_DRDY_STATUS_MSK)) return result;
    result = bmm150_read_mag_data(&data, &s_dev);
    if (result == BMM150_OK) {
        mag[0] = data.x; mag[1] = data.y; mag[2] = data.z;
        fresh[0] = 1;
    }
    return result;
}
