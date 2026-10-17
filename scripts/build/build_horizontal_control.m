function report=build_horizontal_control()
%BUILD_HORIZONTAL_CONTROL 保存モデルの水平補助・高度修正・診断版をビルドする。
% 保存モデルとソースのSHA-256、生成BIN、依存元を記録します。
% 書き込みは別工程です。通常の操作はREADMEのSimulinkメニューを使います。
root=stampfly_project_root();configure_stampfly_project();
license('checkout','Navigation_Toolbox');init_imu_flight();
checks={'incident_invariants_verification','vertical_boundary_verification', ...
    'incident_recording_verification','incident_layout_verification', ...
    'horizontal_telemetry_verification','imu_cleanup_model_audit'};
for k=1:numel(checks)
    check=jsondecode(fileread(fullfile(root,'docs',[checks{k} '.json'])));
    if isfield(check,'Passed'),assert(check.Passed);else,assert(check.Failed==0&&check.Incomplete==0);end
end
invariants=jsondecode(fileread(fullfile(root,'docs','incident_invariants_verification.json')));
assert(strcmp(invariants.ModelSHA256,sha256(fullfile(root,'StampFly_IMU400.slx'))), ...
    'horizontal:SavedVerification','The invariant audit must match the saved model.');
assert(invariants.PIDParametersPreserved&&invariants.SupervisorUnchanged);
assert(~invariants.FullOutputEquivalenceClaimed);
sourceSnapshot=sourceHashes(root);
models={'StampFly_IMU400','M5Stamp_IMU_Rx'};results=cell(1,2);expectedStep=[.0025,.01];
destination=fullfile(root,'firmware','current');if ~isfolder(destination),mkdir(destination);end
% 1801の実飛行失敗版も保全し、旧記録のSHAと参照先を失わないようにします。
previousManifest=fullfile(destination,'manifest.json');
if isfile(previousManifest)
    previous=jsondecode(fileread(previousManifest));
    if previous.Models(1).Settings.FirmwareRevision==1801
        archiveFolder=fullfile(root,'firmware','history','horizontal1801');
        if ~isfolder(archiveFolder),mkdir(archiveFolder);end
        for j=1:numel(previous.Models)
            for k=1:numel(previous.Models(j).Binaries)
                item=previous.Models(j).Binaries(k);original=fullfile(root,item.File);
                assert(strcmp(sha256(original),item.SHA256),'horizontal:ArchiveDigest','旧BINがmanifestと一致しません。');
                [~,stem,ext]=fileparts(original);archived=fullfile(archiveFolder,[stem ext]);
                if isfile(archived),assert(strcmp(sha256(archived),item.SHA256));else,copyfile(original,archived);end
            end
        end
        if ~isfile(fullfile(archiveFolder,'manifest.json')),copyfile(previousManifest,fullfile(archiveFolder,'manifest.json'));end
        record=fullfile(root,'docs','horizontal_build.json');
        if isfile(record),copyfile(record,fullfile(archiveFolder,'build.json'));end
    end
