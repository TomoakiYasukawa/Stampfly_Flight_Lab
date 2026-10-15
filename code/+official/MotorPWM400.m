classdef MotorPWM400 < matlab.System & coder.ExternalDependency
    %MOTORPWM400 Four bounded LEDC writes per 400 Hz tick, 150 kHz / 8 bit.
    % Exclusive timer0/channels0..3; input and output order FR FL RR RL.
    % AllowMotorOutput=false is a compile-time USB-bench interlock.
    properties (Nontunable)
        SampleTime = 0.0025
        AllowMotorOutput = false
    end
    methods (Static)
        function name=getDescriptiveName(), name='Official StampFly PWM 400 Hz'; end
        function tf=isSupportedContext(~), tf=true; end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'), return; end
            src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            b.addIncludePaths(src); b.addSourcePaths(src);
            b.addSourceFiles('official_pwm.cpp',src);
        end
    end
    methods (Access=protected)
        function setupImpl(~)
            if coder.target('Rtw')
                coder.cinclude('official_pwm.h');coder.ceval('official_pwm_setup');
            end
        end
        function [applied,info]=stepImpl(o,counts,enable)
            applied=zeros(4,1,'uint8');info=zeros(4,1,'uint32');
            if coder.target('Rtw')
                coder.cinclude('official_pwm.h');
                coder.ceval('official_pwm_step',coder.rref(counts), ...
                    uint8(enable && o.AllowMotorOutput),coder.wref(applied),coder.wref(info));
            end
        end
        function releaseImpl(~)
            if coder.target('Rtw'), coder.ceval('official_pwm_stop'); end
        end
        function n=getNumInputsImpl(~),n=2;end
        function n=getNumOutputsImpl(~),n=2;end
        function varargout=getInputNamesImpl(~),varargout={'CountsFRFLRRRL','Enable'};end
        function varargout=getOutputNamesImpl(~),varargout={'AppliedCounts','StatusHzBitsUs'};end
        function varargout=getOutputSizeImpl(~),varargout={[4 1],[4 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'uint8','uint32'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true};end
        function st=getSampleTimeImpl(o)
            st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);
        end
    end
end
