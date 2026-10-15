/*
 * vl53l3cx_uld_wrapper.cpp - C wrapper around the ST/stm32duino VL53L3CX ULD.
 *
 * Presents the same C interface the StampFly System object already calls
 * (vl53l3cx_bringup / vl53l3cx_setup / vl53l3cx_step, see vl53l3cx_driver.h),
 * but backs it with the full ST VL53L3CX Ultra-Lite Driver (histogram ranging,
 * multi-target, crosstalk) via stm32duino's VL53LX class. The ULD sources in
 * src/vl53l3cx/uld are used UNMODIFIED (github.com/stm32duino/VL53L3CX); only
 * this wrapper is StampFly-specific, so the block interface is unchanged.
 *
 * The bring-up + per-sensor configuration mirror the M5StampFly firmware
 * tof_init() (github.com/M5Fly-kanazawa/M5StampFly, src/tof.cpp): XSHUT
 * sequencing (bottom GPIO 7 keeps 0x29, front GPIO 9 -> 0x2A), then per sensor
 * WaitDeviceBooted -> DataInit -> SetDistanceMode -> SetMeasurementTimingBudget
 * -> StartMeasurement. Bus is the shared StampFly Wire1 (SDA 3 / SCL 4).
 *
 * The distance mode and the timing budget come from the block rather than being
 * fixed at the firmware's 33 ms: the budget is what sets the output rate (see
 * "Update rate" in vl53l3cx_driver.h), and 33 ms is only the ULD default.
 *
 * Outputs: Range (m, the selected valid target: farthest for the bottom sensor
 * like the firmware, nearest for the front sensor, see VL53L3CX_TS_*; holds
 * last value between
 * measurements), RangeStatus (the sensor's per-target status), Status (1 = a
 * valid recent reading is available, 0 = dropout / no target / not ready yet;
 * stays high while tracking). Valid-range statuses are 0 / 6 / 11; on a real
 * drop-out Range goes to 0 and RangeStatus carries the sensor's reason
 * (1 sigma, 2 signal, 13 min-range, 255 no target).
 *
 * Wrapper-level faults are reported through RangeStatus too, so problems are
 * visible in External mode without a serial console. They use a band ABOVE the
 * ULD's own codes, which run 0..14 plus 255: the ULD already defines 11 as
 * RANGE_VALID_MERGED_PULSE (a GOOD range), 13 as MIN_RANGE_FAIL and 14 as
 * RANGE_INVALID, so an earlier "10 + stage" encoding made a boot failure
 * indistinguishable from a real measurement result. Status does not separate
 * them either - a dropout and a failed setup both report Status = 0.
 *     101 = WaitDeviceBooted failed (Range = ULD error code)
 *     102 = DataInit / InitSensor failed
 *     103 = SetDistanceMode failed
 *     104 = SetMeasurementTimingBudget failed (requested budget out of range)
 *     105 = StartMeasurement failed
 *      90 = data-ready / I2C read error
 * Anything <= 14 or == 255 therefore comes from the sensor; >= 90 is ours.
 *
 * Host MEX: stubbed (returns zeros) so the System object compiles for sim.
 *
 * The ULD addressing API is 8-bit (writes addr/2 to I2C_SLAVE__DEVICE_ADDRESS;
 * the Wire layer shifts >>1), so 7-bit StampFly addresses are passed as
 * (addr7 << 1): bottom 0x29 -> 0x52, front 0x2A -> 0x54.
 */
#include "vl53l3cx_driver.h"

#ifndef MATLAB_MEX_FILE
/* ============================ TARGET (ESP32) ============================ */
#include <Arduino.h>
#include <Wire.h>
#include "i2c_esp32.h"
#include "vl53lx_class.h"

#define VL53_XSHUT_BOTTOM   7    /* downward sensor, keeps 0x29 */
#define VL53_XSHUT_FRONT    9    /* forward  sensor, moved to 0x2A */
/* Fallback when the block passes 0: the ULD's own DataInit default. */
#define VL53_TIMING_BUDGET_DEFAULT  33333u

static VL53LX s_bottom(&Wire1, VL53_XSHUT_BOTTOM);
static VL53LX s_front(&Wire1, VL53_XSHUT_FRONT);
static VL53LX s_custom(&Wire1, -1);

typedef struct {
    VL53LX *dev;
    uint8_t addr7;
    bool    powered;      /* XSHUT raised + address assigned    */
    bool    ready;        /* booted + DataInit + StartMeasurement OK */
    bool    nearest;      /* pick nearest valid target (else farthest) */
    bool    have_sample;  /* at least one valid range read       */
    float   last_range;   /* held between measurements           */
    uint8_t last_range_status; /* held so External mode can display it */
    uint8_t dbg_stage;    /* setup stage reached (1..5)          */
    uint8_t dbg_err;      /* ULD error code at the failing stage */
} vl53_slot_t;

static vl53_slot_t s_slot[3] = {
    { &s_bottom, VL53L3CX_BOTTOM_ADDR, false, false, false, false, 0.0f, 0u, 0u, 0u },
    { &s_front,  VL53L3CX_FRONT_ADDR,  false, false, true,  false, 0.0f, 0u, 0u, 0u },
    { &s_custom, 0u,                   false, false, false, false, 0.0f, 0u, 0u, 0u }
};

