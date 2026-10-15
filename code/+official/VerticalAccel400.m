classdef VerticalAccel400 < matlab.System
    %VERTICALACCEL400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        FilterTime=0.1
    end
    properties (Access=private)
        Az=single(0)
        PreviousMode=uint8(0)
    end
    methods (Access=protected)
        function [az]=stepImpl(o,azd,mode,dt)
            if mode==3 && mode~=o.PreviousMode,o.Az=single(0);end
            if mode>1,o.Az=official.filterStep(-azd,dt,single(o.FilterTime),o.Az);end
            az=o.Az;o.PreviousMode=mode;
        end
        function resetImpl(o)
            o.Az=single(0);o.PreviousMode=uint8(0);
        end
        function n=getNumInputsImpl(~),n=3;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'azd','mode','dt'};end
        function varargout=getOutputNamesImpl(~),varargout={'OfficialVerticalAccelG'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
