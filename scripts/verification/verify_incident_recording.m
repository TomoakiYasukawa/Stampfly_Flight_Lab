function report=verify_incident_recording()
%VERIFY_INCIDENT_RECORDING 概要：自動記録・履歴・アプリとログ境界を検証します。
% 通信ポートは開かず、CRC付きのテストパケットと一時MAT記録だけを使います。
root=stampfly_project_root();configure_stampfly_project();addpath(fullfile(root,'tests'));
files={'FlightRecorderTest.m','RecordingHistoryTest.m','StampFlyIMUAppDisplayTest.m'};
suite=[];
for k=1:numel(files),suite=[suite testsuite(fullfile(root,'tests',files{k}))];end %#ok<AGROW>
results=run(suite);
folder=fullfile(root,'build','horizontal_control','fall_investigation');
if ~isfolder(folder),mkdir(folder);end
save(fullfile(folder,'incident_recording_tests.mat'),'results');
report=struct('Passed',all([results.Passed]),'Tests',numel(results), ...
    'Failed',nnz([results.Failed]),'Incomplete',nnz([results.Incomplete]), ...
    'SerialConnectionsOpened',0,'Cases',{{results.Name}});
writeJSON(fullfile(root,'docs','incident_recording_verification.json'),report);
assert(report.Passed,'imu:IncidentRecordingTests','記録・履歴・アプリの検証が失敗しました。');
report.DistributedTelemetry=verify_distributed_telemetry();
report.HorizontalLogging=verify_horizontal_logging();
writeJSON(fullfile(root,'docs','incident_recording_verification.json'),report);
fprintf('INCIDENT_RECORDING_VERIFICATION_PASSED\n');
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
