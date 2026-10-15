classdef IMUAxes400 < matlab.System
    %IMUAXES400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [a,g]=stepImpl(o,accelMps2,gyroRps)
            a=accelMps2([2 1 3])/single(9.80665);a(3)=-a(3);
            g=gyroRps([2 1 3]);g(3)=-g(3);
        end
        function n=getNumInputsImpl(~),n=2;end
        function n=getNumOutputsImpl(~),n=2;end
        function varargout=getInputNamesImpl(~),varargout={'accelMps2','gyroRps'};end
        function varargout=getOutputNamesImpl(~),varargout={'BodyAccelG','BodyGyroRps'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[3 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,2);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,2);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
