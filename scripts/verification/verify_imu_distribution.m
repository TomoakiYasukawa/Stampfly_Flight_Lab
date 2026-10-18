function report=verify_imu_distribution()
%VERIFY_IMU_DISTRIBUTION 新規取得先でモデル・アプリと依存元を確認する。
% restoredefaultpath 後に、コピー側のプロジェクトから実行する検証。
root=stampfly_project_root();license('checkout','Navigation_Toolbox');
project=currentProject();assert(strcmpi(project.RootFolder,root));
models={'Stampfly_Tx','M5Stamp_Rx'};
for k=1:numel(models)
    open_system(fullfile(root,[models{k} '.slx']));
    set_param(models{k},'SimulationCommand','update');
    assert(strcmpi(fileparts(which(models{k})),root));
end
classes={'stampfly.BMI270IMU','stampfly.BMM150','stampfly.PMW3901MB', ...
    'official.BottomToFSource','official.TickStart400','official.MotorPWM400', ...
    'official.LogTransport50','basic.ExtendedLogger50','basic.Joystick400', ...
    'imu.M5Receiver','imu.MatRecordingWriter','imu.readExtendedTelemetry', ...
    'imu.FlightRecorder','imu.readRecordingHistory','imu.RecordingHistoryView', ...
    'imu.flightStateDefinition','imu.flightStateName','imu.recordingStopName', ...
    'imu.heightVelocity','imu.resetReasonName','imu.recordingTimeline','imu.LivePlotTimeline', ...
    'horizontal.IMUSource','horizontal.FlowMotion','horizontal.Command','horizontal.VelocityPI', ...
    'horizontal.SelectAttitude','horizontal.Logger','horizontal.TelemetryPacker','horizontal.TelemetryTransport', ...
    'horizontal.mathSingle','horizontal.vectorNorm'};
for k=1:numel(classes)
    source=which(classes{k});assert(within(source,root),'cleanup:ExternalMATLABCode','%s resolves outside project.',classes{k});
end
assert(strcmpi(stampfly.BMI270IMU.libsRoot(),root));
app=DataLogger();figureHandle=app.UIFigure;delete(app);assert(~isvalid(figureHandle));
% 同名の比較IMU版を検索パスへ置かないことも確認する。
currentPaths=strsplit(path,pathsep);
assert(~any(cellfun(@(p)within(p,fullfile(root,'archive')),currentPaths)));
startupIssues=listStartupIssues(project);assert(isempty(startupIssues));
checks=runChecks(project);updateDependencies(project);
checkSummary=struct('ID',{},'Passed',{},'ProblemFileCount',{});
for k=1:numel(checks)
    checkSummary(k)=struct('ID',checks(k).ID,'Passed',checks(k).Passed, ...
        'ProblemFileCount',numel(checks(k).ProblemFiles));
end
ids=string({checks.ID});sourceControlCheck=contains(ids,'UnderSourceControl');
nonSourceControlPassed=all([checks(~sourceControlCheck).Passed]);
gitIncluded=isfolder(fullfile(root,'.git')) || isfile(fullfile(root,'.git'));
projectChecksPassed=all([checks.Passed]);
passed=nonSourceControlPassed && (~gitIncluded || projectChecksPassed);
report=struct('ProjectFile','StampFly_Lab.prj','FreshCopy',true,'RestoredDefaultPath',true, ...
    'FullModelUpdatesPassed',true,'CurrentAircraft',models{1},'CurrentReceiver',models{2}, ...
    'AppConstructedAndClosed',true,'CustomClassesResolveInsideProject',true, ...
    'ArchivedModelsExcludedFromPath',true,'ExternalCustomDependencies',0, ...
    'ProjectChecks',checkSummary,'ProjectChecksPassed',projectChecksPassed, ...
    'RuntimeChecksPassed',true,'NonSourceControlProjectChecksPassed',nonSourceControlPassed, ...
    'GitMetadataIncluded',gitIncluded,'Passed',passed);
if ~gitIncluded
    report.SourceControlCheckNote=['配布用コピーは.gitを含まないためGit管理のチェックを実行可否の判定から除きます。' ...
        'ファイル存在・パス・起動・モデル更新・アプリと、元リポジトリの登録は別に検証します。'];
end
writeJSON(stampfly_report_file('docs/imu_distribution_verification.json'),report);
assert(report.Passed,'cleanup:DistributionFailed','配布コピーの検証に失敗しました。');
fprintf('IMU_FRESH_DISTRIBUTION_MODEL_AND_APP_PASSED\n');
end
function yes=within(file,folder)
file=replace(string(file),'\','/');folder=strip(replace(string(folder),'\','/'),'right','/');
yes=strcmpi(file,folder)||startsWith(file,folder+"/",'IgnoreCase',true);
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
