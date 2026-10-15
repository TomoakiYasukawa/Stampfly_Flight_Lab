#include "bmm150_logger.h"
#include "bmm150_driver.h"
#include "official_tof.h"
#include <string.h>
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#include <freertos/task.h>
namespace {
portMUX_TYPE cacheLock = portMUX_INITIALIZER_UNLOCKED;
TaskHandle_t workerTask = nullptr;
float heldMag[3] = {};
uint32_t samples = 0, sampledAt = 0, consumed = 0;
uint32_t lastReadUs = 0, maxReadUs = 0, errors = 0, lastRequestedAt = 0;
uint8_t deviceAddress = 0x10, errorCode = 0;
bool valid = false, pending = false;
void worker(void*) {
    bool initialized = false;
    for (;;) {
        // First notification is from stepImpl, after all model setup completed.
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        while (!official_i2c_try_lock()) vTaskDelay(1);
        if (!initialized) {
            bmm150_mag_setup(deviceAddress);
            initialized = true;
        }
        float value[3] = {}; uint8_t fresh = 0;
        const uint32_t start = micros();
        const int8_t result = bmm150_mag_poll(value, &fresh);
        const uint32_t end = micros();
        official_i2c_unlock();
        portENTER_CRITICAL(&cacheLock);
        lastReadUs = end - start;
        if (lastReadUs > maxReadUs) maxReadUs = lastReadUs;
        errorCode = uint8_t(result < 0 ? -result : result);
        if (result != 0) { ++errors; valid = false; }
        else if (fresh) {
            memcpy(heldMag, value, sizeof(heldMag));
            ++samples; sampledAt = end; valid = true;
        }
        pending = false;
        portEXIT_CRITICAL(&cacheLock);
    }
}
}
#endif
extern "C" void bmm150_logger_setup(uint8_t address) {
#if defined(ARDUINO_ARCH_ESP32)
    deviceAddress = address;
    if (!workerTask)
        xTaskCreatePinnedToCore(worker, "SFMag", 4096, nullptr, 1, &workerTask, 0);
#endif
}
extern "C" void bmm150_logger_step(float mag[3], uint8_t flags[3], uint32_t info[6]) {
    memset(mag, 0, 3*sizeof(float)); memset(flags, 0, 3);
    memset(info, 0, 6*sizeof(uint32_t));
#if defined(ARDUINO_ARCH_ESP32)
    const uint32_t now = micros();
    portENTER_CRITICAL(&cacheLock);
    memcpy(mag, heldMag, sizeof(heldMag));
    const uint32_t age = samples ? now - sampledAt : UINT32_MAX;
    flags[0] = valid && age < 100000u;
    flags[1] = samples != consumed; flags[2] = errorCode;
    consumed = samples;
    info[0] = samples; info[1] = sampledAt; info[2] = age;
    info[3] = lastReadUs; info[4] = maxReadUs; info[5] = errors;
    // 100 Hz data-ready polling captures the 30 Hz sensor's new conversions.
    bool request = workerTask && !pending && uint32_t(now-lastRequestedAt) >= 10000u;
    if (request) { pending = true; lastRequestedAt = now; }
    portEXIT_CRITICAL(&cacheLock);
    if (request) xTaskNotifyGive(workerTask);
#endif
}
