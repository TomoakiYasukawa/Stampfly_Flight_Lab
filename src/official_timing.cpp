#include "official_timing.h"
#include "official_scheduler.h"
#include "official_usb.h"
#include "official_tof.h"
#include "official_radio.h"
#if defined(ARDUINO_ARCH_ESP32)
#include <Arduino.h>
#endif
extern "C" void official_timing_end(uint32_t start,uint8_t fresh,const uint8_t applied[4],const uint32_t pwm[4],uint32_t result[8]) {
  static uint32_t last=0,count=0,freshCount=0,total=0,maxExec=0,maxGap=0,over=0;
  uint32_t elapsed=official_now_us()-start;
  uint32_t gap=last?start-last:2500;last=start;
  ++count;freshCount+=(fresh!=0);total+=elapsed;
  if(elapsed>maxExec)maxExec=elapsed;if(gap>maxGap)maxGap=gap;
  if(elapsed>2500)++over;
  uint32_t v[8]={elapsed,gap,count,freshCount,total/count,maxExec,maxGap,over};
  for(int i=0;i<8;++i)result[i]=v[i];
#if defined(ARDUINO_ARCH_ESP32)
  if(count==400) {
    uint32_t runtime[7];official_runtime_info(runtime);
    uint32_t sched[4];official_scheduler_info(sched);
    // One short line per second; SFI frames on USB share a framed byte stream.
    char line[256];int length=snprintf(line,sizeof(line),"SFTIMING n=%lu fresh=%lu mean_us=%lu max_us=%lu max_gap_us=%lu over=%lu missed=%lu hz=%lu bits=%lu pwm_us=%lu applied=%u,%u,%u,%u\n",count,freshCount,total/count,maxExec,maxGap,over,sched[1],pwm[1],pwm[2],pwm[3],applied[0],applied[1],applied[2],applied[3]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length>255?255:length);
    length=snprintf(line,sizeof(line),"SFRUNTIME reset_reason=%lu idle0_age_us=%lu idle1_age_us=%lu stack_min_bytes=%lu heap_bytes=%lu core=%lu idle_hook_status=%lu\n",runtime[0],runtime[1],runtime[2],runtime[3],runtime[4],runtime[5],runtime[6]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length>255?255:length);
    length=snprintf(line,sizeof(line),"SFPROFILE logger_max_us=%lu flow_motion_max_us=%lu horizontal_log_max_us=%lu\n",official_profile_max(0),official_profile_max(1),official_profile_max(2));
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    uint32_t front[6];official_front_info(front);
    length=snprintf(line,sizeof(line),"SFFRONT enabled=0 frames=%lu valid=%lu mm=%lu status=%lu ready=%lu fault=%lu\n",front[0],front[1],front[2],front[3],front[4],front[5]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    int32_t bottom[10];official_bottom_info(bottom);
    length=snprintf(line,sizeof(line),"SFBOTTOM frames=%ld valid=%ld errors=%ld mm=%ld raw_mm=%ld status=%ld objects=%ld stream=%ld error=%ld ready=%ld\n",bottom[0],bottom[1],bottom[2],bottom[3],bottom[4],bottom[5],bottom[6],bottom[7],bottom[8],bottom[9]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    uint32_t rc[8];float stick[6];official_radio_info(rc,stick);
    length=snprintf(line,sizeof(line),"SFRC packets=%lu valid=%lu rejected=%lu age_us=%lu peer=%lu arm=%lu ahrs=%lu flip=%lu stick=%.3f,%.3f,%.3f,%.3f,%.0f,%.0f\n",rc[0],rc[1],rc[2],rc[3],rc[4],rc[5],rc[6],rc[7],stick[0],stick[1],stick[2],stick[3],stick[4],stick[5]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length>255?255:length);
    int32_t debug[5];official_tof_debug(debug);
    length=snprintf(line,sizeof(line),"SFTOFSTATE error=%ld stage=%ld status=%ld warm=%ld bottom_ready=%ld\n",debug[0],debug[1],debug[2],debug[3],debug[4]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    uint32_t bus[4];official_tof_bus_info(bus);
    length=snprintf(line,sizeof(line),"SFTOFBUS addr=%lu reg=%lu code=%lu front_ack=%lu\n",bus[0],bus[1],bus[2],bus[3]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    count=freshCount=total=maxExec=maxGap=over=0;
  }
#endif
}
