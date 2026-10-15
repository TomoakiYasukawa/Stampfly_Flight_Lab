classdef IMUCalibration400 < matlab.System
    %IMUCALIBRATION400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        Offset=zeros(4,1,'single')
        Count=uint16(0)
    end
    methods (Access=protected)
        function [offset,count]=stepImpl(o,a,g,mode)
            if mode==0,o.Offset(:)=single(0);o.Count=uint16(0);
            elseif mode==1 && o.Count<uint16(800)
                n=single(o.Count);o.Offset=(n*o.Offset+[g;a(3)])/(n+single(1));o.Count=o.Count+uint16(1);
            end
            offset=o.Offset;count=o.Count;
        end
        function resetImpl(o)
            o.Offset=zeros(4,1,'single');o.Count=uint16(0);
        end
        function n=getNumInputsImpl(~),n=3;end
        function n=getNumOutputsImpl(~),n=2;end
        function varargout=getInputNamesImpl(~),varargout={'a','g','mode'};end
        function varargout=getOutputNamesImpl(~),varargout={'GyroXYZAccelZBias','CalibrationSamples'};end
        function varargout=getOutputSizeImpl(~),varargout={[4 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint16'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,2);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,2);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
