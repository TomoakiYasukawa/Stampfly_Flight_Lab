classdef FlightRecorder < handle
    %FLIGHTRECORDER 概要：受信した飛行状態から1飛行分のMAT記録を作ります。
    % 飛行/着陸モードで開始し、前2秒と待機後1秒を含めて保存します。
    % 通信途絶や機体時刻リセットは待機復帰と区別します。機器への指令は出しません。

    properties
        Enabled (1,1) logical = true
        Folder (1,1) string = ""
        Config (1,1) struct = struct()
        PreRollSeconds (1,1) double = 2
        PostRollSeconds (1,1) double = 1
        LossTimeoutSeconds (1,1) double = 2
        WriteBatchFcn = []
    end
    properties (SetAccess = private)
        Writer = []
        Active (1,1) logical = false
        Automatic (1,1) logical = false
        LastPath (1,1) string = ""
        SavedPaths string = strings(0,1)
        Status (1,1) string = "自動記録: 飛行制御待ち"
        ErrorMessage (1,1) string = ""
    end
    properties (Access = private)
        PrePackets cell = cell(0,1)
        PreTimes double = zeros(0,1)
        PreHosts double = zeros(0,1)
        LastDeviceTime (1,1) double = NaN
        LastBaseTime (1,1) double = NaN
        LastBaseSequence (1,1) double = NaN
        RestartPackets cell = cell(0,1)
        RestartBaseTime (1,1) double = NaN
        RestartBaseSequence (1,1) double = NaN
        RestartBaseCount (1,1) double = 0
        StopReason (1,1) string = "parked"
        RestartDetail (1,1) struct = struct()
        DeviceClockOffset (1,1) double = 0
        LastModeTime (1,1) double = NaN
        LastMode (1,1) double = NaN
        LastPacketHost (1,1) double = NaN
        StopDeviceTime (1,1) double = NaN
        StopHostTime (1,1) double = NaN
        LastFlushDeviceTime (1,1) double = NaN
        LastFlushHostTime (1,1) double = NaN
        MissingStart (1,1) double = 0
        CRCStart (1,1) double = 0
        Suppressed (1,1) logical = false
    end

    methods
        function obj=FlightRecorder(folder,config)
            if nargin>=1,obj.Folder=string(folder);end
            if nargin>=2,obj.Config=config;end
        end

        function accept(obj,sample,frame,hostSeconds,missingCount,crcCount)
            % 1. 対象機体のCRC確認済みパケットだけを受け取ります。
            if isfield(obj.Config,'ExpectedBuildID') && obj.Config.ExpectedBuildID~=0 && ...
                    isfield(sample,'BuildID') && double(sample.BuildID)~=double(obj.Config.ExpectedBuildID)
                return
            end
            deviceTime=double(sample.TimeSeconds);
            if ~isfinite(deviceTime),return;end
            clockPeriod=2^32/1000;
            if isfinite(obj.LastDeviceTime) && obj.LastDeviceTime-obj.DeviceClockOffset>clockPeriod-1 && deviceTime<1
                % uint32ミリ秒の約49.7日での一周は、同じ飛行として連続記録。
                obj.DeviceClockOffset=obj.DeviceClockOffset+clockPeriod;
            end
            deviceTime=deviceTime+obj.DeviceClockOffset;
            if obj.DeviceClockOffset>0 && deviceTime>obj.LastDeviceTime+clockPeriod/2
                deviceTime=deviceTime-clockPeriod; % 一周前に生成されて遅れて届いた補足。
            end
            % 2. 逆転したパケットは一旦保留します。単独の遅延フレームを
            % 再起動とせず、別の通常フレームの進行で新しい時刻系を確認。
            if isfinite(obj.LastBaseTime) && deviceTime<obj.LastBaseTime-.5
                obj.holdRestartPacket(sample,frame,deviceTime,hostSeconds,missingCount,crcCount);
                return
            elseif ~isempty(obj.RestartPackets)
                % 同じ時刻系が続いたため、保留分は遅れて届いた過去の記録。
                % 観測状態・停止判断は巻き戻さず、受信データだけを残します。
                obj.drainDelayedPackets();
            end
            obj.LastDeviceTime=max([deviceTime,obj.LastDeviceTime],[],'omitnan');
            obj.LastPacketHost=hostSeconds;
            if ~isfield(sample,'Kind')
                obj.LastBaseTime=deviceTime;obj.LastBaseSequence=double(sample.Sequence);
            end
            mode=obj.packetMode(sample);
            previousMode=obj.LastMode;
            if isfinite(mode) && (~isfinite(obj.LastModeTime) || deviceTime>=obj.LastModeTime)
                obj.LastMode=mode;obj.LastModeTime=deviceTime;
                if ~obj.isFlightMode(mode),obj.Suppressed=false;end
            else
                mode=NaN; % 古い飛行状態で保存済みの飛行を再び開始しません。
            end
            try
                % 2. 通常フレームを待たず、先に届く指令補足でも飛行を検出します。
                if obj.Automatic && obj.Active && isfinite(obj.StopDeviceTime) && ...
                        obj.isFlightMode(mode) && ~obj.isFlightMode(previousMode)
                    obj.stop(missingCount,crcCount,'parked_next_takeoff');
                end
                if obj.Enabled && isempty(obj.Writer) && ~obj.Suppressed && obj.isFlightMode(mode)
                    trigger='flight_mode';
                    if ~isfinite(previousMode),trigger='connected_midflight';end
                    obj.begin(true,missingCount,crcCount,trigger,hostSeconds,deviceTime);
                    if ~isempty(obj.PrePackets)
                        obj.MissingStart=obj.PrePackets{1}.MissingCount;
                        obj.CRCStart=obj.PrePackets{1}.CRCCount;
                    end
                    for k=1:numel(obj.PrePackets)
                        entry=obj.PrePackets{k};obj.append(entry.Sample,entry.Frame);
                    end
                    obj.PrePackets=cell(0,1);
                    obj.PreTimes=zeros(0,1);obj.PreHosts=zeros(0,1);
                end
                if obj.Active
                    % 3. 通常/全補足を受信順に保存し、ヘッダーの対応づけを保持。
                    obj.append(sample,frame);
                    if obj.Automatic && isfinite(mode)
                        if obj.isFlightMode(mode)
                            obj.StopDeviceTime=NaN;obj.StopHostTime=NaN;
                        elseif ~isfinite(obj.StopDeviceTime)
                            obj.StopDeviceTime=deviceTime;obj.StopHostTime=hostSeconds;
                            if ismember(mode,[0 1]),obj.StopReason="initialization";
                            else,obj.StopReason="parked";end
                        end
                    end
                    % 4. 約0.5秒ごとに書き出し、未保存のメモリーだけへ溜めません。
                    if deviceTime-obj.LastFlushDeviceTime>=.5 || hostSeconds-obj.LastFlushHostTime>=.5
                        obj.Writer.flush();
                        obj.LastFlushDeviceTime=deviceTime;obj.LastFlushHostTime=hostSeconds;
                    end
                    if obj.Automatic && isfinite(obj.StopDeviceTime) && ...
                            deviceTime>=obj.StopDeviceTime+obj.PostRollSeconds && ~isfield(sample,'Kind')
                        % 同時刻の補足が先に届くため、通常フレームまで保存して閉じます。
                        obj.stop(missingCount,crcCount,obj.StopReason);
                    else
                        obj.updateStatus();
                    end
                end
                % 次回離陸用の直前受信バッファ。時間と件数の両方を制限します。
                obj.PrePackets{end+1,1}=struct('Sample',sample,'Frame',uint8(frame(:)), ...
                    'Time',deviceTime,'Host',hostSeconds,'MissingCount',missingCount,'CRCCount',crcCount);
                obj.PreTimes(end+1,1)=deviceTime;obj.PreHosts(end+1,1)=hostSeconds;
                keep=obj.PreTimes>=deviceTime-obj.PreRollSeconds & ...
                    obj.PreHosts>=hostSeconds-obj.PreRollSeconds;
                obj.PrePackets=obj.PrePackets(keep);
                obj.PreTimes=obj.PreTimes(keep);obj.PreHosts=obj.PreHosts(keep);
                if numel(obj.PrePackets)>2000
                    obj.PrePackets=obj.PrePackets(end-1999:end);
                    obj.PreTimes=obj.PreTimes(end-1999:end);obj.PreHosts=obj.PreHosts(end-1999:end);
                end
            catch err
                obj.fail(err);
            end
        end

        function poll(obj,hostSeconds,missingCount,crcCount)
            % 5. 受信が止まった場合も保存します。通信途絶を着陸とは扱いません。
            if ~obj.Active || ~obj.Automatic,return;end
            if isfinite(obj.LastPacketHost) && hostSeconds-obj.LastPacketHost>=obj.LossTimeoutSeconds
                obj.stop(missingCount,crcCount,'telemetry_lost');
                obj.resetObservation();
            elseif isfinite(obj.StopHostTime) && hostSeconds>=obj.StopHostTime+obj.PostRollSeconds
                obj.stop(missingCount,crcCount,obj.StopReason);
            end
        end

        function path=startManual(obj,folder,missingCount,crcCount)
            % 机上確認用の手動記録。自動記録と別ファイルへ二重保存しません。
            if obj.Automatic && obj.Active,obj.stop(missingCount,crcCount,'manual_recording');end
            if ~isempty(obj.Writer)
                error('imu:RecordingAlreadyOpen','Stop or retry saving the previous recording first.');
            end
            if nargin>=2 && strlength(string(folder))>0,obj.Folder=string(folder);end
            obj.begin(false,missingCount,crcCount,'manual',0,0);
            path=obj.Writer.FilePath;
        end

        function path=stop(obj,missingCount,crcCount,reason)
            % 6. 保存失敗時はWriterを残し、同じファイルで再試行できるようにします。
            path="";
            if nargin<4,reason='manual_stop';end
            if isempty(obj.Writer),return;end
            obj.Active=false;
            try
                if ~strcmp(reason,'firmware_restart'),obj.drainDelayedPackets();end
                detail=struct('Automatic',obj.Automatic,'Reason',char(reason), ...
                    'LastObservedFlightMode',obj.LastMode,'LastDeviceTimeSeconds',obj.LastDeviceTime);
                if strcmp(reason,'firmware_restart'),detail.NewBoot=obj.RestartDetail;end
                obj.Writer.finish(max(0,missingCount-obj.MissingStart),max(0,crcCount-obj.CRCStart),detail);
                path=obj.Writer.FilePath;count=obj.Writer.Count;
                obj.LastPath=path;obj.SavedPaths(end+1,1)=path;obj.Writer=[];
                if strcmp(reason,'manual_stop') && obj.Automatic && obj.isFlightMode(obj.LastMode)
                    obj.Suppressed=true;
                end
                obj.Status=sprintf('保存完了: %d フレーム / %s',count,imu.recordingStopName(reason));
                obj.ErrorMessage="";obj.StopDeviceTime=NaN;obj.StopHostTime=NaN;
            catch err
                obj.fail(err);
            end
        end

        function resetConnection(obj)
            % 切断前の記録は呼出し側で保存し、新接続では途中飛行も検出します。
            obj.resetObservation();
        end
    end

    methods (Access = private)
        function holdRestartPacket(obj,sample,frame,deviceTime,hostSeconds,missingCount,crcCount)
            entry=struct('Sample',sample,'Frame',uint8(frame(:)), ...
                'Time',deviceTime,'Host',hostSeconds,'MissingCount',missingCount,'CRCCount',crcCount);
            if numel(obj.RestartPackets)>=2000,obj.drainDelayedPackets();end
            obj.RestartPackets{end+1,1}=entry;
            if isfield(sample,'Kind'),return;end
            sequence=double(sample.Sequence);
            if obj.RestartBaseCount==0
                obj.RestartBaseCount=1;
            elseif deviceTime>obj.RestartBaseTime && ...
                    mod(sequence-obj.RestartBaseSequence,65536)>0 && ...
                    mod(sequence-obj.RestartBaseSequence,65536)<32768
                obj.RestartBaseCount=obj.RestartBaseCount+1;
            else
                obj.RestartBaseCount=1;
            end
            obj.RestartBaseTime=deviceTime;obj.RestartBaseSequence=sequence;
            % 起動直後の初期化/校正に加え、進む通常フレームを2件要求します。
            % 通信開始が飛行途中だった場合は3件で確認し、途中飛行も保存します。
            mode=obj.packetMode(sample);
            needed=3;if ismember(mode,[0 1]) && deviceTime<5,needed=2;end
            if obj.RestartBaseCount<needed,return;end
            entries=obj.RestartPackets;
            confirmedFrames=obj.RestartBaseCount;
            obj.clearRestartPackets();
            resetReason=NaN;
            for k=1:numel(entries)
                s=entries{k}.Sample;if isfield(s,'ResetReason'),resetReason=s.ResetReason;end
            end
            obj.RestartDetail=struct('FirstDeviceTimeSeconds',entries{1}.Sample.TimeSeconds, ...
                'ConfirmedByBaseFrames',confirmedFrames,'ResetReason',resetReason);
            if obj.Automatic && ~isempty(obj.Writer)
                obj.stop(missingCount,crcCount,'firmware_restart');
            end
            obj.resetObservation();
            % 新しい起動の補足も最初から再処理。前の飛行へ混ぜません。
            for k=1:numel(entries)
                e=entries{k};obj.accept(e.Sample,e.Frame,e.Host,e.MissingCount,e.CRCCount);
            end
        end

        function drainDelayedPackets(obj)
            entries=obj.RestartPackets;obj.clearRestartPackets();
            if isempty(obj.Writer),return;end
            for k=1:numel(entries),obj.append(entries{k}.Sample,entries{k}.Frame);end
        end

        function clearRestartPackets(obj)
            obj.RestartPackets=cell(0,1);obj.RestartBaseTime=NaN;
            obj.RestartBaseSequence=NaN;obj.RestartBaseCount=0;
        end

        function yes=isFlightMode(obj,mode)
            schema='StampFlyOfficial-v1';
            if isfield(obj.Config,'FlightStateSchema'),schema=char(obj.Config.FlightStateSchema);end
            if strcmp(schema,'StampFlyOfficial-v1'),yes=mode==2 || mode==5;
            elseif strcmp(schema,'StampFlyHover-v1'),yes=mode==1 || mode==2 || mode==3;
            else,yes=false;end
        end

        function begin(obj,automatic,missingCount,crcCount,trigger,hostTime,deviceTime)
            config=obj.Config;
            config.Recording=struct('Automatic',automatic,'Trigger',trigger, ...
                'PreRollSeconds',obj.PreRollSeconds,'PostRollSeconds',obj.PostRollSeconds, ...
                'LossTimeoutSeconds',obj.LossTimeoutSeconds);
            folder=obj.Folder;
            if strlength(folder)==0,folder=fullfile(fileparts(which('DataLogger')),'recordings');end
            obj.Writer=imu.MatRecordingWriter(folder,config,obj.WriteBatchFcn);
            obj.Active=true;obj.Automatic=automatic;
            obj.MissingStart=missingCount;obj.CRCStart=crcCount;
            obj.LastFlushDeviceTime=deviceTime;obj.LastFlushHostTime=hostTime;
            obj.StopDeviceTime=NaN;obj.StopHostTime=NaN;obj.ErrorMessage="";
            obj.updateStatus();
        end

        function append(obj,sample,frame)
            if isfield(sample,'Kind'),obj.Writer.appendExtension(sample,frame);
            else,obj.Writer.append(sample,frame);end
        end

        function updateStatus(obj)
            if ~obj.Active,return;end
            kind='記録中';if obj.Automatic,kind='自動記録中';end
            obj.Status=sprintf('%s: %d フレーム',kind,obj.Writer.bufferedCount());
        end

        function fail(obj,err)
            obj.Active=false;obj.Suppressed=true;
            obj.ErrorMessage=string(err.message);
            obj.Status="記録エラー: 保存先を確認・保存再試行";
        end

        function resetObservation(obj)
            obj.PrePackets=cell(0,1);obj.LastDeviceTime=NaN;obj.LastModeTime=NaN;
            obj.PreTimes=zeros(0,1);obj.PreHosts=zeros(0,1);
            obj.LastBaseTime=NaN;obj.LastBaseSequence=NaN;obj.clearRestartPackets();
            obj.DeviceClockOffset=0;
            obj.LastMode=NaN;obj.LastPacketHost=NaN;
            obj.StopDeviceTime=NaN;obj.StopHostTime=NaN;obj.Suppressed=false;
        end
    end

    methods (Static,Access = private)
        function mode=packetMode(sample)
            mode=NaN;
            if isfield(sample,'Kind')
                if sample.Kind==1 && numel(sample.Values)>=45,mode=double(sample.Values(45));end
            elseif isfield(sample,'FlightState')
                mode=double(sample.FlightState);
            end
        end
    end
end
