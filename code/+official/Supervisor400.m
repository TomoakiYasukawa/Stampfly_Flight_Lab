classdef Supervisor400 < matlab.System
    %SUPERVISOR400 Official calibration/arming/flight supervisor.
    properties (Access=private)
        State=official.supervisorInitial()
    end
    methods (Access=protected)
        function [branch,mode,ahrs,parking,alt]=stepImpl(o,button,connected,flags,height,ahrsFlag,stick)
            [branch,mode,ahrs,parking,o.State]=official.supervisorStep(button,connected,flags(1),height,ahrsFlag,o.State);
            alt=uint8(branch==2 && uint8(stick(6))==4);
        end
        function resetImpl(o),o.State=official.supervisorInitial();end
        function n=getNumInputsImpl(~),n=6;end
        function n=getNumOutputsImpl(~),n=5;end
        function varargout=getOutputSizeImpl(~),varargout=repmat({[1 1]},1,5);end
        function varargout=getOutputDataTypeImpl(~),varargout={'uint8','uint8','boolean','boolean','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,5);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,5);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
    end
end
