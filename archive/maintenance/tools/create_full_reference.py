"""Host oracle: unchanged official mode dispatch, buttons, Flip and controllers."""
from pathlib import Path
import re
import create_official_reference as base

root=base.root
names=base.names+['flip','judge_mode_change','get_arming_button','get_flip_button']
prefix=base.prefix.replace('uint8_t get_flip_button(){return 0;}','')
prefix=prefix.replace('void motor_stop(){}','float applied[4]={};void motor_stop(){for(int i=0;i<4;i++)applied[i]=0;}')
prefix=prefix.replace('void set_duty_fr(float){} void set_duty_fl(float){}','void set_duty_fr(float x){applied[0]=x;} void set_duty_fl(float x){applied[1]=x;}')
prefix=prefix.replace('void set_duty_rr(float){} void set_duty_rl(float){}','void set_duty_rr(float x){applied[2]=x;} void set_duty_rl(float x){applied[3]=x;}')
prefix += '''
#define BUTTON_ARM 4
#define BUTTON_FLIP 5
#define FLIPCOLOR 0xFF9933
#define AVERAGENUM 800
uint16_t Connect_flag=0;
uint32_t Led_color=0;
uint8_t ahrs_resets=0;
uint8_t rc_isconnected(){Connect_flag++;return Connect_flag<40;}
void ahrs_reset(){ahrs_resets++;}
void sensor_reset_offset(){}
void sensor_calc_offset_avarage(){}
struct ResetStub{void reset(){}};ResetStub EstimatedAltitude;
void buzzer_sound(uint32_t,uint32_t){}
void telemetry(){}
uint32_t micros(){return 0;}
'''
# Keep the exact official if/else body; omit waiting, IO acquisition, and time IO.
loop=base.function('loop_400Hz')
dispatch=loop[loop.index('    if (Mode == INIT_MODE)'):loop.index('    //// Telemetry')]
declarations='\n'.join(f'{"uint8_t" if n in ["auto_landing","judge_mode_change","get_arming_button","get_flip_button"] else "float" if n in ["get_trim_duty","get_rate_ref"] else "void"} {n}({"float" if n in ["get_trim_duty","get_rate_ref"] else ""});' for n in names)
wrapper='''
void dispatch_step(){
DISPATCH
 OldMode=Mode;
}
void mexFunction(int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]){
 if(nrhs!=1 || !mxIsSingle(prhs[0]) || mxGetN(prhs[0])!=23)
 mexErrMsgIdAndTxt("official:full:input","Expected single N x 23 trace");
 mwSize n=mxGetM(prhs[0]);const float* u=mxGetSingles(prhs[0]);
 plhs[0]=mxCreateNumericMatrix(n,27,mxSINGLE_CLASS,mxREAL);float* y=mxGetSingles(plhs[0]);
 control_init();
 for(mwSize i=0;i<n;i++){
  Stick[AILERON]=u[i+n*0];Stick[ELEVATOR]=u[i+n*1];Stick[RUDDER]=u[i+n*2];
  Stick[THROTTLE]=u[i+n*3];Stick[CONTROLMODE]=u[i+n*4];Stick[ALTCONTROLMODE]=u[i+n*5];
  Roll_angle=u[i+n*6];Pitch_angle=u[i+n*7];Yaw_angle=u[i+n*8];
  Roll_rate=u[i+n*9];Pitch_rate=u[i+n*10];Yaw_rate=u[i+n*11];
  Altitude2=u[i+n*12];Alt_velocity=u[i+n*13];Voltage=u[i+n*14];
  Range0flag=(uint8_t)u[i+n*15];OverG_flag=(uint8_t)u[i+n*16];
  Interval_time=u[i+n*18];Stick[BUTTON_ARM]=u[i+n*19];Stick[BUTTON_FLIP]=u[i+n*20];
  if(u[i+n*21])Connect_flag=0;ahrs_reset_flag=(uint8_t)u[i+n*22];
  uint8_t branch=Mode;ahrs_resets=0;dispatch_step();
  float row[27]={applied[0],applied[1],applied[2],applied[3],
   Alt_ref,Thrust0,(float)Auto_takeoff_counter,Z_dot_ref,Thrust_command,
   Roll_angle_reference,Pitch_angle_reference,Roll_rate_reference,Pitch_rate_reference,Yaw_rate_reference,
   Roll_rate_command,Pitch_rate_command,Yaw_rate_command,(float)Mode,(float)Alt_flag,(float)Flip_flag,
   (float)Flip_counter,(float)branch,(float)ahrs_resets,Roll_angle_command,Pitch_angle_command,
   (float)Control_mode,(float)Connect_flag};
  for(int j=0;j<27;j++)y[i+n*j]=row[j];
 }
}
'''.replace('DISPATCH',dispatch)
(root/'tests/reference/official_full_reference.cpp').write_text(prefix+base.globals_text+declarations+'\n'+'\n'.join(base.function(n) for n in names)+wrapper,encoding='utf-8')
print('Created official_full_reference.cpp from unchanged official functions')
