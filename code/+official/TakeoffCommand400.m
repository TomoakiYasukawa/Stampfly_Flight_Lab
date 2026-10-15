classdef TakeoffCommand400 < matlab.System
    %TAKEOFFCOMMAND400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        InitialAltitude=0.5
        MinimumAltitude=0.05
        MaximumAltitude=1.8
    end
    properties (Access=private)
        Alt=single(.5)
        Base=single(0)
        Counter=uint16(0)
        RangeOld=uint8(0)
        Landing=false
        History=zeros(10,1,'single')
    end
    methods (Access=protected)
        function [alt,base,counter,raw,auto,manual]=stepImpl(o,stick,height,voltage,rangeFlag,mode)
            raw=single(0);auto=false;manual=false;
            if mode==3
                o.Base=single(0);o.Alt=single(o.InitialAltitude);o.Counter=uint16(0);o.Landing=false;
            elseif mode==2
                if uint8(stick(6))==4
                    auto=true;
                    if o.Counter<uint16(500)
                        o.Base=min(single(o.Counter)/single(1000),trim(single(3.8)));o.Counter=o.Counter+uint16(1);
                    elseif o.Counter<uint16(1000)
                        o.Base=min(single(o.Counter)/single(1000),trim(voltage));o.Counter=o.Counter+uint16(1);
                    else,o.Base=trim(voltage);end
                    th=stick(4);if th>single(-.2) && th<single(.2),th=single(0);end
                    o.Alt=min(max(single(double(o.Alt)+double(th)*.001),single(o.MinimumAltitude)),single(o.MaximumAltitude));
                    if rangeFlag>o.RangeOld || rangeFlag==20,o.Base=o.Base-single(.02);o.RangeOld=rangeFlag;end
                    raw=single(double(o.Base)*3.7);
                else
                    manual=true;th=min(max(stick(4),single(0)),single(1));
                    if th>single(-.2) && th<single(.2),th=single(0);end
                    raw=single((.00413+double(single(3.3)*th-single(5.44)*th*th+single(3.13)*th*th*th))*3.7);
                end
            elseif mode==5
                if ~o.Landing,o.Landing=true;o.History(:)=height;o.Base=trim(voltage);end
                if o.History(10)>=height,o.Base=single(double(o.Base)*.9999);end
                if height<single(.15),o.Base=single(double(o.Base)*.999);end
                for j=2:10,o.History(j)=o.History(j-1);end
                o.History(1)=height;
            end
            alt=o.Alt;base=o.Base;counter=o.Counter;
        end
        function resetImpl(o)
            o.Alt=single(o.InitialAltitude);o.Base=single(0);o.Counter=uint16(0);o.RangeOld=uint8(0);o.Landing=false;o.History(:)=single(0);
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=6;end
        function varargout=getInputNamesImpl(~),varargout={'stick','height','voltage','rangeFlag','mode'};end
        function varargout=getOutputNamesImpl(~),varargout={'AltitudeReferenceM','BaseDuty','TakeoffCounter','RawThrust','AutoAltitude','ManualAltitude'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','uint16','single','boolean','boolean'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,6);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,6);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end

function y=trim(v)
y=-single(.2448)*v+single(1.5892);
end
