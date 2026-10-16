#include "vl53l3cx_bottom_official128_driver.h"

#ifndef MATLAB_MEX_FILE

#include <Arduino.h>
#include <Wire.h>
#include <freertos/semphr.h>
#include <freertos/task.h>
extern "C" {
#include "vl53lx_api.h"
#include "vl53lx_api_core.h"
#include "vl53lx_platform.h"
}

#define VL53_I2C_SDA 3
#define VL53_I2C_SCL 4
#define VL53_I2C_HZ 400000u
#define VL53_I2C_BUFFER_SIZE 258u
#define VL53_I2C_MAX_TRANSFER 256u
#define VL53_INT_BOTTOM 6
#define VL53_XSHUT_BOTTOM 7
#define VL53_XSHUT_FRONT 9
#define VL53_OFFICIAL_BUDGET_US 33000u

static bool s_wire_ready = false;
static VL53LX_Dev_t s_bottom_device;
static VL53LX_DEV s_bottom = &s_bottom_device;
static volatile uint8_t s_data_ready_interrupt = 0u;
static bool s_ready = false;
static bool s_setup_failed = false;
static uint8_t s_setup_stage = 0u;
static int16_t s_setup_error = 0;
static uint32_t s_setup_deadline_ms = 0u;
static uint8_t s_last_range_status = 255u;
static float s_last_range_m = 0.0f;
static float s_metrics[10] = {0.0f};
static uint32_t s_measurement_count = 0u;
static uint32_t s_valid_count = 0u;
static uint32_t s_no_object_count = 0u;
static uint32_t s_status12_count = 0u;
static uint32_t bus_error_address=0,bus_error_register=0,bus_error_code=0,front_ack=0;

/*
 * The official ULD platform is compiled as C. Keep all ESP32 Arduino I2C
 * access in this C++ translation unit and expose only a small C ABI to it.
 * This prevents ESP-IDF's legacy driver and Arduino's new driver from being
 * linked into the same firmware.
 */
extern "C" int vl53lx_wire_i2c_init(void)
{
    if (s_wire_ready) {
        return 0;
    }

    if (Wire1.setBufferSize(VL53_I2C_BUFFER_SIZE) <
        VL53_I2C_BUFFER_SIZE) {
        return -1;
    }
    if (!Wire1.begin(VL53_I2C_SDA, VL53_I2C_SCL, VL53_I2C_HZ)) {
        return -1;
    }

    s_wire_ready = true;
    return 0;
}

extern "C" int vl53lx_wire_write(
    uint8_t address,
    uint16_t index,
    const uint8_t *data,
    uint32_t count)
{
    if (!s_wire_ready || count > VL53_I2C_MAX_TRANSFER ||
        (count != 0u && data == nullptr)) {
        return -1;
    }

    Wire1.beginTransmission(address);
    if (Wire1.write((uint8_t)(index >> 8)) != 1u ||
        Wire1.write((uint8_t)(index & 0xFFu)) != 1u ||
        (count != 0u &&
         Wire1.write(data, (size_t)count) != (size_t)count)) {
        (void)Wire1.endTransmission(true);
        return -1;
    }

    uint8_t result=Wire1.endTransmission(true);
    if(result){bus_error_address=address;bus_error_register=index;bus_error_code=result;}
    return result==0u?0:-1;
}

extern "C" int vl53lx_wire_read(
    uint8_t address,
    uint16_t index,
    uint8_t *data,
    uint32_t count)
{
    if (!s_wire_ready || count > VL53_I2C_MAX_TRANSFER ||
        (count != 0u && data == nullptr)) {
        return -1;
    }
    if (count == 0u) {
        return 0;
    }

    Wire1.beginTransmission(address);
    if (Wire1.write((uint8_t)(index >> 8)) != 1u ||
        Wire1.write((uint8_t)(index & 0xFFu)) != 1u) {
        return -1;
    }
    uint8_t err=Wire1.endTransmission(false);
    if(err){bus_error_address=address;bus_error_register=index;bus_error_code=err;return -1;}

    const size_t received =
        Wire1.requestFrom(address, (size_t)count, true);
    if (received != (size_t)count) {
        bus_error_address=address;bus_error_register=index;bus_error_code=100+received;
        return -1;
    }

    for (uint32_t i = 0u; i < count; ++i) {
        const int value = Wire1.read();
        if (value < 0) {
            return -1;
        }
        data[i] = (uint8_t)value;
    }

    return 0;
}

