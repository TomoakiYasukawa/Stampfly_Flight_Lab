classdef FlightInputs400 < matlab.System
    %FLIGHTINPUTS400 Calibration -> arm -> takeoff -> hover input fixture.
    properties (Access=private)
        Tick=uint32(0)
    end
    methods (Access=protected)
        function [acc,gyro,tof,new,volt,stick,button,connected,ahrs,dt]=stepImpl(o)
            o.Tick=o.Tick+uint32(1);k=o.Tick;
            acc=single([0;0;9.80665]);gyro=zeros(3,1,'single');
            tof=int16(30+min(max(double(k)-1000,0),1000)*.47);
            new=uint8(mod(k,uint32(16))==0);volt=single(3.8);
            stick=single([0;0;0;0;0;4]);button=uint8(k>=900 && k<940);
            connected=uint8(1);ahrs=uint8(0);dt=single(.0025);
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=10;end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[3 1],[1 1],[1 1],[1 1],[6 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,10);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,10);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
    end
end
