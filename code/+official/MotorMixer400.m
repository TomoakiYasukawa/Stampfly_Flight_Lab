classdef MotorMixer400 < matlab.System
    %MOTORMIXER400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        FilterTime=0.003
        MaximumDuty=0.95
    end
    properties (Access=private)
        Filter=zeros(4,1,'single')
    end
    methods (Access=protected)
        function [duty,counts,before]=stepImpl(o,thrust,rollTorque,pitchTorque,yawTorque,run,reset,overG,mode,dt)
            duty=zeros(4,1,'single');counts=zeros(4,1,'uint8');before=zeros(4,1,'single');
            if mode==3 || reset,o.Filter(:)=single(0);end
            if run
                torque=[rollTorque;pitchTorque;yawTorque];mix=single([-1 1 1;1 1 -1;-1 -1 -1;1 -1 1]);
                for j=1:4
                    combination=mix(j,1)*torque(1)+mix(j,2)*torque(2)+mix(j,3)*torque(3);
                    before(j)=single(double(thrust+combination*single(.25))/3.7);
                    o.Filter(j)=official.filterStep(before(j),dt,single(o.FilterTime),o.Filter(j));
                end
                duty=min(max(o.Filter,single(0)),single(o.MaximumDuty));if overG~=0,duty(:)=single(0);end
                counts=uint8(floor(single(255)*duty));
            end
        end
        function resetImpl(o)
            o.Filter(:)=single(0);
        end
        function n=getNumInputsImpl(~),n=9;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'thrust','rollTorque','pitchTorque','yawTorque','run','reset','overG','mode','dt'};end
        function varargout=getOutputNamesImpl(~),varargout={'DutyFRFLRRRL','CountsFRFLRRRL','MixerBeforeLimit'};end
        function varargout=getOutputSizeImpl(~),varargout={[4 1],[4 1],[4 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,3);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,3);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
