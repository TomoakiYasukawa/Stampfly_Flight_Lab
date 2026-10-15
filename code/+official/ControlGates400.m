classdef ControlGates400 < matlab.System
    %CONTROLGATES400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Access=protected)
        function [command,run,reset,altEnable,angleEnable,velEnable]=stepImpl(o,raw,manual,auto,mode,controlMode,dt,oldFilter,lastThrust)
            command=raw;
            if manual,command=official.filterStep(raw,dt,single(.01),oldFilter);end
            if mode==5 || mode==3,command=lastThrust;end
            active=mode==2 || mode==5;reset=active && double(command)/3.7<double(single(.1));run=active && ~reset;
            altEnable=run && auto;angleEnable=run && uint8(controlMode)==0;velEnable=run && (auto || mode==5);
        end
        function n=getNumInputsImpl(~),n=8;end
        function n=getNumOutputsImpl(~),n=6;end
        function varargout=getInputNamesImpl(~),varargout={'raw','manual','auto','mode','controlMode','dt','oldFilter','lastThrust'};end
        function varargout=getOutputNamesImpl(~),varargout={'CommandThrust','RunControl','ResetPID','EnableAltitudePID','EnableAnglePID','EnableVelocityPID'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','boolean','boolean','boolean','boolean','boolean'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,6);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,6);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
