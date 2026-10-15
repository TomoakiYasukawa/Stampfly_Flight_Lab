// Hardware-only status backend. Colors, tones and button decisions are model inputs.
#include "official_status.h"
#include <Arduino.h>
#include <driver/ledc.h>
#include <esp32-hal-rmt.h>
#include <freertos/queue.h>
#include <freertos/task.h>
namespace {
struct Status {uint32_t c1,c2,hz;uint8_t restart;};
QueueHandle_t queue=nullptr;
rmt_data_t symbols[49];
void worker(void*) {
 Status s{},previous{0xffffffff,0xffffffff,0xffffffff,0};
 for(;;) {
  if(xQueueReceive(queue,&s,portMAX_DELAY)!=pdTRUE)continue;
  if(s.restart){ledc_stop(LEDC_LOW_SPEED_MODE,LEDC_CHANNEL_4,0);esp_restart();}
  if(s.hz!=previous.hz) {
   if(s.hz) {ledc_set_freq(LEDC_LOW_SPEED_MODE,LEDC_TIMER_1,s.hz);ledc_set_duty(LEDC_LOW_SPEED_MODE,LEDC_CHANNEL_4,127);}
   else ledc_set_duty(LEDC_LOW_SPEED_MODE,LEDC_CHANNEL_4,0);
   ledc_update_duty(LEDC_LOW_SPEED_MODE,LEDC_CHANNEL_4);
  }
  if(s.c1!=previous.c1 || s.c2!=previous.c2) {
   uint32_t colors[2]={s.c1,s.c2};
   for(int pixel=0;pixel<2;pixel++) {
    uint32_t c=colors[pixel];uint8_t grb[3]={uint8_t(c>>8),uint8_t(c>>16),uint8_t(c)};
    for(int byte=0;byte<3;byte++)for(int bit=0;bit<8;bit++) {
     bool one=(grb[byte]&(0x80>>bit))!=0;rmt_data_t& d=symbols[pixel*24+byte*8+bit];
     d.level0=1;d.duration0=one?8:4;d.level1=0;d.duration1=one?4:8;
    }
   }
   symbols[48].val=0;symbols[48].duration0=1000;symbols[48].duration1=1;
   // Blocking peripheral transmission occurs only in this core0 worker.
   rmtWrite(39,symbols,49,10);
  }
  previous=s;
 }
}
}
extern "C" void official_status_setup(void) {
 pinMode(0,INPUT_PULLUP);rmtInit(39,RMT_TX_MODE,RMT_MEM_NUM_BLOCKS_1,10000000);
 ledc_timer_config_t timer{};timer.speed_mode=LEDC_LOW_SPEED_MODE;timer.timer_num=LEDC_TIMER_1;
 timer.duty_resolution=LEDC_TIMER_8_BIT;timer.freq_hz=4000;timer.clk_cfg=LEDC_USE_APB_CLK;
 ledc_timer_config(&timer);
 ledc_channel_config_t ch{};ch.gpio_num=40;ch.speed_mode=LEDC_LOW_SPEED_MODE;ch.channel=LEDC_CHANNEL_4;ch.timer_sel=LEDC_TIMER_1;ch.duty=0;
 ledc_channel_config(&ch);queue=xQueueCreate(1,sizeof(Status));
 if(queue)xTaskCreatePinnedToCore(worker,"SFStatus",3072,nullptr,1,nullptr,0);
}
extern "C" uint8_t official_user_button(void){return digitalRead(0)==LOW;}
extern "C" void official_status_write(uint32_t c1,uint32_t c2,uint32_t hz,uint8_t restart){
 Status s{c1,c2,hz,restart};if(queue)xQueueOverwrite(queue,&s);
}