static void IRAM_ATTR bottom_tof_interrupt_128(void)
{
    s_data_ready_interrupt = 1u;
}

static bool deadline_reached(uint32_t now_ms, uint32_t deadline_ms)
{
    return (int32_t)(now_ms - deadline_ms) >= 0;
}

static void fail_setup(VL53LX_Error status)
{
    s_setup_error = (int16_t)status;
    s_setup_failed = true;
}

static void advance_setup(void)
{
    VL53LX_Error status = VL53LX_ERROR_NONE;
    const uint32_t now_ms = millis();

    if (s_ready || s_setup_failed) {
        return;
    }

    switch (s_setup_stage) {
    case 1u:
        /*
         * Keep setupImpl fast so External mode can initialize first.
         * Hardware initialization starts from the first model step.
         * The official ULD platform reaches Wire1 through the C bridge above,
         * so the complete firmware uses only Arduino's new I2C driver.
         */
        if (vl53lx_i2c_init() != 0) {
            fail_setup(VL53LX_ERROR_CONTROL_INTERFACE);
            break;
        }
        pinMode(VL53_XSHUT_BOTTOM, OUTPUT);
        pinMode(VL53_XSHUT_FRONT, OUTPUT);
        pinMode(VL53_INT_BOTTOM, INPUT);
        digitalWrite(VL53_XSHUT_BOTTOM, LOW);
        digitalWrite(VL53_XSHUT_FRONT, LOW);
        s_setup_deadline_ms = now_ms + 50u;
        s_setup_stage = 2u;
        break;

    case 2u:
        if (!deadline_reached(now_ms, s_setup_deadline_ms)) {
            break;
        }
        digitalWrite(VL53_XSHUT_BOTTOM, HIGH);
        s_setup_deadline_ms = now_ms + 100u;
        s_setup_stage = 3u;
        break;

    case 3u:
        if (!deadline_reached(now_ms, s_setup_deadline_ms)) {
            break;
        }
        status = VL53LX_WaitDeviceBooted(s_bottom);
        if (status == VL53LX_ERROR_NONE) {
            s_setup_stage = 4u;
        } else {
            fail_setup(status);
        }
        break;

    case 4u:
        status = VL53LX_DataInit(s_bottom);
        if (status == VL53LX_ERROR_NONE) {
            s_setup_stage = 5u;
        } else {
            fail_setup(status);
        }
        break;

    case 5u:
        status = VL53LX_SetDistanceMode(
            s_bottom, VL53LX_DISTANCEMODE_MEDIUM);
        if (status == VL53LX_ERROR_NONE) {
            s_setup_stage = 6u;
        } else {
            fail_setup(status);
        }
        break;

    case 6u:
        status = VL53LX_SetMeasurementTimingBudgetMicroSeconds(
            s_bottom, VL53_OFFICIAL_BUDGET_US);
        if (status == VL53LX_ERROR_NONE) {
            s_setup_stage = 7u;
        } else {
            fail_setup(status);
        }
        break;

    case 7u:
        attachInterrupt(
            VL53_INT_BOTTOM, bottom_tof_interrupt_128, FALLING);
        s_data_ready_interrupt = 0u;
        status = VL53LX_StartMeasurement(s_bottom);
        if (status == VL53LX_ERROR_NONE) {
            s_setup_stage = 8u;
            s_ready = true;
        } else {
            fail_setup(status);
        }
        break;

    default:
        fail_setup(VL53LX_ERROR_INVALID_PARAMS);
        break;
    }
}

