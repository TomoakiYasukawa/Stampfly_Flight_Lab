classdef RateReference400 < matlab.System
    %RATEREFERENCE400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [rate]=stepImpl(o,direct,rollPID,pitchPID,angleEnable)
            rate=direct;if angleEnable,rate(1)=rollPID;rate(2)=pitchPID;end
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'direct','rollPID','pitchPID','angleEnable'};end
        function varargout=getOutputNamesImpl(~),varargout={'RateReferenceRadps'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