end
oldFolder=pwd;restoreFolder=onCleanup(@()cd(oldFolder)); %#ok<NASGU>
fileConfig=Simulink.fileGenControl('getConfig');
restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
for n=1:numel(models)
    model=models{n};open_system(fullfile(root,[model '.slx']));
    assert(strcmp(get_param(model,'Dirty'),'off'),'horizontal:Unsaved','Save the model before build.');
    target=get_param(model,'CoderTargetData');assert(strcmp(target.Runtime.BuildAction,'Build'));
    assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
    assert(slResolve(get_param(model,'FixedStep'),model)==expectedStep(n));
    assert(strcmp(get_param(model,'SystemTargetFile'),'ert.tlc'));
    set_param(model,'SimulationCommand','update');
    folder=fullfile(root,'build','horizontal_control','firmware',model);if ~isfolder(folder),mkdir(folder);end
    Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
        'CodeGenFolder',folder,'createDir',true);
    cd(folder);started=tic;slbuild(model);elapsed=toc(started);
    suffixes={'.bin','.bootloader.bin','.partitions.bin'};
    binaries=struct('File',{},'SHA256',{},'Bytes',{});
    for k=1:numel(suffixes)
        name=[model suffixes{k}];file=fullfile(folder,name);assert(isfile(file));
        metadata=dir(file);copyfile(file,fullfile(destination,name));
        binaries(k)=struct('File',['firmware/current/' name],'SHA256',sha256(file),'Bytes',metadata.bytes);
    end
    assert(binaries(1).Bytes<=hex2dec('140000'),'horizontal:Partition','Application exceeds partition.');
    generated=fullfile(folder,[model '_ert_rtw']);info=load(fullfile(generated,'buildInfo.mat'),'buildInfo');
    dependencies=auditDependencies(info.buildInfo,root,generated);
    if n==1
        pids=find_system(model,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(pids)==7);
        pack=one(model,'horizontal.TelemetryPacker');command=one(model,'horizontal.Command');
        pwm=one(model,'official.MotorPWM400');fusion=one(model,'fusion.internal.simulink.imufilter');
        assert(strcmp(get_param(pwm,'AllowMotorOutput'),'true'));
        assert(strcmp(get_param(fusion,'DecimationFactor'),'1'));
        assert(strcmp(get_param(command,'Enabled'),'true'));
        joystick=one(model,'basic.Joystick400');transport=one(model,'horizontal.TelemetryTransport');
        ch=slResolve(get_param(joystick,'Channel'),model);
        assert(ch==slResolve(get_param(transport,'Channel'),model));
        revision=double(slResolve(get_param(pack,'FirmwareRevision'),model));assert(revision==1802);
        settings=struct('PIDCount',7,'PWMHz',150000,'PWMBits',8,'MotorOutputEnabled',true, ...
            'ExistingPIDParametersPreserved',true,'CorrectedAngularVelocityToPID',true, ...
            'AltitudeKalmanImplementation','MATLAB Function','RawToFModeIndependent',true, ...
            'AltitudeControlTiltCompensated',false,'HorizontalAssistEnabled',true, ...
            'VerticalAccelerationUnits','m/s^2','ParkingKalmanReset','rising edge', ...
            'ResetReasonTelemetry',true,'WatchdogDisabled',false, ...
            'HorizontalVelocityAndPositionLocalFrame',true,'HorizontalSupplementBytes',182, ...
            'BuildID',double(slResolve(get_param(pack,'BuildID'),model)), ...
            'FirmwareRevision',revision,'RadioChannel',double(ch));
    else
        receiver=one(model,'imu.M5Receiver');
        settings=struct('RadioChannel',double(slResolve(get_param(receiver,'Channel'),model)), ...
            'BaudRate',double(slResolve(get_param(receiver,'BaudRate'),model)), ...
            'AcceptsSFIH182',contains(fileread(fullfile(root,'src','imu_rx.cpp')), '"SFIH"'));
        assert(settings.AcceptsSFIH182);
    end
    results{n}=struct('Model',[model '.slx'],'ModelSHA256',sha256(get_param(model,'FileName')), ...
        'BuildPassed',true,'BuildAction','Build','Step',expectedStep(n),'SystemTargetFile','ert.tlc', ...
        'Settings',settings,'Binaries',binaries,'BuildSeconds',elapsed,'Dependencies',dependencies);
    fprintf('HORIZONTAL_FIRMWARE_BUILT: %s (%d bytes)\n',model,binaries(1).Bytes);
end
assert(results{1}.Settings.RadioChannel==results{2}.Settings.RadioChannel);
assert(isequaln(sourceSnapshot,sourceHashes(root)),'horizontal:BuildSourcesChanged','Source changed during build.');
report=struct('BuildPassed',true,'MATLABRelease',version('-release'),'Models',{results}, ...
    'VerificationRecords',{checks},'SourceHashes',sourceSnapshot,'Flashed',false, ...
    'PhysicalFlightTested',false,'HardwareTimingMeasured',false, ...
    'Purpose','USB-only incident diagnosis; flight investigation remains open', ...
    'FlightCauseConfirmed',false,'FlightReleaseApproved',false, ...
    'PreviousFullOutputRegression','docs/horizontal_off_verification.json', ...
    'PreviousFullOutputRegressionAppliesTo','Revision 1801 before vertical boundary repair');
