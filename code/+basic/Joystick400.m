classdef Joystick400 < matlab.System & coder.ExternalDependency
    %JOYSTICK400 Receive normal-flight commands; ignore the reserved button.
    properties (Nontunable)
        SampleTime=.0025
        Channel=uint8(3)
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='StampFly basic JoyStick receiver';end
        function updateBuildInfo(b,c),official.Joystick400.updateBuildInfo(b,c);end
    end
    methods (Access=protected)
        function setupImpl(o)
            if coder.target('Rtw'),coder.cinclude('official_radio.h');coder.ceval('official_radio_setup',o.Channel);end
        end
        function [s,b,c,a,p,e]=stepImpl(~)
            s=single([0;0;0;0;0;4]);b=uint8(0);c=uint8(0);a=uint8(0);p=uint8(0);e=uint8(0);
            if coder.target('Rtw')
                coder.cinclude('official_radio.h');
                coder.ceval('official_radio_step',coder.wref(s),coder.wref(b),coder.wref(c),coder.wref(a));
                coder.ceval('official_radio_basic_events',coder.wref(p),coder.wref(e));
            end
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=6;end
        function varargout=getOutputNamesImpl(~),varargout={'Stick6','Arm','Connected','AHRSFlag','NewPacket','PacketError'};end
        function varargout=getOutputSizeImpl(~),varargout={[6 1],[1 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8','uint8','uint8','uint8','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,6);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,6);end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly 操縦指令受信', ...
                'Text','公式 Atom JoyStick の指令を ESP-NOW で受信します。Stick6 は [Roll, Pitch, Yaw, Thrust, 制御モード, 高度モード]。アーム、通信状態、姿勢リセット、新パケット、エラーも出力します。Flip 用ボタンは無視します。Channel は自分専用の 1～13 にし、機体のログ送信・受信機と揃えます。','ShowSourceLink',true);
        end
    end

end
