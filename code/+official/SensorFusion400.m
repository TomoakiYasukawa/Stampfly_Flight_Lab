classdef SensorFusion400 < matlab.System
    %SENSORFUSION400 Official calibration, Madgwick and held-ToF Kalman.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        State=official.sensorInitial()
    end
    methods (Access=protected)
        function [a,r,z,v,f,q,d]=stepImpl(o,accel,gyro,tof,newToF,voltage,mode,altFlag,h,ahrsReset,parkingReset)
            % Unit delays deliver the preceding tick's post-control resets.
            % Apply them before sensor_read: equivalent to committing them at
            % the end of that preceding tick, without an algebraic loop.
            if ahrsReset,o.State.q=single([1;0;0;0]);end
            if parkingReset
                [~,o.State.kalman]=official.kalmanStep(single(0),single(0),h,true,o.State.kalman);
                o.State.overG=uint8(0);o.State.rangeFlag=uint8(0);
            end
            [a,r,z,v,f,q,d,o.State]=official.sensorStep(accel,gyro,tof,newToF,voltage,mode,altFlag,h,o.State);
        end
        function resetImpl(o),o.State=official.sensorInitial();end
        function n=getNumInputsImpl(~),n=10;end
        function n=getNumOutputsImpl(~),n=7;end
        function varargout=getInputNamesImpl(~)
            varargout={'AccelMps2','GyroRps','ToFmm','ToFNew','Voltage','PreviousMode','AltFlag','Dt','AHRSReset','ParkingReset'};
        end
        function varargout=getOutputNamesImpl(~),varargout={'Attitude3','Rates3','Altitude','Velocity','Flags3','Quaternion4','Diagnostics8'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[3 1],[1 1],[1 1],[3 1],[4 1],[8 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single','single','uint8','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true,true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
