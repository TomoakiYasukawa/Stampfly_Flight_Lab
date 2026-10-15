classdef ThrustFinalize400 < matlab.System
    %THRUSTFINALIZE400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [thrust,filter,last]=stepImpl(o,command,correction,base,auto,manual,velEnable,mode,dt,oldFilter,lastThrust)
            thrust=command;filter=oldFilter;
            if mode==3,filter=single(0);
            elseif manual,filter=command;end
            if velEnable
                filter=official.filterStep(single(double(base+correction)*3.7),dt,single(.01),oldFilter);thrust=filter;
                if auto
                    if double(thrust)/3.7>double(single(base*single(1.15))),thrust=single(3.7*double(base)*double(single(1.15)));end
                    if double(thrust)/3.7<double(single(base*single(.85))),thrust=single(3.7*double(base)*double(single(.85)));end
                end
            end
            if mode==3,thrust=lastThrust;last=lastThrust;else,last=thrust;end
        end
        function n=getNumInputsImpl(~),n=10;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'command','correction','base','auto','manual','velEnable','mode','dt','oldFilter','lastThrust'};end
        function varargout=getOutputNamesImpl(~),varargout={'FinalThrust','NextFilterState','NextHeldThrust'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,3);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,3);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