extern "C" void vl53l3cx_bottom_official128_setup(void)
{
    memset(&s_bottom_device, 0, sizeof(s_bottom_device));
    s_bottom->comms_speed_khz = 400u;
    s_bottom->i2c_slave_address = 0x29u;

    s_ready = false;
    s_setup_failed = false;
    s_setup_stage = 1u;
    s_setup_error = 0;
    s_setup_deadline_ms = 0u;
    s_last_range_status = 255u;
    s_last_range_m = 0.0f;
    s_data_ready_interrupt = 0u;
    s_measurement_count = 0u;
    s_valid_count = 0u;
    s_no_object_count = 0u;
    s_status12_count = 0u;
    for (uint8_t i = 0u; i < 10u; ++i) {
        s_metrics[i] = 0.0f;
    }
}

extern "C" void vl53l3cx_bottom_official128_step(
    float range_m[1],
    float raw_range_m[1],
    uint8_t range_status[1],
    uint8_t fresh_valid[1],
    uint8_t new_data[1],
    float metrics[10])
{
    static VL53LX_MultiRangingData_t data;

    range_m[0] = s_last_range_m;
    raw_range_m[0] = 0.0f;
    range_status[0] = s_last_range_status;
    fresh_valid[0] = 0u;
    new_data[0] = 0u;

    if (!s_ready) {
        advance_setup();
        s_last_range_status = (uint8_t)(100u + s_setup_stage);
        range_status[0] = s_last_range_status;
        range_m[0] = (float)s_setup_error;
    } else if (s_data_ready_interrupt != 0u) {
        uint8_t selected_valid = 0u;
        uint8_t selected_diag = 0u;
        bool valid_found = false;
        bool diag_found = false;

        s_data_ready_interrupt = 0u;
        new_data[0] = 1u;

        if (VL53LX_GetMultiRangingData(s_bottom, &data) !=
            VL53LX_ERROR_NONE) {
            s_last_range_status = 90u;
        } else {
            bool status12_seen = false;

            ++s_measurement_count;
            s_metrics[3] = (float)data.NumberOfObjectsFound;
            s_metrics[4] =
                (float)data.EffectiveSpadRtnCount / 256.0f;
            s_metrics[5] = (float)data.StreamCount;
            if (data.NumberOfObjectsFound == 0u) {
                ++s_no_object_count;
            }

            for (uint8_t i = 0u;
                 i < data.NumberOfObjectsFound;
                 ++i) {
                const int16_t mm = data.RangeData[i].RangeMilliMeter;

                if (data.RangeData[i].RangeStatus ==
                    VL53LX_RANGESTATUS_TARGET_PRESENT_LACK_OF_SIGNAL) {
                    status12_seen = true;
                }
                if (!diag_found ||
                    mm > data.RangeData[selected_diag].RangeMilliMeter) {
                    selected_diag = i;
                    diag_found = true;
                }
                if (data.RangeData[i].RangeStatus ==
                        VL53LX_RANGESTATUS_RANGE_VALID &&
                    (!valid_found ||
                     mm > data.RangeData[selected_valid].RangeMilliMeter)) {
                    selected_valid = i;
                    valid_found = true;
                }
            }

            if (status12_seen) {
                ++s_status12_count;
            }

            if (valid_found) {
                const VL53LX_TargetRangeData_t *target =
                    &data.RangeData[selected_valid];
                const float measured_range_m =
                    (float)target->RangeMilliMeter * 0.001f;

                s_last_range_status = target->RangeStatus;
                if (target->RangeMilliMeter > 0) {
                    /*
                     * RawRange is intentionally status-agnostic. Range_m and
                     * FreshValid retain their strict status-0 behavior.
                     */
                    raw_range_m[0] = measured_range_m;
                }
                s_metrics[0] =
                    (float)target->SignalRateRtnMegaCps / 65536.0f;
                s_metrics[1] =
                    (float)target->AmbientRateRtnMegaCps / 65536.0f;
                s_metrics[2] =
                    (float)target->SigmaMilliMeter / 65536.0f;

                /*
                 * The bottom sensor sits about 20 mm above the floor. Using
                 * the official firmware's strict >20 mm cutoff makes a valid
                 * stationary reading alternate between accepted and rejected,
                 * so HeightValid never remains asserted. RangeStatus is
                 * already RANGE_VALID; retain a small nonzero guard instead.
                 */
                if (target->RangeMilliMeter >= 10) {
                    s_last_range_m = measured_range_m;
                    fresh_valid[0] = 1u;
                    ++s_valid_count;
                }
            } else if (diag_found) {
                const VL53LX_TargetRangeData_t *target =
                    &data.RangeData[selected_diag];
                const float measured_range_m =
                    (float)target->RangeMilliMeter * 0.001f;
                s_last_range_status = target->RangeStatus;
                if (target->RangeMilliMeter > 0) {
                    /*
                     * Expose the measured target even when the vendor
                     * RangeStatus is not RANGE_VALID.
                     */
                    raw_range_m[0] = measured_range_m;
                }
                s_metrics[0] =
                    (float)target->SignalRateRtnMegaCps / 65536.0f;
                s_metrics[1] =
                    (float)target->AmbientRateRtnMegaCps / 65536.0f;
                s_metrics[2] =
                    (float)target->SigmaMilliMeter / 65536.0f;
            } else {
                s_last_range_status = 255u;
                s_metrics[0] = 0.0f;
                s_metrics[1] = 0.0f;
                s_metrics[2] = 0.0f;
            }

            s_metrics[6] = (float)s_measurement_count;
            s_metrics[7] = (float)s_valid_count;
            s_metrics[8] = (float)s_no_object_count;
            s_metrics[9] = (float)s_status12_count;
        }

        (void)VL53LX_ClearInterruptAndStartMeasurement(s_bottom);
        range_m[0] = s_last_range_m;
        range_status[0] = s_last_range_status;
    }

    for (uint8_t i = 0u; i < 10u; ++i) {
        metrics[i] = s_metrics[i];
    }
}

