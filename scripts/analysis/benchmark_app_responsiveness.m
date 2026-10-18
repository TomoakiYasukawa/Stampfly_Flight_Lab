function report = benchmark_app_responsiveness(label,useParallel)
%BENCHMARK_APP_RESPONSIVENESS Measure synthetic reception, saving and history.
% No device is connected; all recordings are generated under build/tests.
if nargin < 1, label = "baseline"; end
if nargin < 2, useParallel = true; end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'config'),fullfile(root,'tests')); configure_stampfly_project();
originalFolder = pwd;
restoreFolder = onCleanup(@()cd(originalFolder)); %#ok<NASGU>
cd(root);
folder = string(fullfile(root,'build','tests','app_responsiveness',label));
if ~isfolder(folder), mkdir(folder); end
clock=tic;
app = DataLogger(); app.UIFigure.Visible = 'off';
report.StartupSeconds=toc(clock);
cleanup = onCleanup(@()delete(app)); %#ok<NASGU>
app.ParallelEnabled=useParallel;
app.AutoRecordingEnabled = false;
app.setRecordingFolder(folder);
assert(app.waitForHistoryRead(30),'History initialization timed out.');
packer = basic.ExtendedLogger50;
releasePacker = onCleanup(@()release(packer)); %#ok<NASGU>
[raw,estimate,control,extra] = logging_fixture();
control.Mode = uint8(3);
frames = zeros(626,301,'uint8');
for k = 1:size(frames,2)
    raw.Time = single(10+(k-1)*.02);
    [base,commands,sensors] = packer(raw,estimate,control,extra);
    frames(:,k) = [sensors;commands;base];
end
app.processBytes(frames(:,1));
clock = tic; app.processBytes(frames(:));
report.ReceiveSeconds = toc(clock);
file = app.startRecording(folder);
profile clear; profile on;
clock = tic; app.processBytes(frames(:));
report.ReceiveAndSaveSeconds = toc(clock);
clock = tic; app.stopRecording();
report.FinalSaveSeconds = toc(clock);
clock=tic;
assert(app.waitForRecordingSave(30),'Recording save failed or timed out.');
report.SaveCompletionWaitSeconds=toc(clock);
report.SaveEndToEndSeconds=report.ReceiveAndSaveSeconds+ ...
    report.FinalSaveSeconds+report.SaveCompletionWaitSeconds;
clock = tic; imu.RecordingHistoryView.refresh(app,file);
report.HistorySeconds = toc(clock);
assert(app.waitForHistoryRead(30),'History read failed or timed out.');
report.HistoryEndToEndSeconds=toc(clock);
clock = tic; imu.RecordingHistoryView.refresh(app);
report.RepeatedHistorySeconds = toc(clock);
assert(app.waitForHistoryRead(30),'Repeated history read timed out.');
profile off;
profileData = profile('info');
functions = profileData.FunctionTable;
[~,order] = sort([functions.TotalTime],'descend');
order = order(1:min(15,numel(order)));
report.HotFunctions = {functions(order).FunctionName};
report.HotSeconds = [functions(order).TotalTime];
report.HotCalls = [functions(order).NumCalls];
report.Label = string(label);
report.RecordingFile = file;
report.FrameCount = size(frames,2);
report.Parallel=useParallel;
saved=load(file,'telemetry','extensionTelemetry','info');
assert(size(saved.telemetry,1)==301 && size(saved.extensionTelemetry,1)==602 && saved.info.Complete, ...
    'Benchmark recording is incomplete.');
save(fullfile(folder,'benchmark.mat'),'report','profileData');
disp(report);
end