static vl53_slot_t *slot_for(uint8_t addr7)
{
    if (addr7 == VL53L3CX_BOTTOM_ADDR) { return &s_slot[0]; }
    if (addr7 == VL53L3CX_FRONT_ADDR)  { return &s_slot[1]; }
    s_slot[2].addr7 = addr7;
    return &s_slot[2];
}

extern "C" void vl53l3cx_bringup(void)
{
    static bool s_done = false;
    if (s_done) { return; }
    s_done = true;

    stampfly_i2c_init();                 /* Wire1 @ SDA 3 / SCL 4 / 400 kHz */

    s_bottom.begin();                    /* pinMode(XSHUT, OUTPUT) */
    s_front.begin();

    s_bottom.VL53LX_Off();
    s_front.VL53LX_Off();
    delay(50);

    /* Raise FRONT only and move it to 0x2A while BOTTOM is held low. */
    s_front.VL53LX_On();
    delay(100);                          /* firmware waits 100 ms before re-address */
    if (s_front.VL53LX_SetDeviceAddress((uint8_t)(VL53L3CX_FRONT_ADDR << 1))
            == VL53LX_ERROR_NONE) {
        s_slot[1].powered = true;
    }
    delay(100);

    /* Raise BOTTOM; it keeps the default 0x29. */
    s_bottom.VL53LX_On();
    s_slot[0].powered = true;
}

/* Map the block's selector to a ULD distance mode. AUTO reproduces the original
 * per-sensor split so models that do not set the parameter behave as before. */
static VL53LX_DistanceModes resolve_mode(const vl53_slot_t *s, uint8_t sel)
{
    switch (sel) {
        case VL53L3CX_DM_SHORT:  return VL53LX_DISTANCEMODE_SHORT;
        case VL53L3CX_DM_MEDIUM: return VL53LX_DISTANCEMODE_MEDIUM;
        case VL53L3CX_DM_LONG:   return VL53LX_DISTANCEMODE_LONG;
        default:                                        /* VL53L3CX_DM_AUTO */
            return (s == &s_slot[1]) ? VL53LX_DISTANCEMODE_LONG
                                     : VL53LX_DISTANCEMODE_MEDIUM;
    }
}

/* Map the block's target selector. AUTO = farthest for the bottom sensor (skip
 * the near crosstalk phantom, track the floor), nearest for the front sensor
 * (closest obstacle) and for a custom-address unit. */
static bool resolve_nearest(const vl53_slot_t *s, uint8_t sel)
{
    switch (sel) {
        case VL53L3CX_TS_NEAREST:  return true;
        case VL53L3CX_TS_FARTHEST: return false;
        default:                   return (s != &s_slot[0]);   /* VL53L3CX_TS_AUTO */
    }
}

extern "C" void vl53l3cx_setup(uint8_t i2c_addr, uint8_t distance_mode,
                               uint32_t timing_budget_us, uint8_t target_select)
{
    vl53_slot_t       *s    = slot_for(i2c_addr);
    VL53LX_Error       st   = VL53LX_ERROR_NONE;
    VL53LX_DistanceModes mode = resolve_mode(s, distance_mode);

    if (timing_budget_us == 0u) { timing_budget_us = VL53_TIMING_BUDGET_DEFAULT; }

    s->nearest     = resolve_nearest(s, target_select);
    s->ready       = false;
    s->have_sample = false;
    s->last_range  = 0.0f;
    s->last_range_status = 0u;
    s->dbg_stage   = 0u;
    s->dbg_err     = 0u;
    stampfly_i2c_init();

    if (s->powered) {
        s->dbg_stage = 1u;
        st = s->dev->VL53LX_WaitDeviceBooted();
        if (st == VL53LX_ERROR_NONE) {
            s->dbg_stage = 2u;
            st = s->dev->VL53LX_DataInit();
        }
    } else {
        s->dbg_stage = 2u;
        s->dev->begin();
        st = s->dev->InitSensor((uint8_t)(i2c_addr << 1));
        if (st == VL53LX_ERROR_NONE) { s->powered = true; }
    }

    /* Distance mode, then timing budget: SetDistanceMode re-applies the preset
     * (and with it the preset's default timeouts), so the budget MUST be set
     * after it or it is silently overwritten. Both are checked rather than
     * ignored like the firmware does - a rejected budget means the sensor is
     * not running at the requested rate, which is invisible in the range data
     * itself and is exactly the failure worth surfacing. */
    if (st == VL53LX_ERROR_NONE) {
        s->dbg_stage = 3u;
        st = s->dev->VL53LX_SetDistanceMode(mode);
    }
    if (st == VL53LX_ERROR_NONE) {
        s->dbg_stage = 4u;
        st = s->dev->VL53LX_SetMeasurementTimingBudgetMicroSeconds(timing_budget_us);
    }
    if (st == VL53LX_ERROR_NONE) {
        /* Prime the interrupt/range state, then start ranging. This Clear-then-
         * Start order mirrors M5StampFly tof_init(); without the initial clear
         * the back-to-back interrupt never asserts, so GetMeasurementDataReady
         * stays 0 (the "sensor ready but no data ever arrives" symptom). */
        (void)s->dev->VL53LX_ClearInterruptAndStartMeasurement();
        delay(100);
        s->dbg_stage = 5u;
        st = s->dev->VL53LX_StartMeasurement();
    }

    s->dbg_err = (uint8_t)st;
    s->ready   = (st == VL53LX_ERROR_NONE);
}


