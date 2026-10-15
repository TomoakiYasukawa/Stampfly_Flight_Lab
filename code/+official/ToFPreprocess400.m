classdef ToFPreprocess400 < matlab.System
    %TOFPREPROCESS400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        FilterTime=0.005
        OutlierLimitMm=500
    end
    properties (Access=private)
        History=zeros(4,1,'int16')
        Range=int16(0)
        Raw=int16(0)
        Outlier=uint8(0)
        Alt=single(0)
        PreviousMode=uint8(0)
    end
    methods (Access=protected)
        function [alt,raw]=stepImpl(o,mm,fresh,mode,dt)
            if mode==3 && mode~=o.PreviousMode,o.History(:)=int16(0);o.Alt=single(0);end
            if mode>1
                if fresh~=0
                    o.Raw=mm;if mm>int16(20),o.Range=mm;end
                    delta=int32(o.Range)-int32(o.History(2));
                    if abs(delta)>int32(o.OutlierLimitMm) && o.Outlier<uint8(2)
                        extrap=int32(o.History(2))+idivide(int32(o.History(2))-int32(o.History(4)),int32(2),'fix');
                        o.Range=int16(extrap);o.Outlier=o.Outlier+uint8(1);
                    else
                        o.Outlier=uint8(0);o.History(4)=o.History(3);o.History(3)=o.History(2);o.History(2)=o.Range;
                    end
                end
                o.Alt=official.filterStep(single(double(o.Range)/1000),dt,single(o.FilterTime),o.Alt);
            end
            alt=o.Alt;raw=o.Raw;o.PreviousMode=mode;
        end
        function resetImpl(o)
            o.History(:)=int16(0);o.Range=int16(0);o.Raw=int16(0);o.Outlier=uint8(0);o.Alt=single(0);o.PreviousMode=uint8(0);
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=2;end
        function varargout=getInputNamesImpl(~),varargout={'mm','fresh','mode','dt'};end
        function varargout=getOutputNamesImpl(~),varargout={'FilteredRangeM','LatestRawMm'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','int16'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,2);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,2);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
