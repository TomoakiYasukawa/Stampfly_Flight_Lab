classdef LoggerPacker50 < matlab.System
    %LOGGERPACKER50 Reuse SFI8 packet and MAT logger; absent fields stay NaN.
    % The original UI's PI tuning is disabled for this official PID reproduction.
    properties (Access=private)
        Sequence=uint16(0)
        LastToFCount=uint32(0)
    end
    methods (Access=protected)
        function frame=stepImpl(o,accel,gyro,imuFresh,t,tof,tofNew,tofStatus,voltage,batteryValid,duty,mode,attitude,z,v,cd,sd,tofInfo)
            profileStart=uint32(0);
            if coder.target('Rtw'),coder.cinclude('official_scheduler.h');profileStart=coder.ceval('official_now_us');end
            tofNew=uint8(tofInfo(1)~=o.LastToFCount);
            o.LastToFCount=tofInfo(1);
            % Display the controller body angles, preserving official yaw offset.
            q=official.eulerQuaternion(attitude);
            diag=nan(32,1,'single');
            diag(1:10)=[voltage;single(batteryValid);single(tofNew);cd(1);cd(1)-z;cd(4);v;v;cd(4)-v;cd(2)];
            diag(11:13)=single(tofInfo(1:3));
            diag(14)=single(double(cd(5))/3.7)-cd(2);
            diag(15:18)=[single(double(cd(5))/3.7);single(double(cd(5))/3.7);single(mode==2);single(any(duty>=single(.95)))];
            diag(19:22)=cd(14:17);diag(24)=cd(1);diag(25)=single(.15);
            % Remaining sibling PI-specific gain fields are unavailable.
            nan2=nan(2,1,'single');nan3=nan(3,1,'single');
            frame=imu.packFlightTuningFrame(o.Sequence,t,accel,gyro,imuFresh, ...
                single(tof)/single(1000),uint8(tof>0 && tofStatus==0),tofStatus, ...
                nan2,uint8(0),uint8(0),uint16(0),nan2,uint8(0),nan3,uint8(0), ...
                q,uint8(mode>1),z,uint8(mode>1),nan2,duty,uint8(0), ...
                mode,uint16(0),diag,uint32(1401),single([0;0]),uint16(0),uint8(0),true);
            % Keep computed counts even with MotorValid=false (physical output
            % disabled). The copied generic packer otherwise discards them.
            frame(105:108)=uint8(floor(single(255)*duty));
            frame(189:190)=reshape(typecast(imu.crc16(frame(1:188)),'uint8'),2,1);
            o.Sequence=uint16(bitand(uint32(o.Sequence)+1,uint32(65535)));
            if isempty(sd),frame(1)=uint8(0);end
            if coder.target('Rtw'),coder.ceval('official_profile_record',uint8(0),profileStart);end
        end
        function n=getNumInputsImpl(~),n=17;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~)
            varargout={'Accel3','Gyro3','Fresh','Time','ToFmm','ToFNew','ToFStatus','Voltage','BatteryValid','ComputedDuty4','OfficialMode','BodyAttitude3','Height','Velocity','ControlDiag17','SensorDiag8','ToFInfo4'};
        end
        function name=getOutputNamesImpl(~),name='SFI8Frame190';end
        function s=getOutputSizeImpl(~),s=[190 1];end
        function t=getOutputDataTypeImpl(~),t='uint8';end
        function c=isOutputComplexImpl(~),c=false;end
        function f=isOutputFixedSizeImpl(~),f=true;end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.02);end
    end
end