extern "C" void vl53l3cx_step(uint8_t i2c_addr, float range_m[1],
                              uint8_t range_status[1], uint8_t status[1])
{
    vl53_slot_t *s = slot_for(i2c_addr);
    uint8_t      dataReady = 0u;
    static VL53LX_MultiRangingData_t data;   /* large: keep off the task stack */

    status[0]       = 0u;
    range_status[0] = s->last_range_status;
    range_m[0]      = s->last_range;          /* hold last value by default */

    if (!s->ready) {
        /* Setup failed: surface where (100 + stage) and the ULD error code.
         * The offset keeps these clear of the ULD's own 0..14 range statuses. */
        range_status[0] = (uint8_t)(100u + s->dbg_stage);
        s->last_range_status = range_status[0];
        range_m[0]      = (float)s->dbg_err;
        return;
    }

    if (s->dev->VL53LX_GetMeasurementDataReady(&dataReady) != VL53LX_ERROR_NONE) {
        range_status[0] = 90u;               /* I2C / data-ready read error */
        s->last_range_status = range_status[0];
        return;
    }
    if (!dataReady) {
        /* No new measurement yet: hold the last reading and its validity, so
         * Status stays high while tracking instead of pulsing once per sample. */
        status[0] = s->have_sample ? 1u : 0u;
        return;
    }

    if (s->dev->VL53LX_GetMultiRangingData(&data) != VL53LX_ERROR_NONE) {
        range_status[0] = 90u;
        s->last_range_status = range_status[0];
        return;
    }
    (void)s->dev->VL53LX_ClearInterruptAndStartMeasurement();   /* re-arm next range */

    /* Pick one object with a usable (valid-family) status. The VL53L3CX can
     * report several objects; 0/6/11 are valid ranges (see the ULD RangeStatus
     * defines). Bottom sensor: the FARTHEST, matching the M5StampFly firmware
     * (tof_range_get returns range_max of RANGE_VALID objects) - it skips the
     * near crosstalk phantom from the cover/frame so Range tracks the floor.
     * Front sensor: the NEAREST, because the closest obstacle is the one an
     * avoider must react to. Chosen per slot at setup (s->nearest). */
    {
        int16_t best_mm   = 0;
        uint8_t best_stat = 255u;
        bool    found     = false;
        uint8_t j;
        for (j = 0u; j < data.NumberOfObjectsFound; j++) {
            uint8_t rs = data.RangeData[j].RangeStatus;
            int16_t mm = data.RangeData[j].RangeMilliMeter;
            if (rs == VL53LX_RANGESTATUS_RANGE_VALID ||
                rs == VL53LX_RANGESTATUS_RANGE_VALID_NO_WRAP_CHECK_FAIL ||
                rs == VL53LX_RANGESTATUS_RANGE_VALID_MERGED_PULSE) {
                bool better = !found || (s->nearest ? (mm < best_mm) : (mm > best_mm));
                if (better) { best_mm = mm; best_stat = rs; found = true; }
            }
        }
        if (found) {
            range_m[0]      = (float)best_mm * 0.001f;
            range_status[0] = best_stat;
            s->last_range   = range_m[0];
            s->last_range_status = range_status[0];
            s->have_sample  = true;
            status[0]       = 1u;
        } else {
            /* Fresh measurement, no usable target: a drop-out. HOLD the last
             * valid Range (range_m already = last_range) so the signal stays
             * smooth through the sensor's intermittent gaps, but mark it stale
             * with Status 0. range_status carries the sensor's reason (1 sigma,
             * 2 signal, 13 min-range, ...) or 255 if nothing found. */
            s->have_sample  = false;
            range_status[0] = (data.NumberOfObjectsFound > 0u) ?
                              data.RangeData[0].RangeStatus : 255u;
            s->last_range_status = range_status[0];
        }
    }
}

#else
/* ============================ HOST (MEX sim) ============================ */
extern "C" void vl53l3cx_bringup(void) { }
extern "C" void vl53l3cx_setup(uint8_t i2c_addr, uint8_t distance_mode,
                               uint32_t timing_budget_us, uint8_t target_select)
{
    (void)i2c_addr; (void)distance_mode; (void)timing_budget_us; (void)target_select;
}
extern "C" void vl53l3cx_step(uint8_t i2c_addr, float range_m[1],
                              uint8_t range_status[1], uint8_t status[1])
{
    (void)i2c_addr;
    range_m[0] = 0.0f;
    range_status[0] = 0u;
    status[0] = 0u;
}

#endif /* MATLAB_MEX_FILE */
