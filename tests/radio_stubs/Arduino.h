#pragma once
#include <stdint.h>
typedef int portMUX_TYPE;
#define portMUX_INITIALIZER_UNLOCKED 0
#define portENTER_CRITICAL(x) ((void)(x))
#define portEXIT_CRITICAL(x) ((void)(x))
extern uint32_t testTimeUs;
inline uint32_t micros(){return testTimeUs;}
inline uint32_t millis(){return testTimeUs/1000;}
