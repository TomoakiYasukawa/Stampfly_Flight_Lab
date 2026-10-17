/*
 * bmi270_imu_driver.c - Bosch BMI2 API wrapper for the BMI270_IMU block.
 *
 * Uses the official Bosch BMI270_SensorAPI (bmi2.c / bmi270.c, v2.113). The SPI
 * bus access is delegated to the ESP32 hardware layer (bmi270_spi_esp32.*), so
 * the same code compiles for host MEX simulation (hardware stubbed -> zeros) and
 * for ESP32 code generation (real SPI).
 *
 * Sensor configuration (see bmi270_imu_driver.h for the reasoning):
 *   accel  +/-8 g,     ODR 400 Hz, normal filter, performance filter mode
 *   gyro   +/-2000 dps, ODR 400 Hz, normal filter, performance filter mode,
 *                       performance (low-noise) noise mode
 */
#include "bmi270_imu_driver.h"
#include "bmi270_spi_esp32.h"
#include "bmi270.h"
#include "bmi2_defs.h"

#include <string.h>

#define BMI270_GRAVITY      9.80665f
#define BMI270_ACC_RANGE_G  8.0f        /* matches BMI2_ACC_RANGE_8G   */
#define BMI270_GYR_RANGE_D  2000.0f     /* matches BMI2_GYR_RANGE_2000  */
#define BMI270_DEG2RAD      0.017453292519943295f
#define BMI270_TEMP_INVALID ((int16_t)0x8000) /* datasheet: 0x8000 = invalid */

static struct bmi2_dev s_bmi;
static uint8_t         s_intf = 0;      /* non-NULL intf_ptr placeholder */
static uint8_t         s_ready = 0;
static uint8_t         s_last_read_valid = 0;
static float           s_last_temp = 0.0f;

/* ----- Bosch API interface callbacks bridging to the ESP32 SPI layer ----- */
static BMI2_INTF_RETURN_TYPE spi_read(uint8_t reg, uint8_t *data, uint32_t len, void *ip)
{
    (void)ip;
    return (BMI2_INTF_RETURN_TYPE)bmi270_hw_read(reg, data, len);
}

static BMI2_INTF_RETURN_TYPE spi_write(uint8_t reg, const uint8_t *data, uint32_t len, void *ip)
{
    (void)ip;
    return (BMI2_INTF_RETURN_TYPE)bmi270_hw_write(reg, data, len);
}

static void delay_us(uint32_t period, void *ip)
{
    (void)ip;
    bmi270_hw_delay_us(period);
}

/* ----- LSB -> physical unit conversions (16-bit, signed) ----- */
static float lsb_to_mps2(int16_t val, float g_range, uint8_t bit_width)
{
    float half_scale = (float)((uint32_t)1u << (bit_width - 1u));   /* 2^bw / 2 */
    return (BMI270_GRAVITY * (float)val * g_range) / half_scale;
}

static float lsb_to_dps(int16_t val, float dps, uint8_t bit_width)
{
    float half_scale = (float)((uint32_t)1u << (bit_width - 1u));
    return (dps / half_scale) * (float)val;
}

