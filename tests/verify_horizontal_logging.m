function report=verify_horizontal_logging()
%VERIFY_HORIZONTAL_LOGGING 水平ログのCRC・独立受信・記録・欠落時の結合を確認。
root=stampfly_project_root();[~,~,~,~,motion]=horizontal.fixture();
values=single((1:24)')/single(100);motion.Status=single((1:8)');motion.Diagnostics=single((11:18)');
frame=horizontal.packFrame(uint16(5),single(1.25),uint32(1401),uint32(1801),values,motion);
assert(imu.frameLength(frame(1:4))==182);sample=imu.decodeExtensionFrame(frame);
assert(sample.Kind==3&&sample.FirmwareRevision==1801);
assert(isequal(single(sample.Values(122:161)'),[values;motion.Status;motion.Diagnostics]));
assert(all(isnan(sample.Values(1:121))));bad=frame;bad(20)=bitxor(bad(20),uint8(1));
rejected=false;try,imu.decodeExtensionFrame(bad);catch e,rejected=strcmp(e.identifier,'imu:CRCError');end
assert(rejected);
% 分散ロガーは取得時の値・時刻を保持し、次周期の入力と混ぜません。
logger=horizontal.Logger;cleanupLogger=onCleanup(@()release(logger)); %#ok<NASGU>
for k=0:15
    current=values+single(k);inputTime=single(2)+single(k)*single(.0025);
    packed=logger(inputTime,current,motion);
    if mod(k,8)==6
        decoded=imu.decodeExtensionFrame(packed);snapshotTick=k-6;
        assert(decoded.Sequence==uint16(floor(k/8)));
        assert(decoded.FirmwareRevision==1802);
        assert(abs(decoded.TimeSeconds-(2+snapshotTick*.0025))<.0011);
        assert(isequal(single(decoded.Values(122:145)'),values+single(snapshotTick)));
    end
end
app=DataLogger();app.UIFigure.Visible='off';clean=onCleanup(@()delete(app)); %#ok<NASGU>
folder=string(fullfile(root,'build','horizontal_control','logs'));file=app.startRecording(folder);
[raw,estimate,control,extra]=logging_fixture();packer=basic.ExtendedLogger50;
cleanPacker=onCleanup(@()release(packer)); %#ok<NASGU>
for k=1:3
    raw.Time=single(1+(k-1)/50);[base,commands,sensors]=packer(raw,estimate,control,extra);
    h=horizontal.packFrame(uint16(k-1),raw.Time,uint32(1401),uint32(1801),values,motion);
    if k~=2,app.processBytes(h);end
    app.processBytes([sensors;commands;base]);
end
app.stopRecording();
assert(app.waitForRecordingSave(),'horizontal:SaveTimeout','Recording save did not finish.');
saved=load(file,'info','extensionTelemetry');joined=imu.readExtendedTelemetry(file);
assert(isequal(size(saved.extensionTelemetry),[8 166]));
assert(isnan(joined.HorizontalState(2))&&all(joined.HorizontalState([1 3])==double(values(16))));
assert(all(joined.FlowTotalXModulo==double(extra.Flow.Totals(1))));
report=struct('Passed',true,'CRCVerified',true,'MissingSupplementRemainsNaN',true,'AppAndRecordingVerified',true);
fid=fopen(fullfile(root,'build','horizontal_control','logging_verification.json'),'w','n','UTF-8');
assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_LOGGING_VERIFICATION_PASSED\n');
end
