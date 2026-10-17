classdef Logger < matlab.System & coder.ExternalDependency
    %LOGGER 概要：水平補助の診断を50 Hzで既存のUSB・ESP-NOWキューへ送ります。
    % 400 Hz内の取得・パケット作成・送信を別周期へ分散します。
    % 元の3パケットと同じ時刻・Sequenceを保持し、182byteの補足を追加。
    properties (Access=private)
        Sequence=uint16(0)
        Phase=uint8(0)
        SnapshotTime=single(0)
        SnapshotControl=zeros(24,1,'single')
        SnapshotStatus=zeros(8,1,'single')
        SnapshotFlow=zeros(8,1,'single')
        LastFrame=zeros(182,1,'uint8')
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='水平補助のログ';end
        function updateBuildInfo(b,c)
            imu.ESPNowIMUTx.updateBuildInfo(b,c);official.USBLogger50.updateBuildInfo(b,c);
        end
    end
    methods (Access=protected)
        function frame=stepImpl(o,time,diagnostics24,motion)
            profile=uint32(0);
            if coder.target('Rtw')
                coder.cinclude('official_scheduler.h');
                coder.cinclude('imu_tx.h');coder.cinclude('official_usb.h');
                profile=coder.ceval('official_now_us');
            end
            % 1. 既存50 Hzログと同じ周期の信号を、一括で保存します。
            if o.Phase==0
                o.SnapshotTime=time;o.SnapshotControl=diagnostics24;
                o.SnapshotStatus=motion.Status;o.SnapshotFlow=motion.Diagnostics;
            elseif o.Phase==6
                % 2. SFIX/SFIY/SFI8のCRC作成と別の周期で水平補足を作成。
                saved=struct('Status',o.SnapshotStatus,'Diagnostics',o.SnapshotFlow);
                o.LastFrame=horizontal.packFrame(o.Sequence,o.SnapshotTime,uint32(1401),uint32(1802),o.SnapshotControl,saved);
                o.Sequence=uint16(bitand(uint32(o.Sequence)+1,uint32(65535)));
            elseif o.Phase==7
                % 3. さらに別周期で送信。保存時刻で結合し、受信遅延と区別。
                if coder.target('Rtw')
                    sendFrame=o.LastFrame;
                    coder.ceval('imu_tx_send',coder.rref(sendFrame),uint16(182));
                    coder.ceval('official_usb_bytes',coder.rref(sendFrame),uint16(182));
                end
            end
            o.Phase=uint8(bitand(uint32(o.Phase)+1,uint32(7)));frame=o.LastFrame;
            if coder.target('Rtw'),coder.ceval('official_profile_record',uint8(2),profile);end
        end
        function n=getNumInputsImpl(~),n=3;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'TimeSeconds','ControlDiagnostics24','HorizontalMotion'};end
        function name=getOutputNamesImpl(~),name='SFIHFrame182';end
        function size=getOutputSizeImpl(~),size=[182 1];end
        function type=getOutputDataTypeImpl(~),type='uint8';end
        function value=isOutputComplexImpl(~),value=false;end
        function value=isOutputFixedSizeImpl(~),value=true;end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','水平補助のログ', ...
                'Text',['水平位置・速度・保持目標・速度目標・加速度・PI積分・実姿勢目標・有効性を' ...
                'SFIH182にまとめて50 Hzで記録します。各2軸の順序はX=基準機首、Y=右です。' ...
                '400 Hzタスク内で50 Hzの値を保存し、15 ms後にパケットを作成、17.5 ms後に送信します。' ...
                '保存した時刻とSequenceで既存ログへ結合します。USBと無線の送信キューを共有し、モーター・操縦指令は送信しません。'], ...
                'ShowSourceLink',true);
        end
    end
end
