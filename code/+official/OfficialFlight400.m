classdef OfficialFlight400 < matlab.System
    %OFFICIALFLIGHT400 Preserve sensor -> supervisor -> controller -> resets.
    % All algorithms are MATLAB code-generation functions, not embedded C calls.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        SensorState=official.sensorInitial()
        ControlState=official.controllerInitial()
        SupervisorState=official.supervisorInitial()
        AltFlag=uint8(0)
    end
    methods (Access=protected)
        function [duty,counts,mode,a,r,z,v,q,flags,controlDiag,sensorDiag,previousMode]=stepImpl(o,accel,gyro,tof,tofNew,voltage,stick,button,connected,ahrsFlag,dt)
            previousMode=o.SupervisorState.mode;
            [a,r,z,v,flags,q,sensorDiag,o.SensorState]=official.sensorStep(accel,gyro,tof,tofNew,voltage,previousMode,o.AltFlag,dt,o.SensorState);
            [branch,mode,ahrsReset,parkingReset,o.SupervisorState]=official.supervisorStep(button,connected,flags(1),z,ahrsFlag,o.SupervisorState);
            [duty,counts,controlDiag,o.ControlState]=official.controllerStep(stick,a,r,z,v,voltage,flags(2),flags(1),branch,dt,o.ControlState);
            o.AltFlag=uint8(branch==2 && uint8(stick(6))==4);
            if parkingReset
                [~,o.SensorState.kalman]=official.kalmanStep(single(0),single(0),dt,true,o.SensorState.kalman);
                o.SensorState.overG=uint8(0);o.SensorState.rangeFlag=uint8(0);
                o.AltFlag=uint8(0);
            end
            if ahrsReset,o.SensorState.q=single([1;0;0;0]);end
        end
        function resetImpl(o)
            o.SensorState=official.sensorInitial();o.ControlState=official.controllerInitial();
            o.SupervisorState=official.supervisorInitial();o.AltFlag=uint8(0);
        end
        function n=getNumInputsImpl(~),n=10;end
        function n=getNumOutputsImpl(~),n=12;end
        function varargout=getInputNamesImpl(~)
            varargout={'AccelMps2','GyroRps','ToFmm','ToFNew','VoltageV','Stick6','ArmButton','RCConnected','AHRSFlag','Dt'};
        end
        function varargout=getOutputNamesImpl(~)
            varargout={'Duty4','Counts4','Mode','Attitude3','Rates3','Altitude','Velocity','Quaternion4','Flags3','ControlDiag17','SensorDiag8','ModeBeforeTick'};
        end
        function varargout=getOutputSizeImpl(~)
            varargout={[4 1],[4 1],[1 1],[3 1],[3 1],[1 1],[1 1],[4 1],[3 1],[17 1],[8 1],[1 1]};
        end
        function varargout=getOutputDataTypeImpl(~)
            varargout={'single','uint8','uint8','single','single','single','single','single','uint8','single','single','uint8'};
        end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,12);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,12);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
