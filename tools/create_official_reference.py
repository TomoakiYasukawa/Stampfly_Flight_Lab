"""Build host reference from unchanged active official functions (MIT)."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
src = (root/'official_sources/M5StampFly/src/flight_control.cpp').read_text(encoding='utf-8')
src = re.sub(r'#if 0\b.*?#endif', '', src, flags=re.S)
def function(name):
    m = re.search(r'^(?:void|float|uint8_t) '+name+r'\([^\n]*\)\s*\{', src, re.M)
    if not m:
        raise RuntimeError(name)
    start = m.start(); depth = 0
    for i in range(src.index('{', start), len(src)):
        if src[i] == '{': depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0: return src[start:i+1]
    raise RuntimeError(name)
globals_text=src[src.index('const int pwmFrontLeft'):src.index('// Function declaration')]
names=['control_init','get_trim_duty','get_rate_ref','get_command','auto_landing',
       'rate_control','reset_rate_control','reset_angle_control','angle_control']
prefix='''#include "mex.h"
#include <cmath>
#include <cstdint>
#include "pid.hpp"
#define PI 3.1415926535897932384626433832795
#define BATTERY_VOLTAGE 3.7
#define INIT_MODE 0
#define AVERAGE_MODE 1
#define FLIGHT_MODE 2
#define PARKING_MODE 3
#define AUTO_LANDING_MODE 5
#define FLIP_MODE 6
#define ANGLECONTROL 0
#define RATECONTROL 1
#define AUTO_ALT 4
#define MANUAL_ALT 5
#define ALT_REF_MIN 0.05
#define ALT_REF_MAX 1.8
#define RNAGE0FLAG_MAX 20
#define RATE_RATE 70.0f
#define RATE_MAX 1600.0f
#define RATE_EXPO 0.5f
#define THROTTLE 2
#define AILERON 3
#define ELEVATOR 1
#define RUDDER 0
#define CONTROLMODE 11
#define ALTCONTROLMODE 12
float Stick[16]={},Roll_angle=0,Pitch_angle=0,Yaw_angle=0;
float Roll_rate=0,Pitch_rate=0,Yaw_rate=0,Altitude2=0,Alt_velocity=0,Voltage=3.8f;
uint8_t Range0flag=0,OverG_flag=0;
uint8_t get_flip_button(){return 0;}
void motor_stop(){}
void set_duty_fr(float){} void set_duty_fl(float){}
void set_duty_rr(float){} void set_duty_rl(float){}
'''
declarations='\n'.join('void '+n+'();' for n in ['control_init','get_command','rate_control','reset_rate_control','reset_angle_control','angle_control'])
wrapper='''
void mexFunction(int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]) {
 if(nrhs!=1 || !mxIsSingle(prhs[0]) || mxGetN(prhs[0])!=21)
   mexErrMsgIdAndTxt("official:reference:input","Expected single N x 21 input trace");
 const mwSize n=mxGetM(prhs[0]);const float* u=mxGetSingles(prhs[0]);
 plhs[0]=mxCreateNumericMatrix(n,21,mxSINGLE_CLASS,mxREAL);
 float* y=mxGetSingles(plhs[0]);
 p_pid.reset();q_pid.reset();r_pid.reset();phi_pid.reset();theta_pid.reset();alt_pid.reset();z_dot_pid.reset();
 Thrust_filtered.reset();Duty_fr.reset();Duty_fl.reset();Duty_rr.reset();Duty_rl.reset();
 Alt_ref=.5f;Thrust0=0;Auto_takeoff_counter=0;OladRange0flag=0;Landing_state=0;
 Aileron_center=Elevator_center=Rudder_center=0;Roll_angle_offset=Pitch_angle_offset=0;
 Roll_angle_reference=Pitch_angle_reference=0;Z_dot_ref=0;Thrust_command=0;Flip_flag=0;
 control_init();
 for(mwSize i=0;i<n;++i) {
  Stick[AILERON]=u[i+n*0];Stick[ELEVATOR]=u[i+n*1];Stick[RUDDER]=u[i+n*2];
  Stick[THROTTLE]=u[i+n*3];Stick[CONTROLMODE]=u[i+n*4];Stick[ALTCONTROLMODE]=u[i+n*5];
  Roll_angle=u[i+n*6];Pitch_angle=u[i+n*7];Yaw_angle=u[i+n*8];
  Roll_rate=u[i+n*9];Pitch_rate=u[i+n*10];Yaw_rate=u[i+n*11];
  Altitude2=u[i+n*12];Alt_velocity=u[i+n*13];Voltage=u[i+n*14];
  Range0flag=(uint8_t)u[i+n*15];OverG_flag=(uint8_t)u[i+n*16];Mode=(uint8_t)u[i+n*17];
  Interval_time=u[i+n*18];
  if(Mode==PARKING_MODE) {
   motor_stop();Thrust0=0;Alt_flag=0;Alt_ref=.5f;Auto_takeoff_counter=0;
   Landing_state=0;Thrust_filtered.reset();Duty_fr.reset();Duty_fl.reset();Duty_rr.reset();Duty_rl.reset();
   FrontRight_motor_duty=FrontLeft_motor_duty=RearRight_motor_duty=RearLeft_motor_duty=0;
  } else if(Mode==FLIGHT_MODE || Mode==AUTO_LANDING_MODE) {
   if(Mode==FLIGHT_MODE) get_command();else auto_landing();
   angle_control();rate_control();
  }
  float row[21]={FrontRight_motor_duty,FrontLeft_motor_duty,RearRight_motor_duty,RearLeft_motor_duty,
   Alt_ref,Thrust0,(float)Auto_takeoff_counter,Z_dot_ref,Thrust_command,
   Roll_angle_reference,Pitch_angle_reference,Roll_rate_reference,Pitch_rate_reference,Yaw_rate_reference,
   Roll_rate_command,Pitch_rate_command,Yaw_rate_command,0,0,0,0};
  for(int j=0;j<21;++j) y[i+n*j]=row[j];
 }
}
'''
# Last two reserved inputs allow future calibration/state tracing.
out=root/'tests/reference';out.mkdir(parents=True,exist_ok=True)
(out/'official_controller_reference.cpp').write_text(prefix+globals_text+declarations+'\n'+'\n'.join(function(n) for n in names)+wrapper,encoding='utf-8')
# Compile original PID update/filter with only Arduino print dependency stubbed.
pid=(root/'official_sources/M5StampFly/src/pid.cpp').read_text(encoding='utf-8')
pid=pid.replace('#include "pid.hpp"','#include "pid.hpp"\nstruct SerialStub { template<class... T> void printf(T...){} }; static SerialStub Serial;')
(out/'pid_reference.cpp').write_text(pid,encoding='utf-8')
(out/'Arduino.h').write_text('#pragma once\n#include <stdint.h>\n',encoding='utf-8')
print(out)
