classdef Madgwick400 < matlab.System
    %MADGWICK400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        Q=single([1;0;0;0])
        Angles=zeros(3,1,'single')
    end
    methods (Access=protected)
        function [a,q]=stepImpl(o,rates,accel,mode,reset)
            if reset,o.Q=single([1;0;0;0]);end
            if mode>1,[o.Angles,o.Q]=official.madgwickStep(rates,accel,o.Q,false);end
            a=o.Angles;q=o.Q;
        end
        function resetImpl(o)
            o.Q=single([1;0;0;0]);o.Angles=zeros(3,1,'single');
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=2;end
        function varargout=getInputNamesImpl(~),varargout={'rates','accel','mode','reset'};end
        function varargout=getOutputNamesImpl(~),varargout={'RollPitchYawRad','QuaternionWXYZ'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[4 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,2);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,2);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
