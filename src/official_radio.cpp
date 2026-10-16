#include "official_radio.h"
#include "imu_tx.h"
#include <Arduino.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>
#include <math.h>
namespace {
portMUX_TYPE rcLock=portMUX_INITIALIZER_UNLOCKED;
float rcStick[6]={0,0,0,0,0,4};
uint8_t rcArm=0,rcAHRS=0,mac[6]={},peerMac[6]={},channel=3;
uint32_t receivedAt=0,lastDiscovery=0;
uint8_t rcFlip=0,rcError=0;
uint32_t packetEpoch=0,consumedEpoch=0;
uint32_t validPackets=0;
bool received=false,peerReady=false;
bool headerSent=false;
}
extern "C" void official_radio_setup(uint8_t ch) {
  channel=ch;imu_tx_init(ch);esp_wifi_get_mac(WIFI_IF_STA,mac);
  received=false;rcArm=0;lastDiscovery=millis();headerSent=false;
}
extern "C" void official_radio_receive(const uint8_t source[6],const uint8_t* data,int length) {
  // The logger shares this radio. Only valid JoyStick commands may renew the
  // flight link; SFL1/SFP1 packets must never mask JoyStick communication loss.
  portENTER_CRITICAL(&rcLock);++packetEpoch;portEXIT_CRITICAL(&rcLock);
  if(!data || length!=25 || data[0]!=mac[3] || data[1]!=mac[4] || data[2]!=mac[5])return;
  if(peerReady && memcmp(source,peerMac,6)!=0)return;
  portENTER_CRITICAL(&rcLock);rcError=1;portEXIT_CRITICAL(&rcLock);
  uint8_t sum=0;for(int i=0;i<24;++i)sum+=data[i];if(sum!=data[24])return;
  float yaw,throttle,roll,pitch;
  memcpy(&yaw,data+3,4);memcpy(&throttle,data+7,4);memcpy(&roll,data+11,4);memcpy(&pitch,data+15,4);
  if(!isfinite(yaw)||!isfinite(throttle)||!isfinite(roll)||!isfinite(pitch))return;
  portENTER_CRITICAL(&rcLock);
  rcStick[0]=roll;rcStick[1]=pitch;rcStick[2]=yaw;rcStick[3]=throttle;
  rcStick[4]=data[21];rcStick[5]=data[22];rcArm=data[19];rcAHRS=data[23];
  rcFlip=data[20];rcError=0;
  receivedAt=micros();received=true;
  memcpy(peerMac,source,6);
  ++validPackets;
  portEXIT_CRITICAL(&rcLock);
  if(!peerReady) {
    esp_now_peer_info_t peer{};memcpy(peer.peer_addr,source,6);
    peer.channel=channel;peer.ifidx=WIFI_IF_STA;
    peerReady=esp_now_add_peer(&peer)==ESP_OK || esp_now_is_peer_exist(source);
  }
}
extern "C" void official_radio_info(uint32_t info[8],float stick[6]) {
  portENTER_CRITICAL(&rcLock);
  info[0]=packetEpoch;info[1]=validPackets;info[2]=packetEpoch-validPackets;
  info[3]=received?uint32_t(micros()-receivedAt):0xffffffffu;
  info[4]=peerReady;info[5]=rcArm;info[6]=rcAHRS;info[7]=rcFlip;
  memcpy(stick,rcStick,6*sizeof(float));
  portEXIT_CRITICAL(&rcLock);
}
extern "C" void official_radio_events(uint8_t flip[1],uint8_t newPacket[1],uint8_t error[1]) {
  portENTER_CRITICAL(&rcLock);
  flip[0]=rcFlip;error[0]=rcError;newPacket[0]=validPackets!=consumedEpoch;
  consumedEpoch=validPackets;
  portEXIT_CRITICAL(&rcLock);
}
extern "C" void official_radio_basic_events(uint8_t newPacket[1],uint8_t error[1]) {
  portENTER_CRITICAL(&rcLock);
  error[0]=rcError;newPacket[0]=validPackets!=consumedEpoch;
  consumedEpoch=validPackets;
  portEXIT_CRITICAL(&rcLock);
}
extern "C" void official_radio_step(float stick[6],uint8_t arm[1],uint8_t connected[1],uint8_t ahrs[1]) {
  portENTER_CRITICAL(&rcLock);
  memcpy(stick,rcStick,6*sizeof(float));arm[0]=rcArm;ahrs[0]=rcAHRS;
  connected[0]=received && static_cast<uint32_t>(micros()-receivedAt)<100000;
  portEXIT_CRITICAL(&rcLock);
  // Pairing discovery is slow and nonblocking, same 11-byte official message.
  if(!received && millis()-lastDiscovery>500) {
    uint8_t packet[11]={};packet[0]=channel;memcpy(packet+1,mac,6);
    const uint8_t magic[4]={0xaa,0x55,0x16,0x88};memcpy(packet+7,magic,4);
    const uint8_t broadcast[6]={255,255,255,255,255,255};
    imu_tx_radio_queue(broadcast,packet,11);lastDiscovery=millis();
  }
}
extern "C" void official_radio_telemetry(const float values[27],uint8_t altFlag,uint8_t state,uint16_t front) {
  if(!peerReady)return;
  uint8_t frame[120]={};frame[0]=88;frame[1]=88;
  memcpy(frame+2,values,27*sizeof(float));frame[110]=altFlag;frame[111]=state;
  memcpy(frame+112,&front,2);
  imu_tx_radio_queue(peerMac,frame,120);
}
extern "C" uint8_t official_radio_send(const float values[27],const float gains[20],uint8_t altFlag,uint8_t state,uint16_t front) {
  if(!peerReady || state<=1)return 0;
  uint8_t frame[120]={};
  if(!headerSent) {
    frame[0]=99;frame[1]=99;memcpy(frame+2,gains,20*sizeof(float));
    if(!imu_tx_radio_queue(peerMac,frame,120))return 0;headerSent=true;
  }
  frame[0]=88;frame[1]=88;memcpy(frame+2,values,27*sizeof(float));
  frame[110]=altFlag;frame[111]=state;memcpy(frame+112,&front,2);
  return imu_tx_radio_queue(peerMac,frame,120);
}
