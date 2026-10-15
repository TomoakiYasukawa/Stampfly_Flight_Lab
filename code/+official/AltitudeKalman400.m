classdef AltitudeKalman400 < matlab.System
    %ALTITUDEKALMAN400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        State=official.kalmanInitial()
        First=false
        PreviousMode=uint8(0)
    end
    methods (Access=protected)
        function [height,velocity,bias]=stepImpl(o,alt,az,mode,dt,parkingReset)
            if parkingReset,[~,o.State]=official.kalmanStep(single(0),single(0),dt,true,o.State);end
            if mode==3 && mode~=o.PreviousMode,o.First=false;end
            if mode>1
                if o.First,[~,o.State]=official.kalmanStep(alt,az,dt,false,o.State);else,o.First=true;end
            end
            velocity=o.State.output(1);height=o.State.output(2);bias=o.State.output(3);o.PreviousMode=mode;
        end
        function resetImpl(o)
            o.State=official.kalmanInitial();o.First=false;o.PreviousMode=uint8(0);
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'alt','az','mode','dt','parkingReset'};end
        function varargout=getOutputNamesImpl(~),varargout={'HeightM','VelocityMps','EstimatedBias'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,3);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,3);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
