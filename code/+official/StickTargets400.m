classdef StickTargets400 < matlab.System
    %STICKTARGETS400 One reusable function in the 400 Hz official controller.
    properties (Nontunable)
        SampleTime=0.0025
        AngleLimitDeg=30
    end
    properties (Access=private)
        Angle=zeros(2,1,'single')
        Centers=zeros(3,1,'single')
    end
    methods (Access=protected)
        function [angle,directRate,resetError]=stepImpl(o,stick,mode,run,reset)
            angleCmd=min(max(single(.4*double(stick(1:2))),single(-1)),single(1));yawCmd=min(max(stick(3),single(-1)),single(1));
            resetError=o.Angle;directRate=zeros(3,1,'single');
            if reset,o.Centers(1:2)=angleCmd;o.Centers(3)=yawCmd;end
            if run
                directRate(3)=single(2*pi*double(yawCmd-o.Centers(3)));
                if uint8(stick(5))==1,directRate(1)=rateCommand(stick(1));directRate(2)=rateCommand(stick(2));end
                if uint8(stick(5))==0
                    limit=single(o.AngleLimitDeg*pi/180);o.Angle=min(max(single(.5*pi*double(angleCmd-o.Centers(1:2))),-limit),limit);
                end
            end
            angle=o.Angle;
            if mode<2,directRate(:)=single(0);end
        end
        function resetImpl(o)
            o.Angle(:)=single(0);o.Centers(:)=single(0);
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'stick','mode','run','reset'};end
        function varargout=getOutputNamesImpl(~),varargout={'AngleReferenceRad','DirectRateRadps','ResetPreviousAngle'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[3 1],[2 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,3);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,3);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end

function y=rateCommand(x)
x=min(max(x,single(-1)),single(1));a=abs(x);t=a*(a*a*a*a*a*single(.5)+a*single(.5));
y=single(pi/180)*((single(1600)-single(70))*t+single(70)*a);if x<0,y=-y;end
end
