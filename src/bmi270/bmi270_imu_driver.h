/* Project-local official BMI270: ODR400 Hz, normal filters, +/-8g, +/-2000dps. */
#ifndef BMI270_IMU_DRIVER_H
#define BMI270_IMU_DRIVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Project-local official BMI270: ODR400 Hz, normal filters, +/-8g, +/-2000dps. */
void bmi270_imu_setup(void);

/* Project-local official BMI270: ODR400 Hz, normal filters, +/-8g, +/-2000dps. */
void bmi270_imu_step(float accel[3], float gyro[3], float temp[1], uint8_t status[1]);

/* Success of the most recent register read, independent of data-ready Fresh. */
uint8_t bmi270_imu_read_valid(void);

#ifdef __cplusplus
}
#endif

#endif /* Project-local official BMI270: ODR400 Hz, normal filters, +/-8g, +/-2000dps. */

