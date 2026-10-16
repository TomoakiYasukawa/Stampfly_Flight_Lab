function report=build_imu_cleanup()
%BUILD_IMU_CLEANUP 現行機体・受信機をビルドし、配布BINと依存元を記録する。
% 書き込みは行わない。通常の設定変更と書き込みはSimulink画面から行う。
root=stampfly_project_root();configure_stampfly_project();
license('checkout','Navigation_Toolbox');init_imu_flight();
verification=jsondecode(fileread(fullfile(root,'docs','imu_cleanup_verification.json')));
assert(verification.Passed && strcmp(verification.ModelSHA256,sha256(fullfile(root,'StampFly_IMU400.slx'))), ...
    'cleanup:VerificationRequired','Final saved model comparison must pass before building.');
models={'StampFly_IMU400','M5Stamp_IMU_Rx'};results=cell(1,2);
oldFolder=pwd;restoreFolder=onCleanup(@()cd(oldFolder)); %#ok<NASGU>
fileConfig=Simulink.fileGenControl('getConfig');
restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
destination=fullfile(root,'firmware','current');if ~isfolder(destination),mkdir(destination);end
for n=1:numel(models)
    model=models{n};open_system(fullfile(root,[model '.slx']));
    assert(strcmp(get_param(model,'Dirty'),'off'),'cleanup:Unsaved','Save %s before building.',model);
    target=get_param(model,'CoderTargetData');
    assert(strcmp(target.Runtime.BuildAction,'Build'),'cleanup:BuildOnly','Build action must be Build.');
    assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
    expectedStep=[.0025,.01];assert(slResolve(get_param(model,'FixedStep'),model)==expectedStep(n));
    assert(strcmp(get_param(model,'SystemTargetFile'),'ert.tlc'));
    set_param(model,'SimulationCommand','update');
    folder=fullfile(root,'build','imu_cleanup','firmware',model);if ~isfolder(folder),mkdir(folder);end
    Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
        'CodeGenFolder',folder,'createDir',true);
    cd(folder);started=tic;slbuild(model);buildSeconds=toc(started);
    suffixes={'.bin','.bootloader.bin','.partitions.bin'};
    binaries=struct('File',{},'SHA256',{},'Bytes',{});
    for k=1:numel(suffixes)
        name=[model suffixes{k}];file=fullfile(folder,name);assert(isfile(file));
        info=dir(file);copyfile(file,fullfile(destination,name));
        binaries(k)=struct('File',['firmware/current/' name],'SHA256',sha256(file),'Bytes',info.bytes);
    end
    assert(binaries(1).Bytes<=hex2dec('140000'),'cleanup:PartitionSize','Application exceeds partition.');
    buildInfoFile=fullfile(folder,[model '_ert_rtw'],'buildInfo.mat');assert(isfile(buildInfoFile));
    loaded=load(buildInfoFile,'buildInfo');
    dependencies=auditBuildDependencies(loaded.buildInfo,root,fileparts(buildInfoFile));
    settings=struct;
    if n==1
        pid=find_system(model,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(pid)==7);
        pwm=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
        assert(isscalar(pwm)&&strcmp(get_param(pwm{1},'AllowMotorOutput'),'true'));
        fusion=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','fusion.internal.simulink.imufilter');
        assert(isscalar(fusion)&&strcmp(get_param(fusion{1},'DecimationFactor'),'1'));
        pack=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','basic.ExtendedLogger50');
        joystick=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','basic.Joystick400');
        transport=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.LogTransport50');
        assert(isscalar(pack)&&isscalar(joystick)&&isscalar(transport));
        ch=slResolve(get_param(joystick{1},'Channel'),model);
        assert(ch==slResolve(get_param(transport{1},'Channel'),model));
        settings=struct('PIDCount',7,'PWMHz',150000,'PWMBits',8,'MotorOutputEnabled',true, ...
            'CorrectedAngularVelocityToPID',true,'AltitudeKalmanImplementation','MATLAB Function', ...
            'RawToFModeIndependent',true,'BuildID',double(slResolve(get_param(pack{1},'BuildID'),model)), ...
            'FirmwareRevision',double(slResolve(get_param(pack{1},'FirmwareRevision'),model)), ...
            'RadioChannel',double(ch));
    else
        receiver=find_system(model,'BlockType','MATLABSystem','System','imu.M5Receiver');assert(isscalar(receiver));
        settings=struct('RadioChannel',double(slResolve(get_param(receiver{1},'Channel'),model)), ...
            'BaudRate',double(slResolve(get_param(receiver{1},'BaudRate'),model)));
    end
    results{n}=struct('Model',[model '.slx'],'ModelSHA256',sha256(get_param(model,'FileName')), ...
        'BuildPassed',true,'BuildAction','Build','Step',expectedStep(n),'SystemTargetFile','ert.tlc', ...
        'Settings',settings,'Binaries',binaries,'BuildSeconds',buildSeconds,'Dependencies',dependencies);
    fprintf('IMU_CLEANUP_FIRMWARE_BUILT: %s (%d bytes)\n',model,binaries(1).Bytes);
