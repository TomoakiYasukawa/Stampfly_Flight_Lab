classdef ControlDiagnostics400 < matlab.System
    %CONTROLDIAGNOSTICS400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [diag]=stepImpl(o,alt,base,counter,zRef,thrust,angle,rate,rollTorque,pitchTorque,yawTorque,before)
            diag=[alt;base;single(counter);zRef;thrust;angle;rate;rollTorque;pitchTorque;yawTorque;before];
        end
        function n=getNumInputsImpl(~),n=11;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'alt','base','counter','zRef','thrust','angle','rate','rollTorque','pitchTorque','yawTorque','before'};end
        function varargout=getOutputNamesImpl(~),varargout={'ControlDiagnostics17'};end
        function varargout=getOutputSizeImpl(~),varargout={[17 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
