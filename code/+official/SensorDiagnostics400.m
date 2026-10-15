classdef SensorDiagnostics400 < matlab.System
    %SENSORDIAGNOSTICS400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [diag]=stepImpl(o,az,bias,alt,offset,count)
            diag=[az;bias;alt;offset;single(count)];
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'az','bias','alt','offset','count'};end
        function varargout=getOutputNamesImpl(~),varargout={'SensorDiagnostics8'};end
        function varargout=getOutputSizeImpl(~),varargout={[8 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,1);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,1);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
