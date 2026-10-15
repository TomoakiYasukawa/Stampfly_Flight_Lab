#include "official_radio.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
uint32_t testTimeUs=1000000;
extern "C" void imu_tx_init(uint8_t){}
extern "C" uint8_t imu_tx_radio_queue(const uint8_t[6],const uint8_t*,uint16_t){return 1;}
void checksum(uint8_t packet[25]){
 uint8_t sum=0;for(int i=0;i<24;++i)sum+=packet[i];packet[24]=sum;
}
int main(){
 official_radio_setup(3);
 uint8_t joystick[6]={0x48,0xca,0x43,0xb6,0x5b,0x30};
 uint8_t logger[6]={1,2,3,4,5,6};
 uint8_t packet[25]={0xdf,0xa6,0xc4};checksum(packet);
 uint8_t flip,event,error,arm,alive,ahrs;float stick[6];
 official_radio_receive(joystick,packet,25);
 official_radio_events(&flip,&event,&error);assert(event==1 && error==0);
 official_radio_events(&flip,&event,&error);assert(event==0);
 // Logger traffic must not renew link events, even while RC is stale.
 testTimeUs+=150000;
 uint8_t loggerPacket[7]={'S','F','L','1',0,0,0};
 official_radio_receive(logger,loggerPacket,7);
 official_radio_events(&flip,&event,&error);assert(event==0);
 official_radio_step(stick,&arm,&alive,&ahrs);assert(alive==0);
 // Bad checksum and a command from a different sender cannot renew it.
 packet[24]^=1;official_radio_receive(joystick,packet,25);
 official_radio_events(&flip,&event,&error);assert(event==0 && error==1);
 checksum(packet);official_radio_receive(logger,packet,25);
 official_radio_events(&flip,&event,&error);assert(event==0);
 // The configured joystick recovers and a real command is delivered.
 packet[19]=1;checksum(packet);official_radio_receive(joystick,packet,25);
 official_radio_events(&flip,&event,&error);assert(event==1 && error==0);
 official_radio_step(stick,&arm,&alive,&ahrs);assert(alive==1 && arm==1);
 puts("PASS: valid RC, malformed RC, logger isolation, stale link, sender lock, recovery");
}