writeJSON(fullfile(root,'docs','horizontal_build.json'),report);
writeJSON(fullfile(destination,'manifest.json'),report);
fprintf('HORIZONTAL_AIRCRAFT_AND_RECEIVER_BUILD_PASSED\n');
end
function path=one(model,cls)
blocks=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System',cls);
assert(isscalar(blocks));path=blocks{1};
end
function records=sourceHashes(root)
% 一つのプロセスで全ソースを読み、JREのないMATLABでも検証できます。
[status,value]=system(sprintf('python "%s"',fullfile(root,'tools','hash_project_sources.py')));
assert(status==0);records=jsondecode(value);
end
function result=auditDependencies(info,root,generatedFolder)
% 独自コードはプロジェクト内、製品とツールチェーンはインストール内です。
sources=string(getSourceFiles(info,true,true));
sourcePaths=string(getSourcePaths(info,true));includePaths=string(getIncludePaths(info,true));
paths=unique([sourcePaths(:);includePaths(:)]);
toolchain=string(codertarget.arduinobase.internal.getArduinoIDERoot);
support=string(matlabshared.supportpkg.getSupportPackageRoot);
allowed=[string(root),string(matlabroot),toolchain,support];
macros=buildMacros(generatedFolder);external=strings(0,1);unresolved=strings(0,1);local=strings(0,1);productCount=0;
for k=1:numel(sources)
    value=expand(char(sources(k)),macros);
    if contains(value,'$('),unresolved(end+1)=string(value);continue;end %#ok<AGROW>
    canonical=resolve(value);
    if within(canonical,root)
        local(end+1)=replace(extractAfter(string(canonical),strlength(string(root))+1),'\','/'); %#ok<AGROW>
    elseif any(arrayfun(@(p)within(canonical,p),allowed)),productCount=productCount+1;
    else,external(end+1)=string(canonical);end %#ok<AGROW>
    if ~isfile(canonical),unresolved(end+1)=string(canonical);end %#ok<AGROW>
end
for k=1:numel(paths)
    value=expand(char(paths(k)),macros);if isempty(value),continue;end
    if contains(value,'$('),unresolved(end+1)=string(value);continue;end %#ok<AGROW>
    canonical=resolve(value);
    if ~any(arrayfun(@(p)within(canonical,p),allowed)),external(end+1)=string(canonical);end %#ok<AGROW>
end
assert(isempty(external),'horizontal:ExternalDependency','%s',strjoin(external,newline));
assert(isempty(unresolved),'horizontal:UnresolvedDependency','%s',strjoin(unresolved,newline));
result=struct('ExternalCustomDependencyCount',0,'UnresolvedSourceCount',0, ...
    'ProjectSources',{cellstr(unique(local))},'InstalledProductSourceCount',productCount);
end
function path=resolve(path)
if isempty(regexp(path,'^([A-Za-z]:[\\/]|[\\/]{2})','once')),path=fullfile(pwd,path);end
[found,attributes]=fileattrib(path);if found,path=attributes.Name;end
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
function values=buildMacros(folder)
values=struct;files=dir(fullfile(folder,'*.mk'));
for k=1:numel(files)
    tokens=regexp(fileread(fullfile(files(k).folder,files(k).name)), ...
        '(?m)^([A-Za-z_][A-Za-z_0-9]*)\s*[:?]?=\s*([^\r\n]+)','tokens');
    for j=1:numel(tokens),values.(tokens{j}{1})=strtrim(tokens{j}{2});end
end
end
function value=expand(value,macros)
for iteration=1:12
    previous=value;tokens=regexp(value,'\$\(([A-Za-z_][A-Za-z_0-9]*)\)','tokens');
    for k=1:numel(tokens),key=tokens{k}{1};if isfield(macros,key),value=strrep(value,['$(' key ')'],macros.(key));end;end
    if strcmp(previous,value),return;end
end
end
function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
