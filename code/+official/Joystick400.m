classdef Joystick400 < matlab.System & coder.ExternalDependency
    %JOYSTICK400 Receive official 25-byte JoyStick packets on the logger radio.
    properties (Nontunable)
        SampleTime=.0025
        Channel=uint8(3)
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='Official Atom JoyStick receiver';end
        function updateBuildInfo(b,c)
            imu.ESPNowIMUTx.updateBuildInfo(b,c);
            if ~c.isCodeGenTarget('rtw'),return;end
            src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            b.addSourceFiles('official_radio.cpp',src);
        end
    end
    methods (Access=protected)
        function setupImpl(o)
            if coder.target('Rtw'),coder.cinclude('official_radio.h');coder.ceval('official_radio_setup',o.Channel);end
        end
        function [s,b,c,a,f,p,e]=stepImpl(~)
            s=single([0;0;0;0;0;4]);b=uint8(0);c=uint8(0);a=uint8(0);
            f=uint8(0);p=uint8(0);e=uint8(0);
            if coder.target('Rtw')
                coder.cinclude('official_radio.h');coder.ceval('official_radio_step',coder.wref(s),coder.wref(b),coder.wref(c),coder.wref(a));
                coder.ceval('official_radio_events',coder.wref(f),coder.wref(p),coder.wref(e));
            end
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=7;end
        function varargout=getOutputNamesImpl(~),varargout={'Stick6','Arm','Connected','AHRSFlag','FlipButton','NewPacket','PacketError'};end
        function varargout=getOutputSizeImpl(~),varargout={[6 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8','uint8','uint8','uint8','uint8','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,7);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,7);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
