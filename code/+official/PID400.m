classdef PID400 < matlab.System
    %PID400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        Kp=5
        Ti=4
        Td=0.04
        Eta=0.125
        HoldOutputWhenDisabled=false
    end
    properties (Access=private)
        State=zeros(3,1,'single')
        Output=single(0)
    end
    methods (Access=protected)
        function [y]=stepImpl(o,error,dt,enable,reset,previousError)
            if reset,o.State=single([0;0;previousError]);end
            if enable
                [o.Output,o.State]=official.pidStep(error,dt,single([o.Kp o.Ti o.Td o.Eta]),o.State);
            end
            if enable || o.HoldOutputWhenDisabled,y=o.Output;else,y=single(0);end
        end
        function resetImpl(o)
            o.State=zeros(3,1,'single');o.Output=single(0);
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'error','dt','enable','reset','previousError'};end
        function varargout=getOutputNamesImpl(~),varargout={'PIDOutput'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