// Official-compatible startup/acquisition API. Startup finishes before 400Hz.
#include "official_tof.h"
static VL53LX_Dev_t official_front_device;
static VL53LX_DEV official_front = &official_front_device;
static uint8_t official_status=0;
static uint16_t official_dcnt=0;
static int16_t official_bottom_mm=0,official_front_mm=0;
static SemaphoreHandle_t official_bus_mutex=nullptr;
static TaskHandle_t official_tof_task=nullptr;
static portMUX_TYPE official_tof_lock=portMUX_INITIALIZER_UNLOCKED;
static uint8_t official_requested_mode=0;
static uint32_t official_requests=0,official_completed=0,official_consumed=0;
static uint32_t official_max_read_us=0;
static constexpr bool official_front_enabled=false;
static bool official_front_fault=false;
static uint32_t official_front_frames=0,official_front_valid=0;
static uint8_t official_front_ready=0,official_front_range_status=255;
static int32_t official_front_error=0;
static uint8_t official_front_error_stage=0,official_warm=0;
static uint32_t official_bottom_frames=0,official_bottom_valid=0,official_bottom_errors=0;
static uint8_t official_bottom_range_status=255,official_bottom_objects=0,official_bottom_stream=0;
static int16_t official_bottom_raw_mm=0;
static int32_t official_bottom_error=0;
extern "C" void official_tof_info(uint32_t info[4]) {
    portENTER_CRITICAL(&official_tof_lock);
    info[0]=official_completed;info[1]=official_requests;
    info[2]=official_max_read_us;info[3]=official_status;
    portEXIT_CRITICAL(&official_tof_lock);
}
extern "C" void official_front_info(uint32_t info[6]) {
    portENTER_CRITICAL(&official_tof_lock);
    info[0]=official_front_frames;info[1]=official_front_valid;
    info[2]=uint32_t(official_front_mm);info[3]=official_front_range_status;
    info[4]=official_front_ready;info[5]=official_front_fault;
    portEXIT_CRITICAL(&official_tof_lock);
}
extern "C" void official_tof_debug(int32_t info[5]) {
    info[0]=official_front_error;info[1]=official_front_error_stage;
    info[2]=official_status;info[3]=official_warm;info[4]=s_ready;
}
extern "C" void official_tof_bus_info(uint32_t info[4]) {
    info[0]=bus_error_address;info[1]=bus_error_register;info[2]=bus_error_code;info[3]=front_ack;
}
extern "C" void official_bottom_info(int32_t info[10]) {
    portENTER_CRITICAL(&official_tof_lock);
    info[0]=official_bottom_frames;info[1]=official_bottom_valid;info[2]=official_bottom_errors;
    info[3]=official_bottom_mm;info[4]=official_bottom_raw_mm;info[5]=official_bottom_range_status;
    info[6]=official_bottom_objects;info[7]=official_bottom_stream;
    info[8]=official_bottom_error;info[9]=s_ready;
    portEXIT_CRITICAL(&official_tof_lock);
}
extern "C" uint8_t official_i2c_try_lock(void) {
    return official_bus_mutex && xSemaphoreTake(official_bus_mutex,0)==pdTRUE;
}
extern "C" void official_i2c_unlock(void) {xSemaphoreGive(official_bus_mutex);}

