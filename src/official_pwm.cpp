#include "official_pwm.h"
#include <string.h>
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#include <driver/ledc.h>
#include <hal/ledc_ll.h>
#include <soc/ledc_struct.h>
#include <esp_timer.h>
#if !defined(CONFIG_IDF_TARGET_ESP32S3)
#error Official PWM register backend requires ESP32-S3.
#endif
namespace {
// Exclusive ownership: timer0 and channels0..3. Do not share with Arduino PWM.
constexpr int pins[4] = {42,5,41,10}; // FR FL RR RL
bool ready=false;
uint32_t actualHz=0, bits=0;
uint8_t status=0;
inline void writeCounts(const uint8_t counts[4],bool enabled) {
  for (int i=0;i<4;++i) {
    const ledc_channel_t ch=static_cast<ledc_channel_t>(i);
    ledc_ll_set_duty_int_part(&LEDC,LEDC_LOW_SPEED_MODE,ch,enabled?counts[i]:0);
    ledc_ll_set_duty_start(&LEDC,LEDC_LOW_SPEED_MODE,ch,true);
    ledc_ll_ls_channel_update(&LEDC,LEDC_LOW_SPEED_MODE,ch);
  }
}
}
#endif
extern "C" void official_pwm_setup(void) {
#if defined(ARDUINO_ARCH_ESP32)
  ready=false; actualHz=0;bits=0;status=0;
  for (int pin:pins) {pinMode(pin,OUTPUT);digitalWrite(pin,LOW);}
  ledc_timer_config_t timer{};
  timer.speed_mode=LEDC_LOW_SPEED_MODE;timer.duty_resolution=LEDC_TIMER_8_BIT;
  timer.timer_num=LEDC_TIMER_0;timer.freq_hz=150000;timer.clk_cfg=LEDC_USE_APB_CLK;
  if (ledc_timer_config(&timer)!=ESP_OK) {status=1;return;}
  for (int i=0;i<4;++i) {
    ledc_channel_config_t ch{};
    ch.gpio_num=pins[i];ch.speed_mode=LEDC_LOW_SPEED_MODE;
    ch.channel=static_cast<ledc_channel_t>(i);ch.intr_type=LEDC_INTR_DISABLE;
    ch.timer_sel=LEDC_TIMER_0;ch.duty=0;ch.hpoint=0;
    if (ledc_channel_config(&ch)!=ESP_OK) {
      status=2;
      for(int j=0;j<=i;++j) ledc_stop(LEDC_LOW_SPEED_MODE,static_cast<ledc_channel_t>(j),0);
      return;
    }
    // No fade, duty change only. All runtime writes are bounded register writes.
    ledc_ll_set_fade_param(&LEDC,LEDC_LOW_SPEED_MODE,ch.channel,1,1,0,1);
  }
  actualHz=ledc_get_freq(LEDC_LOW_SPEED_MODE,LEDC_TIMER_0);
  ledc_ll_get_duty_resolution(&LEDC,LEDC_LOW_SPEED_MODE,LEDC_TIMER_0,&bits);
  if(bits!=8 || actualHz<149000 || actualHz>151000) {status=3;official_pwm_stop();return;}
  ready=true;
#endif
}
extern "C" void official_pwm_step(const uint8_t counts[4],uint8_t enabled,
                                    uint8_t applied[4],uint32_t info[4]) {
  memset(applied,0,4);memset(info,0,4*sizeof(uint32_t));
#if defined(ARDUINO_ARCH_ESP32)
  uint32_t start=static_cast<uint32_t>(esp_timer_get_time());
  if(ready) {
    uint8_t limited[4];
    for(int i=0;i<4;++i) limited[i]=counts[i]>242?242:counts[i]; // floor(.95*255)
    writeCounts(limited,enabled!=0);
    if(enabled) memcpy(applied,limited,4);
  }
  info[0]=status;info[1]=actualHz;info[2]=bits;
  info[3]=static_cast<uint32_t>(esp_timer_get_time())-start;
#endif
}
extern "C" void official_pwm_stop(void) {
#if defined(ARDUINO_ARCH_ESP32)
  for(int i=0;i<4;++i) ledc_stop(LEDC_LOW_SPEED_MODE,static_cast<ledc_channel_t>(i),0);
  ready=false;
#endif
}
