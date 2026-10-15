classdef VelocityReference400 < matlab.System
    %VELOCITYREFERENCE400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [vRef]=stepImpl(o,zRef,mode)
            vRef=zRef;if mode==5,vRef=single(-.15);end
        end
        function n=getNumInputsImpl(~),n=2;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'zRef','mode'};end
        function varargout=getOutputNamesImpl(~),varargout={'VerticalSpeedReference'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
