classdef FlightController400 < matlab.System
    %FLIGHTCONTROLLER400 Deployable exact official takeoff/hover controller.
    % Explicit mode input allows state supervision and independent replay.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        State=official.controllerInitial()
    end
    methods (Access=protected)
        function [d,c,v]=stepImpl(o,stick,attitude,rates,height,velocity,voltage,rangeFlag,overG,mode,h)
            [d,c,v,o.State]=official.controllerStep(stick,attitude,rates,height,velocity,voltage,rangeFlag,overG,mode,h,o.State);
        end
        function resetImpl(o),o.State=official.controllerInitial();end
        function n=getNumInputsImpl(~),n=10;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~)
            varargout={'Stick6','Attitude3','Rates3','Height','Velocity','Voltage','RangeFlag','OverG','Mode','Dt'};
        end
        function varargout=getOutputNamesImpl(~),varargout={'DutyFRFLRRRL','CountsFRFLRRRL','Diagnostics17'};end
        function varargout=getOutputSizeImpl(~),varargout={[4 1],[4 1],[17 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8','single'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
