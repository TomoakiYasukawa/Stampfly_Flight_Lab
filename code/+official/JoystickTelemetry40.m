classdef JoystickTelemetry40 < matlab.System
    %JOYSTICKTELEMETRY40 Official 120-byte return packet, every 10 base ticks.
    methods (Access=protected)
        function sent=stepImpl(~,t,dt,a,r,cd,accel,voltage,duty,z,sd,mode,stick,front,v)
            values=zeros(27,1,'single');
            values(1:2)=[t;dt];values(3:8)=[a;r]*single(180/pi);
            values(9:13)=cd(6:10)*single(180/pi);values(14)=single(double(cd(5))/3.7);
            values(15)=voltage;values(16:18)=accel([2 1 3])/single(9.80665);values(18)=-values(18);
            values(19:20)=[v;cd(4)];values(21:22)=duty(2:3);
            values(23:27)=[cd(1);z;sd(3);sd(1:2)];sent=uint8(0);
            if coder.target('Rtw')
                coder.cinclude('official_radio.h');
                coder.ceval('official_radio_telemetry',coder.rref(values),uint8(stick(6)==4 && mode==2),mode,uint16(max(front,int16(0))));
                sent=uint8(1);
            end
        end
        function n=getNumInputsImpl(~),n=14;end
        function n=getNumOutputsImpl(~),n=1;end
        function s=getOutputSizeImpl(~),s=[1 1];end
        function t=getOutputDataTypeImpl(~),t='uint8';end
        function b=isOutputComplexImpl(~),b=false;end
        function b=isOutputFixedSizeImpl(~),b=true;end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.025);end
    end
end