static int16_t official_farthest(VL53LX_DEV dev,uint8_t* rangeStatus=nullptr,int* error=nullptr) {
    VL53LX_MultiRangingData_t data{};
    int16_t farthest=0;
    if(rangeStatus)*rangeStatus=255;
    VL53LX_Error read_result=VL53LX_GetMultiRangingData(dev,&data);
    if(read_result==VL53LX_ERROR_NONE) {
        if(rangeStatus && data.NumberOfObjectsFound)*rangeStatus=data.RangeData[0].RangeStatus;
        for(uint8_t i=0;i<data.NumberOfObjectsFound;++i) {
            if(data.RangeData[i].RangeStatus==VL53LX_RANGESTATUS_RANGE_VALID &&
               data.RangeData[i].RangeMilliMeter>farthest)
                {farthest=data.RangeData[i].RangeMilliMeter;if(rangeStatus)*rangeStatus=0;}
        }
    }
    VL53LX_Error restart_result=VL53LX_ClearInterruptAndStartMeasurement(dev);
    if(dev==s_bottom) {
        int16_t raw=0;uint8_t rawStatus=255;
        if(!read_result)for(uint8_t i=0;i<data.NumberOfObjectsFound && i<VL53LX_MAX_RANGE_RESULTS;++i) {
            if(data.RangeData[i].RangeMilliMeter>raw) {raw=data.RangeData[i].RangeMilliMeter;rawStatus=data.RangeData[i].RangeStatus;}
        }
        int err=read_result?read_result:restart_result;
        portENTER_CRITICAL(&official_tof_lock);
        if(!read_result)++official_bottom_frames;
        if(!err && farthest>0)++official_bottom_valid;
        if(err)++official_bottom_errors;
        official_bottom_raw_mm=raw;official_bottom_error=err;
        official_bottom_objects=read_result?0:data.NumberOfObjectsFound;
        official_bottom_stream=read_result?0:data.StreamCount;
        official_bottom_range_status=err?90:(farthest>0?0:rawStatus);
        portEXIT_CRITICAL(&official_tof_lock);
        if(err)farthest=0;
    }
    if(error)*error=read_result?read_result:restart_result;
    if(dev==official_front && (read_result || restart_result)) {
        official_front_error=read_result?read_result:restart_result;
        official_front_error_stage=read_result?2:3;
    }
    return farthest;
}
static void official_tof_worker(void*) {
    for(;;) {
        ulTaskNotifyTake(pdTRUE,portMAX_DELAY);
        uint8_t mode;
        portENTER_CRITICAL(&official_tof_lock);mode=official_requested_mode;portEXIT_CRITICAL(&official_tof_lock);
        xSemaphoreTake(official_bus_mutex,portMAX_DELAY);
        uint32_t start=micros();
        int16_t bottom=official_farthest(s_bottom),front=official_front_mm;
        if(official_front_enabled && mode==3 && !official_front_fault) {
            // Official Parking read has no readiness gate on the front.
            uint8_t rangeStatus=255;int r=0;
            front=official_farthest(official_front,&rangeStatus,&r);
            portENTER_CRITICAL(&official_tof_lock);
            if(!r){++official_front_frames;official_front_valid+=(rangeStatus==0);official_front_range_status=rangeStatus;}
            if(r){official_status=9;official_front_fault=true;if(!official_front_error){official_front_error=r;official_front_error_stage=2;}}
            portEXIT_CRITICAL(&official_tof_lock);
            if(r){
                Wire1.beginTransmission(0x2a);front_ack=Wire1.endTransmission();
                for(uint8_t addr=1;addr<127;++addr) {
                    Wire1.beginTransmission(addr);
                    if(Wire1.endTransmission()==0)Serial.printf("SFTOF_FAULT_SCAN addr=%u\n",addr);
                }
            }
        }
        xSemaphoreGive(official_bus_mutex);
        portENTER_CRITICAL(&official_tof_lock);
        uint32_t elapsed=micros()-start;
        if(elapsed>official_max_read_us)official_max_read_us=elapsed;
        official_bottom_mm=bottom;official_front_mm=front;++official_completed;
        portEXIT_CRITICAL(&official_tof_lock);
    }
}
extern "C" void official_tof_setup(void) {
    Serial.begin(921600);
    official_status=0;official_dcnt=0;official_bottom_mm=official_front_mm=0;
    // The forward sensor is unused for this experiment (user instruction).
    official_front_fault=false;official_front_ready=0;
    official_bottom_frames=official_bottom_valid=official_bottom_errors=0;
    official_bottom_raw_mm=0;official_bottom_range_status=255;official_bottom_error=0;
    bus_error_address=bus_error_register=bus_error_code=0;
    vl53l3cx_bottom_official128_setup();
    if(vl53lx_i2c_init()!=0) {official_status=1;return;}
    // A 128-byte transfer already needs about 3 ms at 400 kHz. This timeout
    // belongs to the core0 IO worker; the 400 Hz model never waits for it.
    Wire1.setTimeOut(20);
    pinMode(VL53_XSHUT_BOTTOM,OUTPUT);pinMode(VL53_XSHUT_FRONT,OUTPUT);
    pinMode(VL53_INT_BOTTOM,INPUT);pinMode(8,INPUT);
    digitalWrite(VL53_XSHUT_BOTTOM,LOW);digitalWrite(VL53_XSHUT_FRONT,LOW);
    delay(10);
    memset(&official_front_device,0,sizeof(official_front_device));
    official_front->comms_speed_khz=400;official_front->i2c_slave_address=0x29;
    // XSHUT_FRONT stays LOW; no front transactions can contaminate bottom status.
    Serial.printf("SFTOF_FRONT disabled=1\n");
    digitalWrite(VL53_XSHUT_BOTTOM,HIGH);delay(100);
    if(VL53LX_WaitDeviceBooted(s_bottom)!=VL53LX_ERROR_NONE ||
       VL53LX_DataInit(s_bottom)!=VL53LX_ERROR_NONE ||
       VL53LX_SetDistanceMode(s_bottom,VL53LX_DISTANCEMODE_MEDIUM)!=VL53LX_ERROR_NONE ||
       VL53LX_SetMeasurementTimingBudgetMicroSeconds(s_bottom,33000)!=VL53LX_ERROR_NONE) {
        official_status=3;return;
    }
    attachInterrupt(VL53_INT_BOTTOM,bottom_tof_interrupt_128,FALLING);
    s_data_ready_interrupt=0;
    // Start exactly once from DataInit's standby state. Calling Clear/Start
    // first advances the ULD configuration stream without reading a frame;
    // a second Start then leaves zone expectations one frame out of sync.
    if(VL53LX_StartMeasurement(s_bottom)!=VL53LX_ERROR_NONE) {official_status=5;return;}
    // Official waits for 10 initial frames. Add timeout instead of boot deadlock.
    uint32_t start=millis();uint8_t warm=0;
    while(warm<10 && millis()-start<5000) {
        if(s_data_ready_interrupt) {
            s_data_ready_interrupt=0;
            int error=0;official_farthest(s_bottom,nullptr,&error);
            if(!error)++warm;
        }
        delay(1);
    }
    if(warm<10)official_status=6;
    official_warm=warm;
    s_ready=warm==10; // A front-sensor fault must not stop the bottom sensor.
    official_requests=official_completed=official_consumed=0;
    official_bus_mutex=xSemaphoreCreateMutex();
    if(!official_bus_mutex || xTaskCreatePinnedToCore(official_tof_worker,"SFToF",16384,nullptr,3,&official_tof_task,0)!=pdPASS) {
        official_status=7;s_ready=false;
    }
    for(uint8_t addr: {uint8_t(0x29),uint8_t(0x2a),uint8_t(0x40)}) {
        Wire1.beginTransmission(addr);
        Serial.printf("SFTOF_SCAN addr=%u result=%u\n",addr,Wire1.endTransmission());
    }
    Serial.printf("SFTOF_SETUP status=%u warm=%u\n",official_status,warm);
}
extern "C" void official_tof_step(uint8_t mode,int16_t bottom[1],uint8_t newData[1],int16_t front[1],uint8_t status[1]) {
    newData[0]=0;
    portENTER_CRITICAL(&official_tof_lock);
    bottom[0]=official_bottom_mm;front[0]=official_front_mm;
    status[0]=s_ready?official_bottom_range_status:uint8_t(100+official_status);
    if(official_completed!=official_consumed) {newData[0]=1;official_consumed=official_completed;}
    bool idle=official_requests==official_completed;
    portEXIT_CRITICAL(&official_tof_lock);
    if(mode>1 && s_ready) {
        if(official_dcnt>14) {
            if(s_data_ready_interrupt && idle) {
                official_dcnt=0;s_data_ready_interrupt=0;
                portENTER_CRITICAL(&official_tof_lock);
                official_requested_mode=mode;++official_requests;
                portEXIT_CRITICAL(&official_tof_lock);
                xTaskNotifyGive(official_tof_task);
            }
        } else ++official_dcnt;
    }
}

