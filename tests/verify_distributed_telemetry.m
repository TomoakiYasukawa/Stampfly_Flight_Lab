function report=verify_distributed_telemetry()
%VERIFY_DISTRIBUTED_TELEMETRY 分散ログを変更前の50 Hz生成値とbyte単位で比較。
% 後続周期で入力を変化させ、保存時点の値だけを使うことも確認します。
root=stampfly_project_root();legacyFolder=fullfile(root,'tests','reference','telemetry');
addpath(legacyFolder);cleanupPath=onCleanup(@()rmpath(legacyFolder)); %#ok<NASGU>
legacy=LegacyBasicLogger;legacy.FirmwareRevision=uint32(1802);
modified=basic.ExtendedLogger50;modified.FirmwareRevision=uint32(1802);
distributed=horizontal.TelemetryPacker;distributed.FirmwareRevision=uint32(1802);
transport=horizontal.TelemetryTransport;
cleanup=onCleanup(@()releaseAll(legacy,modified,distributed,transport)); %#ok<NASGU>
[raw,estimate,control,extra]=logging_fixture();
control=rmfield(control,'FlipPhase');control.Pilot=rmfield(control.Pilot,'FlipButton');
expected=cell(1,3);groups=64;
for tick=0:8*groups-1
    raw.Time=single(2)+single(tick)*single(.0025);
    raw.Acceleration=single([1;2;9.81])+single(tick)*single(.001);
    raw.ToFInfo(1)=uint32(40000+floor(tick/12));extra.Mag.Info(1)=uint32(30+floor(tick/14));
    extra.Flow.Totals=uint32([mod(4294967280+tick*3,4294967296);mod(10-tick*2,4294967296)]);
    estimate.ControlDiagnostics=single((1:17)')*single(.031)+single(tick)*single(.001);
    estimate.Quaternion=single([1;0;0;0]);control.AppliedCounts=uint8(mod(tick,200))*ones(4,1,'uint8');
    if mod(tick,8)==0
        [expected{:}]=legacy(raw,estimate,control,extra);
        [refactored{1:3}]=modified(raw,estimate,control,extra); %#ok<AGROW>
        assert(isequal(expected,refactored),'horizontal:BaseLogger','50 Hz logger refactor changed bytes.');
    end
    [frames{1:3}]=distributed(raw,estimate,control,extra); %#ok<AGROW>
    phase=mod(tick,8);
    if any(phase==[1 2 4])
        index=find([4 1 2]==phase);
        assert(isequal(frames{index},expected{index}),'horizontal:DistributedBytes', ...
            'Distributed frame differs from the captured 50 Hz inputs.');
        if index>1
            parsed=imu.decodeExtensionFrame(frames{index});assert(parsed.Sequence==uint16(floor(tick/8)));
        end
    end
    [drops,queued,led]=transport(frames{:});assert(drops==0&&queued==0&&led==0);
end
report=struct('Passed',true,'FirmwareRevision',1802,'Groups',groups,'ByteIdenticalPackets',groups*3, ...
    'ChangingInputsDuringPacking',true,'CumulativeCounterWrap',true, ...
    'SameSavedTimeAndSequence',true,'Legacy50HzBytesPreserved',true, ...
    'CaptureToSendDelayMs',[10 2.5 5]);
fid=fopen(fullfile(root,'docs','horizontal_telemetry_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_DISTRIBUTED_TELEMETRY_BYTES_VERIFIED\n');
end
function releaseAll(varargin)
for k=1:nargin,release(varargin{k});end
end
