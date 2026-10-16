"""Reduce redundant packet CRC work and remove temporary ToF probes."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[3]
names = ['packTelemetryFrame', 'packAttitudeFrame', 'packHeightFrame',
         'packMotorFrame', 'packFlightFrame', 'packFlightDiagnosticsFrame',
         'packFlightTuningFrame']
legacy = root/'archive'/'logger_packers'/'+legacyframe'
legacy.mkdir(parents=True, exist_ok=True)
for name in names:
    path = root/'code/+imu'/f'{name}.m'
    original = path.read_text(encoding='utf-8')
    if 'skipCRC' in original:
        continue
    (legacy/f'{name}.m').write_text(original.replace('imu.pack', 'legacyframe.pack'), encoding='utf-8')
    close = original.index(')')
    text = original[:close]+',skipCRC'+original[close:]
    newline = text.index('\n', close)
    text = text[:newline+1]+f'if nargin < {original[:close].count(",")+2},skipCRC=false;end\n'+text[newline+1:]
    # Each enclosing format copies only the payload, discarding the inner CRC.
    text = re.sub(r'(base = imu\.pack[\s\S]*?)(\);)', r'\1,true\2', text, count=1)
    text = re.sub(r'^(frame\(\d+:\d+\) = .*imu\.crc16.*;)$', r'if ~skipCRC\n    \1\nend', text, flags=re.M)
    path.write_text(text, encoding='utf-8')
path = root/'code/+official'/'LoggerPacker50.m'
text = path.read_text(encoding='utf-8').replace('uint16(0),uint8(0));', 'uint16(0),uint8(0),true);')
path.write_text(text, encoding='utf-8')

path = root/'src'/'vl53l3cx'/'vl53l3cx_uld_wrapper.cpp'
text = path.read_text(encoding='utf-8')
text = re.sub(r'class AssignedFront[\s\S]*?static AssignedFront s_front;',
              'static VL53LX s_front(&Wire1, VL53_XSHUT_FRONT);', text)
text = re.sub(r'/\* Separate C ABI[\s\S]*?(?=extern "C" void vl53l3cx_bringup)', '', text)
path.write_text(text, encoding='utf-8')

path = root/'src'/'vl53l3cx'/'vl53l3cx_bottom_official128_wrapper.cpp'
text = path.read_text(encoding='utf-8')
text = re.sub(r'struct FrontTrace[^\n]*\nstatic FrontTrace[^\n]*\nstatic uint8_t front_trace_count[^\n]*\n', '', text)
text = re.sub(r'    // FULL ULD[\s\S]*?(?=    Wire1.beginTransmission\(address\);)', '', text)
text = re.sub(r'    if\(address==42[\s\S]*?    return result==0u\?0:-1;', '    return result==0u?0:-1;', text)
text = re.sub(r'        static bool readReported[\s\S]*?        return -1;', '        return -1;', text)
text = text.replace('static bool official_front_running=false;\n', '')
text = re.sub(r'extern "C" int official_front_uld_[^\n]*\n', '', text)
text = text.replace('    delay(3000); // Diagnostic capture window before sensor initialization.\n', '')
text = text.replace('official_front_running=false;', '')
text = text.replace('    official_front_running=front_result==0;\n', '')
text = re.sub(r'    for\(uint8_t i=0;i<front_trace_count;[^\n]*\n', '', text)
text = text.replace('SFTOF_MEDIUM', 'SFTOF_FRONT')
text = text.replace('    if(front_result){official_status=8;return;}',
    '    if(front_result){official_status=8;digitalWrite(VL53_XSHUT_FRONT,LOW);}')
text = text.replace('    s_ready=official_status==0;', '    s_ready=warm==10; // A front-sensor fault must not stop the bottom sensor.')
text = text.replace('static bool official_front_fault=false;',
    'static bool official_front_fault=false;\nstatic uint32_t official_front_frames=0,official_front_valid=0;\nstatic uint8_t official_front_ready=0,official_front_range_status=255;')
text = text.replace('static int16_t official_farthest(VL53LX_DEV dev) {',
    'static int16_t official_farthest(VL53LX_DEV dev,uint8_t* rangeStatus=nullptr,int* error=nullptr) {')
text = text.replace('    int16_t farthest=0;\n', '    int16_t farthest=0;\n    if(rangeStatus)*rangeStatus=255;\n', 1)
text = text.replace('        for(uint8_t i=0;i<data.NumberOfObjectsFound;++i) {',
    '        if(rangeStatus && data.NumberOfObjectsFound)*rangeStatus=data.RangeData[0].RangeStatus;\n        for(uint8_t i=0;i<data.NumberOfObjectsFound;++i) {', 1)
text = text.replace('                farthest=data.RangeData[i].RangeMilliMeter;',
    '                {farthest=data.RangeData[i].RangeMilliMeter;if(rangeStatus)*rangeStatus=0;}', 1)
text = re.sub(r'    static bool reported=false;[\s\S]*?    return farthest;',
    '    if(error)*error=read_result?read_result:restart_result;\n    return farthest;', text, count=1)
text = text.replace('            if(r==0 && ready)front=official_farthest(official_front);\n            if(r){official_status=9;official_front_fault=true;}',
    '''            uint8_t rangeStatus=255;
            if(r==0 && ready)front=official_farthest(official_front,&rangeStatus,&r);
            portENTER_CRITICAL(&official_tof_lock);
            official_front_ready=ready;
            if(!r && ready){++official_front_frames;official_front_valid+=(rangeStatus==0);official_front_range_status=rangeStatus;}
            if(r){official_status=9;official_front_fault=true;}
            portEXIT_CRITICAL(&official_tof_lock);''')
text = text.replace('extern "C" uint8_t official_i2c_try_lock(void) {',
    '''extern "C" void official_front_info(uint32_t info[6]) {
    portENTER_CRITICAL(&official_tof_lock);
    info[0]=official_front_frames;info[1]=official_front_valid;
    info[2]=uint32_t(official_front_mm);info[3]=official_front_range_status;
    info[4]=official_front_ready;info[5]=official_front_fault;
    portEXIT_CRITICAL(&official_tof_lock);
}
extern "C" uint8_t official_i2c_try_lock(void) {''')
text = text.replace('extern "C" void official_tof_setup(void) {}',
    'extern "C" void official_front_info(uint32_t info[6]) {for(int i=0;i<6;++i)info[i]=0;}\nextern "C" void official_tof_setup(void) {}')
path.write_text(text, encoding='utf-8')
path=root/'src'/'official_tof.h'
text=path.read_text(encoding='utf-8').replace('void official_tof_info(uint32_t info[4]);',
    'void official_tof_info(uint32_t info[4]);\n/* Completed front frames, valid frames, mm, range status, ready, fault. */\nvoid official_front_info(uint32_t info[6]);')
path.write_text(text, encoding='utf-8')
path=root/'src'/'official_timing.cpp'
text=path.read_text(encoding='utf-8').replace('#include "official_usb.h"', '#include "official_usb.h"\n#include "official_tof.h"')
text=text.replace('    count=freshCount=total=maxExec=maxGap=over=0;',
    '''    uint32_t front[6];official_front_info(front);
    length=snprintf(line,sizeof(line),"SFFRONT frames=%lu valid=%lu mm=%lu status=%lu ready=%lu fault=%lu\\n",front[0],front[1],front[2],front[3],front[4],front[5]);
    official_usb_bytes(reinterpret_cast<const uint8_t*>(line),length);
    count=freshCount=total=maxExec=maxGap=over=0;''')
path.write_text(text, encoding='utf-8')
print('Runtime edits applied; packet originals archived for independent comparison.')