end
assert(results{1}.Settings.RadioChannel==results{2}.Settings.RadioChannel);
report=struct('BuildPassed',true,'MATLABRelease',version('-release'),'Models',{results}, ...
    'VerificationRecord','docs/imu_cleanup_verification.json','Flashed',false, ...
    'PhysicalFlightTested',false,'HardwareTimingMeasured',false, ...
    'Note','ToFの校正中取得タイミングと処理時間は実機では未測定。比較は同じ入力データに対する制御・ログの一致を確認。');
writeJSON(fullfile(root,'docs','imu_cleanup_build.json'),report);
writeJSON(fullfile(destination,'manifest.json'),report);
fprintf('IMU_CLEANUP_AIRCRAFT_AND_RECEIVER_BUILD_PASSED\n');
end

function result=auditBuildDependencies(info,root,generatedFolder)
% 独自ファイルはチェックアウト内、製品とツールチェーンはインストール内。
sources=string(getSourceFiles(info,true,true));
sourcePaths=string(getSourcePaths(info,true));includePaths=string(getIncludePaths(info,true));
paths=unique([sourcePaths(:);includePaths(:)]);
toolchain=string(codertarget.arduinobase.internal.getArduinoIDERoot);
support=string(matlabshared.supportpkg.getSupportPackageRoot);
allowed=[string(root),string(matlabroot),toolchain,support];
macros=buildMacros(generatedFolder);
external=strings(0,1);local=strings(0,1);productCount=0;unresolved=strings(0,1);
for k=1:numel(sources)
    value=expandMacros(char(sources(k)),macros);
    if contains(value,'$('),unresolved(end+1)=string(value);continue;end %#ok<AGROW>
    if isempty(regexp(value,'^([A-Za-z]:[\\/]|[\\/]{2})','once'))
        value=fullfile(pwd,value);
    end
    canonical=absolutePath(value);
    if within(canonical,root)
        local(end+1)=replace(extractAfter(string(canonical),strlength(string(root))+1),'\','/'); %#ok<AGROW>
    elseif any(arrayfun(@(p)within(canonical,p),allowed))
        productCount=productCount+1;
    else
        external(end+1)=string(canonical); %#ok<AGROW>
    end
    if ~isfile(canonical),unresolved(end+1)=string(canonical);end %#ok<AGROW>
end
for k=1:numel(paths)
    value=expandMacros(char(paths(k)),macros);if isempty(value),continue;end
    if contains(value,'$('),unresolved(end+1)=string(value);continue;end %#ok<AGROW>
    if isempty(regexp(value,'^([A-Za-z]:[\\/]|[\\/]{2})','once')),value=fullfile(pwd,value);end
    canonical=absolutePath(value);
    if ~any(arrayfun(@(p)within(canonical,p),allowed)),external(end+1)=string(canonical);end %#ok<AGROW>
end
assert(isempty(external),'cleanup:ExternalDependency','External custom dependencies: %s',strjoin(external,newline));
assert(isempty(unresolved),'cleanup:UnresolvedDependency','Unresolved build sources: %s',strjoin(unresolved,newline));
result=struct('ExternalCustomDependencyCount',0,'UnresolvedSourceCount',0, ...
    'ProjectSources',{cellstr(unique(local))},'InstalledProductSourceCount',productCount, ...
    'AllowedInstalledDependencies',{{'MATLAB products','Arduino Support Package','ESP32 Arduino toolchain'}});
end
function yes=within(file,folder)
file=replace(string(file),'\','/');folder=strip(replace(string(folder),'\','/'),'right','/');
yes=strcmpi(file,folder)||startsWith(file,folder+"/",'IgnoreCase',true);
end
function digest=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);digest=lower(strtrim(value));
assert(~isempty(regexp(digest,'^[0-9a-f]{64}$','once')));
end
function file=absolutePath(file)
[exists,attributes]=fileattrib(file);
if exists,file=attributes.Name;end
end
function values=buildMacros(folder)
% makeを実行せず、ビルドが保存したArduinoパスの変数だけを展開する。
values=struct;
files=dir(fullfile(folder,'*.mk'));
for k=1:numel(files)
    tokens=regexp(fileread(fullfile(files(k).folder,files(k).name)), ...
        '(?m)^([A-Za-z_][A-Za-z_0-9]*)\s*[:?]?=\s*([^\r\n]+)','tokens');
    for j=1:numel(tokens),values.(tokens{j}{1})=strtrim(tokens{j}{2});end
end
end
function value=expandMacros(value,macros)
for iteration=1:12
    previous=value;tokens=regexp(value,'\$\(([A-Za-z_][A-Za-z_0-9]*)\)','tokens');
    for k=1:numel(tokens)
        key=tokens{k}{1};
        if isfield(macros,key),value=strrep(value,['$(' key ')'],macros.(key));end
    end
    if strcmp(previous,value),return;end
end
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
