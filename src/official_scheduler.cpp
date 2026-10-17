// Local linker wrappers replace only MathWorks Timer1, leaving installed files intact.
// Requires --wrap=mw_osTimerCreate,Start,Stop,Delete and fixed-step .0025 model.
#include "official_scheduler.h"
#include <string.h>
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#include <driver/gptimer.h>
#include <esp_timer.h>
#include <esp_system.h>
#include <esp_freertos_hooks.h>
#include "official_usb.h"
#include "mw_timer.h"
#include "mw_semaphore.h"
extern "C" mw_semaphore_t baserateTaskSem;
extern "C" int __real_mw_osTimerCreate(mw_timer_t*,TimerCallbackFunction_t);
extern "C" int __real_mw_osTimerStart(mw_timer_t*,TickType_t);
extern "C" int __real_mw_osTimerStop(mw_timer_t*);
extern "C" int __real_mw_osTimerDelete(mw_timer_t*);
namespace {
gptimer_handle_t timer=nullptr;
mw_timer_t* schedulerDef=nullptr;
volatile uint32_t ticks=0,missed=0;
uint32_t error=0;
bool IRAM_ATTR alarm(gptimer_handle_t,const gptimer_alarm_event_data_t*,void*) {
  BaseType_t woken=pdFALSE;
  ++ticks;
  // Coalesce a pending tick rather than running back-to-back catch-up steps.
  if(uxSemaphoreGetCountFromISR(baserateTaskSem)==0) {
    if(xSemaphoreGiveFromISR(baserateTaskSem,&woken)!=pdTRUE) ++missed;
  } else ++missed;
  return woken==pdTRUE;
}
}
extern "C" int __wrap_mw_osTimerCreate(mw_timer_t* def,TimerCallbackFunction_t cb) {
  if(strcmp(def->name,"Timer1")!=0) return __real_mw_osTimerCreate(def,cb);
  schedulerDef=def;ticks=0;missed=0;error=0;
  gptimer_config_t config{};
  config.clk_src=GPTIMER_CLK_SRC_DEFAULT;config.direction=GPTIMER_COUNT_UP;
  config.resolution_hz=1000000;
  esp_err_t result=gptimer_new_timer(&config,&timer);
  if(result!=ESP_OK) {error=result;return 1;}
  gptimer_event_callbacks_t callbacks{};callbacks.on_alarm=alarm;
  result=gptimer_register_event_callbacks(timer,&callbacks,nullptr);
  if(result==ESP_OK) {
    gptimer_alarm_config_t period{};period.alarm_count=2500;
    period.reload_count=0;period.flags.auto_reload_on_alarm=true;
    result=gptimer_set_alarm_action(timer,&period);
  }
  if(result==ESP_OK) result=gptimer_enable(timer);
  if(result!=ESP_OK) {error=result;return 1;}
  // MathWorks checks non-null; only our wrappers ever operate on this handle.
  def->handle=reinterpret_cast<TimerHandle_t>(timer);
  return 0;
}
extern "C" int __wrap_mw_osTimerStart(mw_timer_t* def,TickType_t wait) {
  if(def!=schedulerDef) return __real_mw_osTimerStart(def,wait);
  esp_err_t r=gptimer_start(timer);error=r;return r==ESP_OK?0:1;
}
extern "C" int __wrap_mw_osTimerStop(mw_timer_t* def) {
  if(def!=schedulerDef) return __real_mw_osTimerStop(def);
  esp_err_t r=gptimer_stop(timer);error=r;return r==ESP_OK?0:1;
}
extern "C" int __wrap_mw_osTimerDelete(mw_timer_t* def) {
  if(def!=schedulerDef) return __real_mw_osTimerDelete(def);
  esp_err_t r=gptimer_disable(timer);
  if(r==ESP_OK) r=gptimer_del_timer(timer);
  error=r;timer=nullptr;schedulerDef=nullptr;def->handle=nullptr;return r==ESP_OK?0:1;
}
// Wrap the generated step at the call in ert_main.c to measure the entire
// task, including outputs, status queues and Unit Delay state updates.
#if defined(OFFICIAL_BENCH_PROFILE) || defined(OFFICIAL_FLIGHT_TEST_PROFILE) || defined(OFFICIAL_PID_BLOCK_TEST_PROFILE) || defined(OFFICIAL_BASIC_PROFILE) || defined(OFFICIAL_IMU_PROFILE) || defined(OFFICIAL_KF_PROFILE)
#if defined(OFFICIAL_BENCH_PROFILE)
#define OFFICIAL_REAL_STEP __real_StampFly_Official_Bench400_step
#define OFFICIAL_WRAP_STEP __wrap_StampFly_Official_Bench400_step
#elif defined(OFFICIAL_PID_BLOCK_TEST_PROFILE)
#define OFFICIAL_REAL_STEP __real_StampFly_PIDBlock_FlightTest400_step
#define OFFICIAL_WRAP_STEP __wrap_StampFly_PIDBlock_FlightTest400_step
#elif defined(OFFICIAL_BASIC_PROFILE)
#define OFFICIAL_REAL_STEP __real_StampFly_Basic400_step
#define OFFICIAL_WRAP_STEP __wrap_StampFly_Basic400_step
#elif defined(OFFICIAL_IMU_PROFILE)
#define OFFICIAL_REAL_STEP __real_StampFly_IMU400_step
#define OFFICIAL_WRAP_STEP __wrap_StampFly_IMU400_step
#elif defined(OFFICIAL_KF_PROFILE)
#define OFFICIAL_REAL_STEP __real_StampFly_KF400_step
#define OFFICIAL_WRAP_STEP __wrap_StampFly_KF400_step
#else
#define OFFICIAL_REAL_STEP __real_StampFly_Official_FlightTest400_step
#define OFFICIAL_WRAP_STEP __wrap_StampFly_Official_FlightTest400_step
#endif
extern "C" void OFFICIAL_REAL_STEP(void);
extern "C" void OFFICIAL_WRAP_STEP(void) {
  uint32_t start=official_now_us();
  OFFICIAL_REAL_STEP();
  uint32_t elapsed=official_now_us()-start;
  static uint32_t count=0,total=0,maximum=0,over=0;
  ++count;total+=elapsed;if(elapsed>maximum)maximum=elapsed;if(elapsed>2500)++over;
  if(count==400) {
    char line[160];int length=snprintf(line,sizeof(line),
      "SFTASK n=%lu mean_us=%lu max_us=%lu over=%lu missed=%lu\n",count,total/count,maximum,over,missed);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    count=total=maximum=over=0;
  }
}
#endif
#endif
extern "C" uint32_t official_now_us(void) {
#if defined(ARDUINO_ARCH_ESP32)
  return static_cast<uint32_t>(esp_timer_get_time());
#else
  return 0;
#endif
}
namespace {
#if defined(ARDUINO_ARCH_ESP32)
volatile uint32_t idleAt0=0,idleAt1=0;
bool idle0(){idleAt0=official_now_us();return true;}
bool idle1(){idleAt1=official_now_us();return true;}
uint32_t idleHookStatus=0;
bool runtimeInitialized=false;
uint32_t stackMinimum=0xffffffff;
#endif
}
extern "C" uint8_t official_reset_reason(void) {
#if defined(ARDUINO_ARCH_ESP32)
  return static_cast<uint8_t>(esp_reset_reason());
#else
  return 0;
#endif
}
extern "C" void official_runtime_setup(void) {
#if defined(ARDUINO_ARCH_ESP32)
  if(runtimeInitialized)return;
  idleAt0=idleAt1=official_now_us();
  esp_err_t e0=esp_register_freertos_idle_hook_for_cpu(idle0,0);
  esp_err_t e1=esp_register_freertos_idle_hook_for_cpu(idle1,1);
  idleHookStatus=(e0==ESP_OK?0u:1u)|(e1==ESP_OK?0u:2u);
  runtimeInitialized=true;
#endif
}
extern "C" void official_runtime_info(uint32_t info[7]) {
  memset(info,0,7*sizeof(uint32_t));
#if defined(ARDUINO_ARCH_ESP32)
  const uint32_t now=official_now_us();
  const uint32_t stack=uxTaskGetStackHighWaterMark(nullptr);
  if(stack<stackMinimum)stackMinimum=stack;
  info[0]=official_reset_reason();info[1]=now-idleAt0;info[2]=now-idleAt1;
  info[3]=stackMinimum;info[4]=xPortGetFreeHeapSize();
  info[5]=xPortGetCoreID();info[6]=idleHookStatus;
#endif
}
static uint32_t profileMax[4]={};
extern "C" void official_profile_record(uint8_t section,uint32_t start) {
  uint32_t elapsed=official_now_us()-start;
  if(section<4 && elapsed>profileMax[section])profileMax[section]=elapsed;
}
extern "C" uint32_t official_profile_max(uint8_t section) {
  return section<4?profileMax[section]:0;
}
extern "C" void official_scheduler_info(uint32_t info[4]) {
  memset(info,0,4*sizeof(uint32_t));
#if defined(ARDUINO_ARCH_ESP32)
  info[0]=ticks;info[1]=missed;info[2]=2500;info[3]=error;
#endif
}
