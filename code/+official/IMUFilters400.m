classdef IMUFilters400 < matlab.System
    %IMUFILTERS400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        MotionTime=0.003
        VerticalTime=0.1
    end
    properties (Access=private)
        Filter=zeros(7,1,'single')
        Accel=zeros(3,1,'single')
        Gyro=zeros(3,1,'single')
        Azd=single(0)
        PreviousMode=uint8(0)
    end
    methods (Access=protected)
        function [af,gf,azd]=stepImpl(o,a,g,offset,mode,dt)
            if mode==3 && mode~=o.PreviousMode,o.Filter(:)=single(0);end
            if mode>1
                for j=1:3
                    o.Filter(j)=official.filterStep(a(j),dt,single(o.MotionTime),o.Filter(j));
                    o.Filter(j+3)=official.filterStep(g(j)-offset(j),dt,single(o.MotionTime),o.Filter(j+3));
                end
                o.Filter(7)=official.filterStep(a(3)-offset(4),dt,single(o.VerticalTime),o.Filter(7));
                o.Accel=o.Filter(1:3);o.Gyro=o.Filter(4:6);o.Azd=o.Filter(7);
            end
            af=o.Accel;gf=o.Gyro;azd=o.Azd;o.PreviousMode=mode;
        end
        function resetImpl(o)
            o.Filter(:)=single(0);o.Accel(:)=single(0);o.Gyro(:)=single(0);o.Azd=single(0);o.PreviousMode=uint8(0);
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'a','g','offset','mode','dt'};end
        function varargout=getOutputNamesImpl(~),varargout={'FilteredAccelG','FilteredGyroRps','VerticalDeltaG'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[3 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,3);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,3);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