extern "C" void official_tof_source_step(int16_t bottom[1],uint8_t newData[1],int16_t front[1],uint8_t status[1]) {
    // The active model samples continuously. Initialization readiness, minimum
    // interval, interrupt readiness, mutex, and worker-busy guards remain in
    // official_tof_step. Keep the old API for archived implementation models.
    official_tof_step(uint8_t(2),bottom,newData,front,status);
}

#else

extern "C" void vl53l3cx_bottom_official128_setup(void)
{
}

extern "C" void vl53l3cx_bottom_official128_step(
    float range_m[1],
    float raw_range_m[1],
    uint8_t range_status[1],
    uint8_t fresh_valid[1],
    uint8_t new_data[1],
    float metrics[10])
{
    range_m[0] = 0.0f;
    raw_range_m[0] = 0.0f;
    range_status[0] = 255u;
    fresh_valid[0] = 0u;
    new_data[0] = 0u;
    for (uint8_t i = 0u; i < 10u; ++i) {
        metrics[i] = 0.0f;
    }
}

extern "C" void official_front_info(uint32_t info[6]) {for(int i=0;i<6;++i)info[i]=0;}
extern "C" void official_tof_debug(int32_t info[5]) {for(int i=0;i<5;++i)info[i]=0;}
extern "C" void official_tof_bus_info(uint32_t info[4]) {for(int i=0;i<4;++i)info[i]=0;}
extern "C" void official_bottom_info(int32_t info[10]) {for(int i=0;i<10;++i)info[i]=0;}
extern "C" void official_tof_setup(void) {}
extern "C" void official_tof_info(uint32_t info[4]) {for(int i=0;i<4;++i)info[i]=0;}
extern "C" void official_tof_step(uint8_t,int16_t b[1],uint8_t n[1],int16_t f[1],uint8_t s[1]) {
    b[0]=0;n[0]=0;f[0]=0;s[0]=0;
}
extern "C" void official_tof_source_step(int16_t b[1],uint8_t n[1],int16_t f[1],uint8_t s[1]) {
    official_tof_step(uint8_t(2),b,n,f,s);
}

#endif
