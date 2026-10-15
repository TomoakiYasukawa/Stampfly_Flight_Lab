classdef LogTransport50 < matlab.System & coder.ExternalDependency
    %LOGTRANSPORT50 通常+指令+センサー補足を順に無線/USBキューへ渡す。
    % 各frameは250byte以下。Queuedはキュー投入成功で、電波到達ではない。
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function n=getDescriptiveName(),n='StampFly Telemetry and Extension Transport';end
        function updateBuildInfo(b,c)
            imu.ESPNowIMUTx.updateBuildInfo(b,c);
            official.USBLogger50.updateBuildInfo(b,c);
        end
    end
    methods (Access=protected)
        function setupImpl(~)
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');coder.cinclude('official_usb.h');
                coder.ceval('imu_tx_init',uint8(3));coder.ceval('official_usb_setup');
            end
        end
        function [drops,queued,led]=stepImpl(~,base,commands,sensors)
            drops=uint32(0);queued=uint8(0);led=uint8(0);
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');coder.cinclude('official_usb.h');
                q1=uint8(0);q2=uint8(0);q3=uint8(0);
                q1=coder.ceval('imu_tx_send',coder.rref(base),uint16(190));
                q2=coder.ceval('imu_tx_send',coder.rref(commands),uint16(190));
                q3=coder.ceval('imu_tx_send',coder.rref(sensors),uint16(246));
                queued=uint8(q1~=0 && q2~=0 && q3~=0);
                coder.ceval('official_usb_bytes',coder.rref(base),uint16(190));
                coder.ceval('official_usb_bytes',coder.rref(commands),uint16(190));
                drops=coder.ceval('official_usb_bytes',coder.rref(sensors),uint16(246));
                led=coder.ceval('imu_tx_led_mode');
            end
        end
        function n=getNumInputsImpl(~),n=3;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'SFI8Frame190','CommandFrame190','SensorFrame246'};end
        function varargout=getOutputNamesImpl(~),varargout={'USBDrops','RadioQueued','LEDMode'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'uint32','uint8','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.02);end
    end
end
