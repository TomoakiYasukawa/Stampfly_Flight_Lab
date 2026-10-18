function result = verify_bottom_logger()
%VERIFY_BOTTOM_LOGGER Validate downward ToF validity, freshness and MAT storage.
root = fileparts(fileparts(mfilename('fullpath')));
packer = official.LoggerPacker50;
cleanup = onCleanup(@()release(packer)); %#ok<NASGU>
accel = single([0;0;9.80665]);
gyro = zeros(3,1,'single');
duty = zeros(4,1,'single');
attitude = zeros(3,1,'single');
control = zeros(17,1,'single');
sensors = zeros(8,1,'single');
% A valid 350 mm sample, the same held sample, then two invalid results.
distances = int16([350 350 350 0]);
statuses = uint8([0 0 90 255]);
counts = uint32([1 1 2 3]);
expectedValid = [true true false false];
expectedFresh = [true false true true];
writer = imu.MatRecordingWriter(string(fullfile(root,'recordings')), ...
    struct('Project','BottomToFLoggerRegression','MotorOutputEnabled',false));
for k = 1:numel(distances)
    tofInfo = uint32([counts(k);counts(k);10000;0]);
    frame = packer(accel,gyro,uint8(1),single(k*.02), ...
        distances(k),uint8(0),statuses(k),single(3.7),uint8(1), ...
        duty,uint8(3),attitude,single(.35),single(0),control,sensors,tofInfo);
    sample = imu.decodeFrame(frame);
    assert(sample.ToFValid == expectedValid(k),'official:ToFLoggerValidity');
    assert(sample.ToFFresh == expectedFresh(k),'official:ToFLoggerFreshness');
    assert(sample.ToFRangeStatus == statuses(k),'official:ToFLoggerStatus');
    if expectedValid(k)
        assert(abs(sample.ToFDistanceM-single(.35)) < single(1e-6));
    end
    % Preserve numeric payload independently of its validity flag for diagnosis.
    assert(abs(sample.ToFDistanceM-single(distances(k))/single(1000))<single(1e-6));
    assert(all(isnan(sample.FlowDelta)) && ~sample.FlowStatus && ~sample.FlowUsed);
    writer.append(sample,frame);
end
file = writer.finish(0,0);
saved = load(file,'telemetry','info');
validCol = strcmp(saved.info.Columns,'ToFValid');
rangeCol = strcmp(saved.info.Columns,'ToFDistanceM');
statusCol = strcmp(saved.info.Columns,'ToFRangeStatus');
assert(isequal(saved.telemetry(:,validCol),double(expectedValid(:))));
assert(isequal(saved.telemetry(:,statusCol),double(statuses(:))));
assert(all(abs(saved.telemetry(1:2,rangeCol)-.35)<1e-6));
assert(abs(saved.telemetry(3,rangeCol)-.35)<1e-6 && saved.telemetry(4,rangeCol)==0);
result = struct('Cases',4,'Passed',true,'MATFile',file, ...
    'OpticalFlowImplemented',false);
save(fullfile(reference_mex_folder(),'bottom_logger_verification.mat'),'result');
disp(result);
end
