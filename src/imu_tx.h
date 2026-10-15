#ifndef STAMPFLY_IMU_TX_H
#define STAMPFLY_IMU_TX_H
#include <stdint.h>
/* Nonblocking hardware queue; 1 means queued, not over-air delivery. */
#ifdef __cplusplus
extern "C" {
#endif
uint8_t imu_tx_radio_queue(const uint8_t destination[6],const uint8_t* bytes,uint16_t length);
#ifdef __cplusplus
}
#endif
#ifdef __cplusplus
extern "C" {
#endif
void imu_tx_init(uint8_t channel);
uint8_t imu_tx_send(const uint8_t *frame, uint16_t length);
uint8_t imu_tx_led_mode(void);
void imu_tx_flight_command(uint8_t *operation, uint16_t *sequence,
                           uint16_t *climbMmPerS, uint16_t *hoverMm,
                           uint16_t *landMmPerS, uint8_t *linkAlive,
                           uint8_t *emergencyStop);
void imu_tx_tuning_request(int16_t *values9, uint16_t *sequence,
                           uint8_t *pending);
#ifdef __cplusplus
}
#endif
#endif
