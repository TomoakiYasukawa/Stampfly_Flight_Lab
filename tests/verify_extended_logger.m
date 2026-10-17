function report=verify_extended_logger()
%VERIFY_EXTENDED_LOGGER Packet values, freshness, wrap, loss and old log support.
root=stampfly_project_root();[raw,estimate,control,extra]=logging_fixture();
packer=official.ExtendedLogger50;cleanup=onCleanup(@()release(packer)); %#ok<NASGU>
[base,commands,sensors]=packer(raw,estimate,control,extra);
a=imu.decodeFrame(base);b=imu.decodeExtensionFrame(commands);c=imu.decodeExtensionFrame(sensors);
assert(numel(base)==190 && numel(commands)==190 && numel(sensors)==246);
assert(a.MagValid && a.MagFresh && a.FlowStatus && ~a.FlowUsed);
assert(isequal(a.MagneticFieldUT,extra.Mag.Field.'));
assert(isequal(a.FlowDelta,single([1200 -800])));
assert(isequal(a.MotorCommands,single(floor(255*double(control.Duty))).'));
extra.Distance=struct('PositionEN',single([.2;-.1]),'Used',uint8(1),'DeltaEN',single([.01;-.02]));
raw.Time=single(1.01);
[distanceFrame,~,~]=packer(raw,estimate,control,extra);
distanceSample=imu.decodeFrame(distanceFrame);
assert(distanceSample.FlowUsed && isequal(distanceSample.XYDisplacementM,single([.2 -.1])));
assert(isequal(distanceSample.FlowCorrectedDeltaENM,single([.01 -.02])));
names=imu.extensionNames();
assert(isequal(b.Values(1:17),double(estimate.ControlDiagnostics.')));
assert(b.Values(strcmp(names,'AppliedPWMFR'))==100);
assert(b.Values(strcmp(names,'PWMFrequencyHz'))==150094);
assert(c.Values(strcmp(names,'FlowShutter16'))==8123);
assert(c.Values(strcmp(names,'ToFCompletedCountExact'))==40000);
assert(c.Values(strcmp(names,'MagSampleCount'))==30);
corrupt=sensors;corrupt(60)=bitxor(corrupt(60),uint8(1));
rejected=false;try,imu.decodeExtensionFrame(corrupt);catch e,rejected=strcmp(e.identifier,'imu:CRCError');end
assert(rejected);
folder=fullfile(root,'build','tests','logging');
writer=imu.MatRecordingWriter(string(folder),struct('ExpectedBuildID',1401));
writer.append(a,base);writer.appendExtension(c,sensors);writer.appendExtension(b,commands);
raw.Time=single(1.02);extra.Flow.Totals=uint32([1224;4294966480]);
[base2,~,sensors2]=packer(raw,estimate,control,extra);
a2=imu.decodeFrame(base2);c2=imu.decodeExtensionFrame(sensors2);
assert(isequal(a2.FlowDelta,single([24 -16])) && ~a2.MagFresh && ~a2.ToFFresh);
writer.append(a2,base2);writer.appendExtension(c2,sensors2);file=writer.finish(0,0);
stored=load(file,'info','telemetry','rawFrames','extensionTelemetry','extensionFrames');
assert(isequal(size(stored.telemetry),[2 80]));
assert(isequal(size(stored.extensionTelemetry),[3 166]));
assert(stored.info.ExtensionFrames==3);
joined=imu.readExtendedTelemetry(file);
assert(joined.AppliedPWMFR(1)==100 && isnan(joined.AppliedPWMFR(2)));
assert(all(joined.FlowShutter16==8123));
history=imu.readRecordingHistory(file,"all");assert(history.TotalFrames==2);
% Exercise unsigned cumulative wrap (max->low) and real data-ready freshness.
extra.Flow.Totals=uint32([4294967290;10]);packer(raw,estimate,control,extra);
extra.Flow.Totals=uint32([5;4]);extra.Mag.Info(1)=31;raw.ToFInfo(1)=40001;
[base3,~,~]=packer(raw,estimate,control,extra);a3=imu.decodeFrame(base3);
assert(isequal(a3.FlowDelta,single([11 -6])) && a3.MagFresh && a3.ToFFresh);
% Existing saved SFI8 logs remain readable without extension variables.
old=fullfile(root,'recordings','StampFly_20261015_195124_321.mat');
if isfile(old),oldTable=imu.readExtendedTelemetry(string(old));assert(height(oldTable)==1418);end
report=struct('Passed',true,'StandardBytes',190,'ExtensionBytes',[190 246], ...
    'AddedNamedFields',121,'StoredStandardRows',2,'StoredExtensionRows',3,'MATFile',file);
save(fullfile(folder,'packet_verification.mat'),'report');disp(report);
end
