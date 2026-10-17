classdef TelemetryPacker < basic.ExtendedLogger50
    %TELEMETRYPACKER 概要：通常・指令・センサーログの計算を別周期へ分散。
    % 同じ50 Hz時刻の入力を保存し、SFI8/SFIX/SFIYを順に作ります。
    % 形式・値・Sequenceは従来と等価で、飛行制御の信号には影響しません。
    properties (Access=private)
        Phase=uint8(0)
        PacketSequence=uint16(0)
        SnapshotSequence=uint16(0)
        SnapshotRaw=horizontal.loggingState('raw')
        SnapshotEstimate=horizontal.loggingState('estimate')
        SnapshotControl=horizontal.loggingState('control')
        SnapshotExtra=horizontal.loggingState('extra')
        Base=zeros(190,1,'uint8')
        Commands=zeros(190,1,'uint8')
        Sensors=zeros(246,1,'uint8')
    end
    methods
        function o=TelemetryPacker(varargin)
            % 版番号はモデルのNontunable設定で一度だけ指定します。
            % コンストラクターで既定値を再代入すると、別の保存値のコード生成が失敗します。
            setProperties(o,nargin,varargin{:});
        end
    end
    methods (Access=protected)
        function [base,commands,sensors]=stepImpl(o,raw,estimate,control,extra)
            profile=uint32(0);
            if coder.target('Rtw')
                coder.cinclude('official_scheduler.h');profile=coder.ceval('official_now_us');
            end
            if o.Phase==0
                % 1. 全入力を同時に保存します。通常パケットは軽い周期で作ります。
                o.SnapshotRaw=raw;o.SnapshotEstimate=estimate;
                o.SnapshotControl=control;o.SnapshotExtra=extra;
                o.SnapshotSequence=o.PacketSequence;
                o.PacketSequence=uint16(bitand(uint32(o.PacketSequence)+1,uint32(65535)));
            elseif o.Phase==1
                % 2. 次周期で同じ時刻の指令補足を作ります。
                o.Commands=basic.packCommandExtension(o.SnapshotSequence,o.SnapshotRaw.Time, ...
                    o.BuildID,o.FirmwareRevision,o.SnapshotEstimate,o.SnapshotControl);
            elseif o.Phase==2
                % 3. さらに次周期で同じ時刻のセンサー補足を作ります。
                o.Sensors=imu.packSensorExtension(o.SnapshotSequence,o.SnapshotRaw.Time, ...
                    o.BuildID,o.FirmwareRevision,o.SnapshotRaw,o.SnapshotEstimate, ...
                    o.SnapshotControl,o.SnapshotExtra);
            elseif o.Phase==4
                % 4. 50 Hzのセンサー処理と重ならない周期で通常パケットを作ります。
                o.Base=packBaseImpl(o,o.SnapshotSequence,o.SnapshotRaw, ...
                    o.SnapshotEstimate,o.SnapshotControl,o.SnapshotExtra);
            end
            o.Phase=uint8(bitand(uint32(o.Phase)+1,uint32(7)));
            base=o.Base;commands=o.Commands;sensors=o.Sensors;
            if coder.target('Rtw'),coder.ceval('official_profile_record',uint8(0),profile);end
        end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','StampFly ログ作成の負荷分散', ...
                'Text',['50 Hzで生センサー・推定・指令・追加センサーを同時に保存し、' ...
                'SFIXを2.5 ms後、SFIYを5 ms後、SFI8を10 ms後に作ります。' ...
                '項目順・型・CRC・保存時刻・Sequenceは従来と同じです。' ...
                '後段のTelemetryTransportが各パケットを一度だけ送信します。' ...
                'BuildIDはプログラムの識別番号で、機体固有のIDではありません。'], ...
                'ShowSourceLink',true);
        end
    end
end
