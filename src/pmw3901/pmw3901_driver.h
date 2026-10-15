/*
 * pmw3901_driver.h - PixArt PMW3901MB optical-flow sensor for StampFly_lib.
 *
 * Bus : SPI (shared StampFly global SPI bus, CS=12). Reports frame-to-frame
 *       motion of the surface below the drone; fused with the ToF height
 *       downstream it gives horizontal velocity for position hold.
 *
 * Outputs are the raw per-sample motion deltas (counts) plus a surface-quality
 * figure. Scaling to metres depends on height and lens FOV and is done in the
 * model, so no board-specific constants are hard-coded here.
 *
 * Implementation note
 * -------------------
 * This C interface is implemented by pmw3901_wrapper.cpp, a thin wrapper over
 * the upstream Bitcraze PMW3901 Arduino driver (src/pmw3901/upstream,
 * github.com/bitcraze/Bitcraze_PMW3901) with one local change: the SPI clock is
 * 2 MHz, the PMW3901MB datasheet maximum, instead of upstream's 4 MHz. The
 * class handles bring-up; each step is a single 12-byte Motion_Burst (0x16)
 * read on the shared StampFly SPI bus (see common/spi_esp32), so motion,
 * SQUAL and shutter come from the same frame in one ~0.2 ms transaction.
 */
#ifndef PMW3901_DRIVER_H
#define PMW3901_DRIVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One-time init: bring up SPI, verify the product ID and run the PixArt
 * performance-optimisation register sequence. Call from the System object setup. */
void pmw3901_setup(void);

/* Acquire one motion sample (one Motion_Burst read; latches the motion regs).
 *   flow    : [2] {deltaX, deltaY} accumulated motion since last read (counts)
 *   quality : [1] surface quality (SQUAL); higher = more trackable features
 *   status  : [1] 1 = valid motion sample, 0 = not initialised / no data / error
 *   shutter : [1] Shutter_Upper (reg 0x0C); reads 0x1F when the integration
 *                 time is saturated (featureless / too-dark surface)
 */
void pmw3901_step(float flow[2], uint8_t quality[1], uint8_t status[1],
                  uint8_t shutter[1]);

/* Logging only. raw: SQUAL/full shutter/motion/observation/raw sum/max/min/valid.
 * info: successful bursts/last us/max us/sample time us.
 * totals: modulo-2^32 X/Y accumulated counts. Shared SPI: call on BMI's task. */
void pmw3901_logger_step(float flow[2], uint16_t raw[8], uint32_t info[4],
                         uint32_t totals[2]);

#ifdef __cplusplus
}
#endif

#endif /* PMW3901_DRIVER_H */
