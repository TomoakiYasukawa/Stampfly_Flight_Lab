function report=verify_logger_app_distribution(originalRoot,copyManifest)
%VERIFY_LOGGER_APP_DISTRIBUTION 配布コピーを開き、モデル・アプリ・PID設定を確認。
% 別MATLABプロセス用。保存済み成功モデルと機器を変更しません。
arguments
    originalRoot (1,1) string
    copyManifest (1,1) string
end
% 新規取得先と同じ状態にし、プロジェクトの起動処理だけでパスを設定します。
root=string(pwd);restoredefaultpath;
removeToolkitPath();
project=matlab.project.loadProject(fullfile(root,'StampFly_Lab.prj'));
report=verify_imu_distribution();
fprintf('LOGGER_APP_DISTRIBUTION_RUNTIME_PASSED; CHECKING_HASHES\n');
modelNames={'Stampfly_Tx.slx','M5Stamp_Rx.slx'};
report.TestedModels=records(root,modelNames,false);
for k=1:numel(modelNames)
    assert(strcmp(report.TestedModels(k).SHA256,sha256(fullfile(originalRoot,modelNames{k}),false)));
end
appNames={'DataLogger.m','DataLogger.xml'};
report.TestedAppFiles=records(root,appNames,true);
for k=1:numel(appNames)
    assert(strcmp(report.TestedAppFiles(k).SHA256,sha256(fullfile(originalRoot,appNames{k}),true)));
end
hostNames={'code/+imu/RecordingHistoryView.m','code/+imu/readRecordingHistory.m', ...
    'code/+imu/ControlSettings.m','code/+imu/recordingFolder.m','code/+imu/flightStatePresentation.m'};
report.TestedHostSources=records(root,hostNames,false);
for k=1:numel(report.TestedHostSources)
    assert(strcmp(report.TestedHostSources(k).SHA256,sha256(fullfile(originalRoot,hostNames{k}),false)));
end
% このPCのSimulink起動で自動登録されるToolkitも検証プロセスだけから除外。
removeToolkitPath();
app=DataLogger();
settings=imu.ControlSettings.read();
app.controlLoadButtonPushed([]);
assert(isequal(app.ControlPIDTable.Data,settings.PIDValues));
app.ControlPIDTable.Data(1,1)=.39;
app.HorizontalControlTable.Data{2,2}=1.9;
removeToolkitPath();
app.controlApplyButtonPushed([]);
assert(contains(app.ControlSettingsStatusLabel.Text,'反映しました'));
after=imu.ControlSettings.read();
assert(after.PIDValues(1,1)==double(single(.39)) && after.HorizontalValues(2)==1.9);
report.PIDAndHorizontalSettingsUIVerified=true;
report.ControlSettingsWithoutToolkitVerified=true;
report.FirmwareRevision=1804;report.HardwareIO=false;
report.SavedModelChanged=false;
delete(app);close_system('Stampfly_Tx',0);
assert(strcmp(report.TestedModels(1).SHA256,sha256(fullfile(root,modelNames{1}),false)));
report.CopyManifestSHA256=sha256(copyManifest,false);
report.Passed=report.Passed && report.ControlSettingsWithoutToolkitVerified;
fid=fopen(stampfly_report_file('docs/logger_app_distribution_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
close(project);
fprintf('LOGGER_APP_FRESH_COPY_MODEL_APP_AND_SETTINGS_PASSED\n');
end
function removeToolkitPath()
% 設定更新が標準Simulink APIへ進むよう、このMATLABプロセスだけを整えます。
toolkitRoot=fullfile(getenv('USERPROFILE'),'.matlab','agentic-toolkits');
folders=strsplit(path,pathsep);
selected=strcmpi(folders,toolkitRoot) | startsWith(folders,[toolkitRoot filesep],'IgnoreCase',true);
if any(selected)
    rmpath(folders{selected});
    fprintf('LOGGER_APP_DISTRIBUTION_TOOLKIT_PATH_REMOVED: %s\n',toolkitRoot);
end
assert(isempty(which('model_edit')) && isempty(which('model_read')) && ...
    isempty(which('library.settingsLookup')), ...
    'imu:DistributionToolkit','Toolkit本体のパスを除外できません。');
end
function output=records(root,names,normalize)
output=struct('File',{},'SHA256',{},'HashNormalization',{});
for k=1:numel(names)
    if normalize,label='LF';else,label='bytes';end
    output(k)=struct('File',names{k},'SHA256',sha256(fullfile(root,names{k}),normalize), ...
        'HashNormalization',label);
end
end
function digest=sha256(file,normalize)
if normalize
    fid=fopen(file,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8');fclose(fid);
    positions=find(bytes(1:end-1)==13 & bytes(2:end)==10);bytes(positions)=[];
    file=[tempname '.sha256'];
    cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
    fid=fopen(file,'wb');assert(fid>=0);fwrite(fid,bytes,'uint8');fclose(fid);
end
% Java未導入の確認環境でも使えるWindows標準のファイルハッシュを使用。
command=sprintf('powershell -NoProfile -NonInteractive -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"', ...
    strrep(char(file),'''',''''''));
[status,value]=system(command);assert(status==0);digest=lower(strtrim(value));
assert(~isempty(regexp(digest,'^[0-9a-f]{64}$','once')));
end
