#ifndef STAMPFLY_IMU_RX_H
#define STAMPFLY_IMU_RX_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void imu_rx_init(uint8_t channel, uint32_t baudRate);
void imu_rx_step(uint32_t *forwarded, uint8_t *channel);
#ifdef __cplusplus
}
#endif
#endif