void bmi270_imu_setup(void)
{
    int8_t rslt;
    struct bmi2_sens_config cfg[2];
    uint8_t sens_list[2] = { BMI2_ACCEL, BMI2_GYRO };

    s_ready     = 0;
    s_last_temp = 0.0f;

    bmi270_hw_init();

    /* Bind the Bosch device structure to our SPI interface. */
    s_bmi.intf            = BMI2_SPI_INTF;
    s_bmi.read            = spi_read;
    s_bmi.write           = spi_write;
    s_bmi.delay_us        = delay_us;
    s_bmi.intf_ptr        = (void *)&s_intf;
    s_bmi.read_write_len  = 46;     /* config upload burst length */
    s_bmi.config_file_ptr = NULL;   /* use built-in BMI270 config file */

    rslt = bmi270_init(&s_bmi);
    bmi270_hw_debug(1, rslt);                 /* bmi270_init result (0 = BMI2_OK) */
    bmi270_hw_debug(2, (int32_t)s_bmi.chip_id);/* expect 0x24 (36) for BMI270     */
    if (rslt != BMI2_OK) { return; }

    cfg[0].type = BMI2_ACCEL;
    cfg[1].type = BMI2_GYRO;
    rslt = bmi2_get_sensor_config(cfg, 2, &s_bmi);
    bmi270_hw_debug(3, rslt);                 /* get_sensor_config result */
    if (rslt != BMI2_OK) { return; }

    /* Official configuration: both ODR400, normal filters. */
    cfg[0].cfg.acc.odr         = BMI2_ACC_ODR_400HZ;
    cfg[0].cfg.acc.range       = BMI2_ACC_RANGE_8G;
    cfg[0].cfg.acc.bwp         = BMI2_ACC_NORMAL_AVG4;    /* normal in perf mode */
    cfg[0].cfg.acc.filter_perf = BMI2_PERF_OPT_MODE;

    cfg[1].cfg.gyr.odr         = BMI2_GYR_ODR_400HZ;
    cfg[1].cfg.gyr.range       = BMI2_GYR_RANGE_2000;
    cfg[1].cfg.gyr.bwp         = BMI2_GYR_NORMAL_MODE;
    /* gyr_noise_perf = 1 selects the datasheet's lower-noise gyro mode for a
     * few hundred microamps more; on a drone the motors dwarf that. */
    cfg[1].cfg.gyr.noise_perf  = BMI2_PERF_OPT_MODE;
    cfg[1].cfg.gyr.filter_perf = BMI2_PERF_OPT_MODE;

    rslt = bmi2_set_sensor_config(cfg, 2, &s_bmi);
    bmi270_hw_debug(4, rslt);                 /* set_sensor_config result */
    if (rslt != BMI2_OK) { return; }

    rslt = bmi2_sensor_enable(sens_list, 2, &s_bmi);
    bmi270_hw_debug(5, rslt);                 /* sensor_enable result */
    if (rslt != BMI2_OK) { return; }

    /* Keep ODR/range/filter settings intact, remove 450us APS bus delays.
     * Bosch SensorAPI uses a 2us access delay with APS disabled. */
    rslt = bmi2_set_adv_power_save(BMI2_DISABLE, &s_bmi);
    bmi270_hw_debug(7, rslt);
    if (rslt != BMI2_OK) { return; }

    bmi270_hw_debug(6, 1);                    /* setup complete, s_ready = 1 */
    s_ready = 1;
}

void bmi270_imu_step(float accel[3], float gyro[3], float temp[1], uint8_t status[1])
{
    struct bmi2_sens_data data;
    int16_t temp_raw = 0;
    uint8_t drdy = 0;
    uint8_t bw;

    accel[0] = accel[1] = accel[2] = 0.0f;
    gyro[0]  = gyro[1]  = gyro[2]  = 0.0f;
    temp[0]  = s_last_temp;
    status[0] = 0u;
    s_last_read_valid = 0u;

    if (!s_ready) { return; }

    /* STATUS (0x03) must be read BEFORE the data registers: the datasheet
     * clears drdy_acc / drdy_gyr as soon as any DATA_8..DATA_19 register is
     * read, so reading it afterwards reports "stale" for nearly every sample.
     * The accel/gyro below are valid regardless; status[0] only says whether
     * the sample about to be read is new since the previous poll. */
    if ((bmi2_get_status(&drdy, &s_bmi) == BMI2_OK) &&
        (drdy & BMI2_DRDY_ACC) && (drdy & BMI2_DRDY_GYR))
    {
        status[0] = 1u;
    }

    /* bmi2_get_sensor_data() bursts acc + gyr + sensortime from 0x0C and applies
     * the gyro cross-axis (zx) compensation from the chip's stored factor. */
    memset(&data, 0, sizeof(data));
    if (bmi2_get_sensor_data(&data, &s_bmi) != BMI2_OK) { status[0] = 0u; return; }
    /* Keep the legacy Fresh flag unchanged; expose read success separately. */
    s_last_read_valid = 1u;

    bw = s_bmi.resolution;   /* 16-bit for BMI270 */

    accel[0] = lsb_to_mps2(data.acc.x, BMI270_ACC_RANGE_G, bw);
    accel[1] = lsb_to_mps2(data.acc.y, BMI270_ACC_RANGE_G, bw);
    accel[2] = lsb_to_mps2(data.acc.z, BMI270_ACC_RANGE_G, bw);

    gyro[0]  = lsb_to_dps(data.gyr.x, BMI270_GYR_RANGE_D, bw) * BMI270_DEG2RAD;
    gyro[1]  = lsb_to_dps(data.gyr.y, BMI270_GYR_RANGE_D, bw) * BMI270_DEG2RAD;
    gyro[2]  = lsb_to_dps(data.gyr.z, BMI270_GYR_RANGE_D, bw) * BMI270_DEG2RAD;

    /* Temperature requires the gyro to be enabled (it is). Updated at 10 Hz by
     * the chip; 0x8000 marks an invalid reading, in which case the last good
     * value is held. Datasheet scaling: T = raw / 512 + 23 degC. */
    if ((bmi2_get_temperature_data(&temp_raw, &s_bmi) == BMI2_OK) &&
        (temp_raw != BMI270_TEMP_INVALID))
    {
        s_last_temp = ((float)temp_raw / 512.0f) + 23.0f;
        temp[0]     = s_last_temp;
    }
}

uint8_t bmi270_imu_read_valid(void)
{
    return s_last_read_valid;
}

