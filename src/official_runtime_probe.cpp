// 概要：生成された制御式を変えず、既存の外部関数呼び出し間を計測します。
// リンカーの --wrap で入口を挟み、同じ引数・同じ戻り値をそのまま渡します。
// 区間時間には割込みと他タスクによる待ち時間も含まれます。
#include "official_scheduler.h"
#if defined(ARDUINO_ARCH_ESP32) && defined(OFFICIAL_RUNTIME_SECTIONS)
#include <stdio.h>
#include <string.h>
#include "official_usb.h"

namespace {
constexpr unsigned kSections=12;
const char* const names[kSections]={
  "imu_io","estimate_before_radio","radio_to_flow","flow_io",
  "flow_to_pwm","pwm_io","telemetry","timing_diagnostic",
  "distance_and_reply","status_compute","status_queue","state_update"};
uint32_t totals[kSections]={},maximum[kSections]={};
uint32_t previous=0,cycles=0;
bool active=false;
void mark(unsigned index) {
  if(!active)return;
  const uint32_t now=official_now_us(),elapsed=now-previous;
  previous=now;
  totals[index]+=elapsed;
  if(elapsed>maximum[index])maximum[index]=elapsed;
}
}

extern "C" void official_sections_begin(uint32_t start) {
  previous=start;active=true;
}
extern "C" void official_sections_end() {
  mark(11);active=false;
  if(++cycles!=400)return;
  // 毎秒4行へ分割し、USBキューの256 byte上限内で平均・最大を保存します。
  for(unsigned i=0;i<kSections;i+=3) {
    char line[256];const int n=snprintf(line,sizeof(line),
      "SFSECTIONS n=%lu %s=%lu,%lu %s=%lu,%lu %s=%lu,%lu\n",
      static_cast<unsigned long>(cycles),
      names[i],static_cast<unsigned long>(totals[i]/cycles),static_cast<unsigned long>(maximum[i]),
      names[i+1],static_cast<unsigned long>(totals[i+1]/cycles),static_cast<unsigned long>(maximum[i+1]),
      names[i+2],static_cast<unsigned long>(totals[i+2]/cycles),static_cast<unsigned long>(maximum[i+2]));
    if(n>0 && n<static_cast<int>(sizeof(line)))
      official_usb_bytes(reinterpret_cast<const uint8_t*>(line),static_cast<uint16_t>(n));
  }
  memset(totals,0,sizeof(totals));memset(maximum,0,sizeof(maximum));cycles=0;
}

extern "C" void __real_bmi270_imu_step(float*,float*,float*,uint8_t*);
extern "C" void __wrap_bmi270_imu_step(float* a,float* g,float* t,uint8_t* s) {
  __real_bmi270_imu_step(a,g,t,s);mark(0);
}
extern "C" void __real_official_radio_step(float*,uint8_t*,uint8_t*,uint8_t*);
extern "C" void __wrap_official_radio_step(float* s,uint8_t* a,uint8_t* c,uint8_t* r) {
  mark(1);__real_official_radio_step(s,a,c,r);
}
extern "C" void __real_pmw3901_logger_step(float*,uint16_t*,uint32_t*,uint32_t*);
extern "C" void __wrap_pmw3901_logger_step(float* f,uint16_t* r,uint32_t* i,uint32_t* t) {
  mark(2);__real_pmw3901_logger_step(f,r,i,t);mark(3);
}
extern "C" void __real_official_pwm_step(const uint8_t*,uint8_t,uint8_t*,uint32_t*);
extern "C" void __wrap_official_pwm_step(const uint8_t* c,uint8_t e,uint8_t* a,uint32_t* i) {
  mark(4);__real_official_pwm_step(c,e,a,i);mark(5);
}
extern "C" void __real_official_timing_end(uint32_t,uint8_t,const uint8_t*,const uint32_t*,uint32_t*);
extern "C" void __wrap_official_timing_end(uint32_t s,uint8_t f,const uint8_t* a,const uint32_t* p,uint32_t* r) {
  mark(6);__real_official_timing_end(s,f,a,p,r);mark(7);
}
extern "C" uint8_t __real_official_user_button();
extern "C" uint8_t __wrap_official_user_button() {
  mark(8);return __real_official_user_button();
}
extern "C" void __real_official_status_write(uint32_t,uint32_t,uint32_t,uint8_t);
extern "C" void __wrap_official_status_write(uint32_t c1,uint32_t c2,uint32_t hz,uint8_t r) {
  mark(9);__real_official_status_write(c1,c2,hz,r);mark(10);
}
#endif
