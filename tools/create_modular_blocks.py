"""Create small, independently configurable System blocks for the official port."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
dest = root / 'code' / '+official'

def block(name, inputs, outputs, body, private='', reset='', public=''):
    # Outputs are (MATLAB variable, human-readable port name, size, type).
    outvars = ','.join(x[0] for x in outputs)
    sizes = ','.join('[' + x[2] + ']' for x in outputs)
    types = ','.join("'" + x[3] + "'" for x in outputs)
    names = ','.join("'" + x[1] + "'" for x in outputs)
    inputnames = ','.join("'" + x + "'" for x in inputs.split(','))
    private_text = ('    properties (Access=private)\n' + private + '\n    end\n') if private else ''
    reset_text = ('        function resetImpl(o)\n' + reset + '\n        end\n') if reset else ''
    text = f'''classdef {name} < matlab.System
    %{name.upper()} One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
{public}    end
{private_text}    methods (Access=protected)
        function [{outvars}]=stepImpl(o,{inputs})
{body}
        end
{reset_text}        function n=getNumInputsImpl(~),n={len(inputs.split(','))};end
        function n=getNumOutputsImpl(~),n={len(outputs)};end
        function varargout=getInputNamesImpl(~),varargout={{{inputnames}}};end
        function varargout=getOutputNamesImpl(~),varargout={{{names}}};end
        function varargout=getOutputSizeImpl(~),varargout={{{sizes}}};end
        function varargout=getOutputDataTypeImpl(~),varargout={{{types}}};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({{false}},1,{len(outputs)});end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({{true}},1,{len(outputs)});end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
'''
    (dest / f'{name}.m').write_text(text, encoding='utf-8')

def out(var, name=None, size='1 1', dtype='single'):
    return (var, name or var, size, dtype)

block('IMUAxes400','accelMps2,gyroRps', [out('a','BodyAccelG','3 1'),out('g','BodyGyroRps','3 1')], '''            a=accelMps2([2 1 3])/single(9.80665);a(3)=-a(3);
            g=gyroRps([2 1 3]);g(3)=-g(3);''')
block('IMUCalibration400','a,g,mode', [out('offset','GyroXYZAccelZBias','4 1'),out('count','CalibrationSamples',dtype='uint16')], '''            if mode==0,o.Offset(:)=single(0);o.Count=uint16(0);
            elseif mode==1 && o.Count<uint16(800)
                n=single(o.Count);o.Offset=(n*o.Offset+[g;a(3)])/(n+single(1));o.Count=o.Count+uint16(1);
            end
            offset=o.Offset;count=o.Count;''',
'''        Offset=zeros(4,1,'single')
        Count=uint16(0)''', '''            o.Offset=zeros(4,1,'single');o.Count=uint16(0);''')
block('IMUFilters400','a,g,offset,mode,dt', [out('af','FilteredAccelG','3 1'),out('gf','FilteredGyroRps','3 1'),out('azd','VerticalDeltaG')], '''            if mode==3 && mode~=o.PreviousMode,o.Filter(:)=single(0);end
            if mode>1
                for j=1:3
                    o.Filter(j)=official.filterStep(a(j),dt,single(o.MotionTime),o.Filter(j));
                    o.Filter(j+3)=official.filterStep(g(j)-offset(j),dt,single(o.MotionTime),o.Filter(j+3));
                end
                o.Filter(7)=official.filterStep(a(3)-offset(4),dt,single(o.VerticalTime),o.Filter(7));
                o.Accel=o.Filter(1:3);o.Gyro=o.Filter(4:6);o.Azd=o.Filter(7);
            end
            af=o.Accel;gf=o.Gyro;azd=o.Azd;o.PreviousMode=mode;''',
'''        Filter=zeros(7,1,'single')
        Accel=zeros(3,1,'single')
        Gyro=zeros(3,1,'single')
        Azd=single(0)
        PreviousMode=uint8(0)''', '''            o.Filter(:)=single(0);o.Accel(:)=single(0);o.Gyro(:)=single(0);o.Azd=single(0);o.PreviousMode=uint8(0);''', '''        MotionTime=0.003
        VerticalTime=0.1
''')
block('Madgwick400','rates,accel,mode,reset', [out('a','RollPitchYawRad','3 1'),out('q','QuaternionWXYZ','4 1')], '''            if reset,o.Q=single([1;0;0;0]);end
            if mode>1,[o.Angles,o.Q]=official.madgwickStep(rates,accel,o.Q,false);end
            a=o.Angles;q=o.Q;''', '''        Q=single([1;0;0;0])
        Angles=zeros(3,1,'single')''', '''            o.Q=single([1;0;0;0]);o.Angles=zeros(3,1,'single');''')
block('VerticalAccel400','azd,mode,dt', [out('az','OfficialVerticalAccelG')], '''            if mode==3 && mode~=o.PreviousMode,o.Az=single(0);end
            if mode>1,o.Az=official.filterStep(-azd,dt,single(o.FilterTime),o.Az);end
            az=o.Az;o.PreviousMode=mode;''', '''        Az=single(0)
        PreviousMode=uint8(0)''', '''            o.Az=single(0);o.PreviousMode=uint8(0);''', '''        FilterTime=0.1
''')
block('ToFPreprocess400','mm,fresh,mode,dt', [out('alt','FilteredRangeM'),out('raw','LatestRawMm',dtype='int16')], '''            if mode==3 && mode~=o.PreviousMode,o.History(:)=int16(0);o.Alt=single(0);end
            if mode>1
                if fresh~=0
                    o.Raw=mm;if mm>int16(20),o.Range=mm;end
                    delta=int32(o.Range)-int32(o.History(2));
                    if abs(delta)>int32(o.OutlierLimitMm) && o.Outlier<uint8(2)
                        extrap=int32(o.History(2))+idivide(int32(o.History(2))-int32(o.History(4)),int32(2),'fix');
                        o.Range=int16(extrap);o.Outlier=o.Outlier+uint8(1);
                    else
                        o.Outlier=uint8(0);o.History(4)=o.History(3);o.History(3)=o.History(2);o.History(2)=o.Range;
                    end
                end
                o.Alt=official.filterStep(single(double(o.Range)/1000),dt,single(o.FilterTime),o.Alt);
            end
            alt=o.Alt;raw=o.Raw;o.PreviousMode=mode;''', '''        History=zeros(4,1,'int16')
        Range=int16(0)
        Raw=int16(0)
        Outlier=uint8(0)
        Alt=single(0)
        PreviousMode=uint8(0)''', '''            o.History(:)=int16(0);o.Range=int16(0);o.Raw=int16(0);o.Outlier=uint8(0);o.Alt=single(0);o.PreviousMode=uint8(0);''', '''        FilterTime=0.005
        OutlierLimitMm=500
''')
block('AltitudeKalman400','alt,az,mode,dt,parkingReset', [out('height','HeightM'),out('velocity','VelocityMps'),out('bias','EstimatedBias')], '''            if parkingReset,[~,o.State]=official.kalmanStep(single(0),single(0),dt,true,o.State);end
            if mode==3 && mode~=o.PreviousMode,o.First=false;end
            if mode>1
                if o.First,[~,o.State]=official.kalmanStep(alt,az,dt,false,o.State);else,o.First=true;end
            end
            velocity=o.State.output(1);height=o.State.output(2);bias=o.State.output(3);o.PreviousMode=mode;''',
'''        State=official.kalmanInitial()
        First=false
        PreviousMode=uint8(0)''', '''            o.State=official.kalmanInitial();o.First=false;o.PreviousMode=uint8(0);''')
block('SensorFlags400','accel,azd,voltage,mode,altFlag,velocity,rawRange,dt,parkingReset', [out('flags','OverGRangeLowVoltage','3 1','uint8')], '''            if parkingReset,o.OverG=uint8(0);o.RangeFlag=uint8(0);end
            if mode==3 && mode~=o.PreviousMode,o.Norm=single(0);end
            if mode>1
                if (velocity>single(2) && altFlag~=0) || rawRange==0,o.RangeFlag=min(o.RangeFlag+uint8(1),uint8(20));else,o.RangeFlag=uint8(0);end
            end
            normA=sqrt(accel(1)*accel(1)+accel(2)*accel(2)+azd*azd);
            o.Norm=official.filterStep(normA,dt,single(.005),o.Norm);
            if o.Norm>single(2),o.OverG=uint8(1);end
            o.Voltage=official.filterStep(voltage,dt,single(.005),o.Voltage);
            if o.LowVoltage~=uint8(100)
                if o.Voltage<single(3.34),o.LowVoltage=o.LowVoltage+uint8(1);else,o.LowVoltage=uint8(0);end
                o.LowVoltage=min(o.LowVoltage,uint8(100));
            end
            flags=[o.OverG;o.RangeFlag;o.LowVoltage];o.PreviousMode=mode;''',
'''        Norm=single(0)
        Voltage=single(0)
        OverG=uint8(0)
        RangeFlag=uint8(0)
        LowVoltage=uint8(0)
        PreviousMode=uint8(0)''', '''            o.Norm=single(0);o.Voltage=single(0);o.OverG=uint8(0);o.RangeFlag=uint8(0);o.LowVoltage=uint8(0);o.PreviousMode=uint8(0);''')
block('SensorDiagnostics400','az,bias,alt,offset,count', [out('diag','SensorDiagnostics8','8 1')], '''            diag=[az;bias;alt;offset;single(count)];''')

block('TakeoffCommand400','stick,height,voltage,rangeFlag,mode',
 [out('alt','AltitudeReferenceM'),out('base','BaseDuty'),out('counter','TakeoffCounter',dtype='uint16'),out('raw','RawThrust'),out('auto','AutoAltitude',dtype='boolean'),out('manual','ManualAltitude',dtype='boolean')], '''            raw=single(0);auto=false;manual=false;
            if mode==3
                o.Base=single(0);o.Alt=single(o.InitialAltitude);o.Counter=uint16(0);o.Landing=false;
            elseif mode==2
                if uint8(stick(6))==4
                    auto=true;
                    if o.Counter<uint16(500)
                        o.Base=min(single(o.Counter)/single(1000),trim(single(3.8)));o.Counter=o.Counter+uint16(1);
                    elseif o.Counter<uint16(1000)
                        o.Base=min(single(o.Counter)/single(1000),trim(voltage));o.Counter=o.Counter+uint16(1);
                    else,o.Base=trim(voltage);end
                    th=stick(4);if th>single(-.2) && th<single(.2),th=single(0);end
                    o.Alt=min(max(single(double(o.Alt)+double(th)*.001),single(o.MinimumAltitude)),single(o.MaximumAltitude));
                    if rangeFlag>o.RangeOld || rangeFlag==20,o.Base=o.Base-single(.02);o.RangeOld=rangeFlag;end
                    raw=single(double(o.Base)*3.7);
                else
                    manual=true;th=min(max(stick(4),single(0)),single(1));
                    if th>single(-.2) && th<single(.2),th=single(0);end
                    raw=single((.00413+double(single(3.3)*th-single(5.44)*th*th+single(3.13)*th*th*th))*3.7);
                end
            elseif mode==5
                if ~o.Landing,o.Landing=true;o.History(:)=height;o.Base=trim(voltage);end
                if o.History(10)>=height,o.Base=single(double(o.Base)*.9999);end
                if height<single(.15),o.Base=single(double(o.Base)*.999);end
                for j=2:10,o.History(j)=o.History(j-1);end
                o.History(1)=height;
            end
            alt=o.Alt;base=o.Base;counter=o.Counter;''',
'''        Alt=single(.5)
        Base=single(0)
        Counter=uint16(0)
        RangeOld=uint8(0)
        Landing=false
        History=zeros(10,1,'single')''',
'''            o.Alt=single(o.InitialAltitude);o.Base=single(0);o.Counter=uint16(0);o.RangeOld=uint8(0);o.Landing=false;o.History(:)=single(0);''',
'''        InitialAltitude=0.5
        MinimumAltitude=0.05
        MaximumAltitude=1.8
''')
with (dest/'TakeoffCommand400.m').open('a',encoding='utf-8') as stream:
    stream.write("\nfunction y=trim(v)\ny=-single(.2448)*v+single(1.5892);\nend\n")

block('ControlGates400','raw,manual,auto,mode,controlMode,dt,oldFilter,lastThrust',
 [out('command','CommandThrust'),out('run','RunControl',dtype='boolean'),out('reset','ResetPID',dtype='boolean'),out('altEnable','EnableAltitudePID',dtype='boolean'),out('angleEnable','EnableAnglePID',dtype='boolean'),out('velEnable','EnableVelocityPID',dtype='boolean')],
'''            command=raw;
            if manual,command=official.filterStep(raw,dt,single(.01),oldFilter);end
            if mode==5 || mode==3,command=lastThrust;end
            active=mode==2 || mode==5;reset=active && double(command)/3.7<double(single(.1));run=active && ~reset;
            altEnable=run && auto;angleEnable=run && uint8(controlMode)==0;velEnable=run && (auto || mode==5);''')
block('StickTargets400','stick,mode,run,reset',
 [out('angle','AngleReferenceRad','2 1'),out('directRate','DirectRateRadps','3 1'),out('resetError','ResetPreviousAngle','2 1')],
'''            angleCmd=min(max(single(.4*double(stick(1:2))),single(-1)),single(1));yawCmd=min(max(stick(3),single(-1)),single(1));
            resetError=o.Angle;directRate=zeros(3,1,'single');
            if reset,o.Centers(1:2)=angleCmd;o.Centers(3)=yawCmd;end
            if run
                directRate(3)=single(2*pi*double(yawCmd-o.Centers(3)));
                if uint8(stick(5))==1,directRate(1)=rateCommand(stick(1));directRate(2)=rateCommand(stick(2));end
                if uint8(stick(5))==0
                    limit=single(o.AngleLimitDeg*pi/180);o.Angle=min(max(single(.5*pi*double(angleCmd-o.Centers(1:2))),-limit),limit);
                end
            end
            angle=o.Angle;
            if mode<2,directRate(:)=single(0);end''',
'''        Angle=zeros(2,1,'single')
        Centers=zeros(3,1,'single')''', '''            o.Angle(:)=single(0);o.Centers(:)=single(0);''', '''        AngleLimitDeg=30
''')
with (dest/'StickTargets400.m').open('a',encoding='utf-8') as stream:
    stream.write('''
function y=rateCommand(x)
x=min(max(x,single(-1)),single(1));a=abs(x);t=a*(a*a*a*a*a*single(.5)+a*single(.5));
y=single(pi/180)*((single(1600)-single(70))*t+single(70)*a);if x<0,y=-y;end
end
''')
block('PID400','error,dt,enable,reset,previousError', [out('y','PIDOutput')],
'''            if reset,o.State=single([0;0;previousError]);end
            if enable
                [o.Output,o.State]=official.pidStep(error,dt,single([o.Kp o.Ti o.Td o.Eta]),o.State);
            end
            if enable || o.HoldOutputWhenDisabled,y=o.Output;else,y=single(0);end''',
'''        State=zeros(3,1,'single')
        Output=single(0)''', '''            o.State=zeros(3,1,'single');o.Output=single(0);''',
'''        Kp=5
        Ti=4
        Td=0.04
        Eta=0.125
        HoldOutputWhenDisabled=false
''')
block('RateReference400','direct,rollPID,pitchPID,angleEnable', [out('rate','RateReferenceRadps','3 1')], '''            rate=direct;if angleEnable,rate(1)=rollPID;rate(2)=pitchPID;end''')
block('VelocityReference400','zRef,mode', [out('vRef','VerticalSpeedReference')], '''            vRef=zRef;if mode==5,vRef=single(-.15);end''')
block('ThrustFinalize400','command,correction,base,auto,manual,velEnable,mode,dt,oldFilter,lastThrust',
 [out('thrust','FinalThrust'),out('filter','NextFilterState'),out('last','NextHeldThrust')],
'''            thrust=command;filter=oldFilter;
            if mode==3,filter=single(0);
            elseif manual,filter=command;end
            if velEnable
                filter=official.filterStep(single(double(base+correction)*3.7),dt,single(.01),oldFilter);thrust=filter;
                if auto
                    if double(thrust)/3.7>double(single(base*single(1.15))),thrust=single(3.7*double(base)*double(single(1.15)));end
                    if double(thrust)/3.7<double(single(base*single(.85))),thrust=single(3.7*double(base)*double(single(.85)));end
                end
            end
            if mode==3,thrust=lastThrust;last=lastThrust;else,last=thrust;end''')
block('MotorMixer400','thrust,rollTorque,pitchTorque,yawTorque,run,reset,overG,mode,dt',
 [out('duty','DutyFRFLRRRL','4 1'),out('counts','CountsFRFLRRRL','4 1','uint8'),out('before','MixerBeforeLimit','4 1')],
'''            duty=zeros(4,1,'single');counts=zeros(4,1,'uint8');before=zeros(4,1,'single');
            if mode==3 || reset,o.Filter(:)=single(0);end
            if run
                torque=[rollTorque;pitchTorque;yawTorque];mix=single([-1 1 1;1 1 -1;-1 -1 -1;1 -1 1]);
                for j=1:4
                    combination=mix(j,1)*torque(1)+mix(j,2)*torque(2)+mix(j,3)*torque(3);
                    before(j)=single(double(thrust+combination*single(.25))/3.7);
                    o.Filter(j)=official.filterStep(before(j),dt,single(o.FilterTime),o.Filter(j));
                end
                duty=min(max(o.Filter,single(0)),single(o.MaximumDuty));if overG~=0,duty(:)=single(0);end
                counts=uint8(floor(single(255)*duty));
            end''', '''        Filter=zeros(4,1,'single')''', '''            o.Filter(:)=single(0);''', '''        FilterTime=0.003
        MaximumDuty=0.95
''')
block('ControlDiagnostics400','alt,base,counter,zRef,thrust,angle,rate,rollTorque,pitchTorque,yawTorque,before',
 [out('diag','ControlDiagnostics17','17 1')], '''            diag=[alt;base;single(counter);zRef;thrust;angle;rate;rollTorque;pitchTorque;yawTorque;before];''')
print('Created', len(list(dest.glob('*400.m'))), '400 Hz System classes')
