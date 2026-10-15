classdef SensorFlags400 < matlab.System
    %SENSORFLAGS400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        Norm=single(0)
        Voltage=single(0)
        OverG=uint8(0)
        RangeFlag=uint8(0)
        LowVoltage=uint8(0)
        PreviousMode=uint8(0)
    end
    methods (Access=protected)
        function [flags]=stepImpl(o,accel,azd,voltage,mode,altFlag,velocity,rawRange,dt,parkingReset)
            if parkingReset,o.OverG=uint8(0);o.RangeFlag=uint8(0);end
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
            flags=[o.OverG;o.RangeFlag;o.LowVoltage];o.PreviousMode=mode;
        end
        function resetImpl(o)
            o.Norm=single(0);o.Voltage=single(0);o.OverG=uint8(0);o.RangeFlag=uint8(0);o.LowVoltage=uint8(0);o.PreviousMode=uint8(0);
        end
        function n=getNumInputsImpl(~),n=9;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'accel','azd','voltage','mode','altFlag','velocity','rawRange','dt','parkingReset'};end
        function varargout=getOutputNamesImpl(~),varargout={'OverGRangeLowVoltage'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'uint8'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
