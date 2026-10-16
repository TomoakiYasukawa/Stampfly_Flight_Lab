"""Match the pinned official tof_init front setup and Parking read order."""
from pathlib import Path
root=Path(__file__).resolve().parents[3]
p=root/'src/vl53l3cx/vl53l3cx_bottom_official128_wrapper.cpp'
s=p.read_text(encoding='utf-8')
start=s.index('    int front_result=VL53LX_WaitDeviceBooted(official_front);')
end=s.index('    digitalWrite(VL53_XSHUT_BOTTOM,HIGH);delay(100);',start)
s=s[:start]+'''    // Pinned official tof_init: assign address, configure, do not call
    // StartMeasurement on front. The first PARKING read clears/starts it.
    int front_result=VL53LX_SetDeviceAddress(official_front,0x54);
    official_front->i2c_slave_address=0x2a;
    if(!front_result)front_result=VL53LX_WaitDeviceBooted(official_front);
    if(!front_result)front_result=VL53LX_DataInit(official_front);
    if(!front_result)front_result=VL53LX_SetDistanceMode(official_front,VL53LX_DISTANCEMODE_LONG);
    if(!front_result)front_result=VL53LX_SetMeasurementTimingBudgetMicroSeconds(official_front,33000);
    uint16_t ident=0;if(!front_result)front_result=VL53LX_RdWord(official_front,0x10f,&ident);
    official_front_fault=front_result!=0;
    if(front_result){official_status=8;official_front_error=front_result;official_front_error_stage=4;digitalWrite(VL53_XSHUT_FRONT,LOW);}
    Serial.printf("SFTOF_FRONT id=%x setup=%d\\n",ident,front_result);
'''+s[end:]
start=s.index('            uint8_t ready=0;\n',s.index('static void official_tof_worker'))
end=s.index('        }\n        xSemaphoreGive',start)
s=s[:start]+'''            // Official Parking read has no readiness gate on the front.
            uint8_t rangeStatus=255;int r=0;
            front=official_farthest(official_front,&rangeStatus,&r);
            portENTER_CRITICAL(&official_tof_lock);
            if(!r){++official_front_frames;official_front_valid+=(rangeStatus==0);official_front_range_status=rangeStatus;}
            if(r){official_status=9;official_front_fault=true;if(!official_front_error){official_front_error=r;official_front_error_stage=2;}}
            portEXIT_CRITICAL(&official_tof_lock);
            if(r){Wire1.beginTransmission(0x2a);front_ack=Wire1.endTransmission();}
'''+s[end:]
p.write_text(s,encoding='utf-8')
