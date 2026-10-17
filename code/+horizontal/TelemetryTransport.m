classdef TelemetryTransport < official.LogTransport50
    %TELEMETRYTRANSPORT 概要：50 Hzの3パケットを別の400 Hz周期に送信。
    % 各入力は直前に完成したパケットで、時刻の対応づけはヘッダーで行います。
    % 制御周期を通信待ちにせず、既存の無線・USBキューへ一度ずつ渡します。
    properties (Access=private)
        Phase=uint8(0)
        Drops=uint32(0)
        Queued=uint8(0)
        LED=uint8(0)
    end
    methods (Access=protected)
        function [drops,queued,led]=stepImpl(o,base,commands,sensors)
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');coder.cinclude('official_usb.h');
                q=uint8(0);usbDrops=uint32(0);currentLED=uint8(0);
                if o.Phase==1
                    % 指令補足を送信し、今の組の成功状態を開始します。
                    q=coder.ceval('imu_tx_send',coder.rref(commands),uint16(190));
                    o.Queued=q;
                    usbDrops=coder.ceval('official_usb_bytes',coder.rref(commands),uint16(190));
                    o.Drops=usbDrops;
                elseif o.Phase==2
                    % 同じ保存時刻のセンサー補足を送信します。
                    q=coder.ceval('imu_tx_send',coder.rref(sensors),uint16(246));
                    o.Queued=uint8(o.Queued~=0&&q~=0);
                    usbDrops=coder.ceval('official_usb_bytes',coder.rref(sensors),uint16(246));
                    o.Drops=usbDrops;
                elseif o.Phase==4
                    % 50 Hzセンサー処理を避けて通常パケットを送信し、成功を確定します。
                    q=coder.ceval('imu_tx_send',coder.rref(base),uint16(190));
                    o.Queued=uint8(o.Queued~=0&&q~=0);
                    usbDrops=coder.ceval('official_usb_bytes',coder.rref(base),uint16(190));
                    o.Drops=usbDrops;
                end
                currentLED=coder.ceval('imu_tx_led_mode');o.LED=currentLED;
            end
            o.Phase=uint8(bitand(uint32(o.Phase)+1,uint32(7)));
            drops=o.Drops;queued=o.Queued;led=o.LED;
        end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','StampFly ログ送信の負荷分散', ...
                'Text',['指令補足を2.5 ms後、センサー補足を5 ms後、通常ログを10 ms後に、50 Hzの保存時刻を保って' ...
                'ESP-NOWとUSBへ送ります。Channelは操縦指令・ログ受信機と同じ専用CHです。' ...
                'Queuedは3パケットのキュー投入成功、USBDropsは累積欠落です。' ...
                '電波到達は受信側のログで確認します。'], ...
                'ShowSourceLink',true);
        end
    end
end
