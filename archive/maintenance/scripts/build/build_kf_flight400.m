function report=build_kf_flight400()
%BUILD_KF_FLIGHT400 Build the verified standard Kalman copy without flashing.
root=stampfly_project_root();configure_stampfly_project();init_kf_flight();
model='StampFly_KF400';open_system(stampfly_model_file(model));
assert(strcmp(get_param(model,'Dirty'),'off'),'kf400:Unsaved','Save the model before building.');
target=get_param(model,'CoderTargetData');assert(strcmp(target.Runtime.BuildAction,'Build'));
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(slResolve(get_param(model,'FixedStep'),model)==.0025);
verification=jsondecode(fileread(fullfile(root,'docs','history','kf_flight_verification.json')));
assert(verification.Passed&&strcmp(verification.ModelSHA256,sha256(get_param(model,'FileName'))), ...
    'kf400:VerificationRequired','Numerical and integrated comparison must pass before the firmware build.');
pid=find_system(model,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(pid)==7);
pwm=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
assert(isscalar(pwm)&&strcmp(get_param(pwm{1},'AllowMotorOutput'),'true'));
fusion=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','fusion.internal.simulink.imufilter');
assert(isscalar(fusion)&&strcmp(get_param(fusion{1},'DecimationFactor'),'1'));
structure=jsondecode(fileread(fullfile(root,'docs','history','kf_flight_structure.json')));
filter=reorg.path(model,structure.FilterBlock);
assert(strcmp(get_param(filter,'ReferenceBlock'),'ctrlSharedLib/Kalman Filter'));
assert(strcmp(get_param(filter,'ModelSource'),'Input port')&&strcmp(get_param(filter,'TimeInvariantQ'),'off'));
assert(strcmp(get_param(filter,'UseCurrentEstimator'),'on'));
assert(isempty(find_system(model,'LookUnderMasks','all','Name','OfficialFlipSequence')));
assert(isempty(find_system(model,'LookUnderMasks','all','Name','MadgwickAttitude')));
set_param(model,'SimulationCommand','update');fprintf('KF400_FULL_MODEL_UPDATE_PASSED\n');
folder=fullfile(root,'build','kf400','firmware');if ~isfolder(folder),mkdir(folder);end
originalFolder=pwd;restoreFolder=onCleanup(@()cd(originalFolder)); %#ok<NASGU>
fileConfig=Simulink.fileGenControl('getConfig');
restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',folder,'createDir',true);
addpath(root);cd(folder);started=tic;slbuild(model);
suffixes={'.bin','.bootloader.bin','.partitions.bin'};built=cell(1,3);
for k=1:3,built{k}=fullfile(folder,[model suffixes{k}]);assert(isfile(built{k}));end
info=dir(built{1});assert(info.bytes<=hex2dec('140000'));
report=struct('Model',model,'ModelSHA256',sha256(get_param(model,'FileName')), ...
    'BuildPassed',true,'BuildAction','Build','Step',.0025,'PWMHz',150000,'PWMBits',8,'PIDCount',7, ...
    'MotorOutputEnabled',true,'BuildID',1401,'FirmwareRevision',1801,'RadioChannel',3, ...
    'TaskTimingProfile','OFFICIAL_KF_PROFILE','TaskTimingStep','StampFly_KF400_step', ...
    'TaskTimingSourceSHA256',sha256(fullfile(root,'src','official_scheduler.cpp')), ...
    'TaskTimingBuildHookSHA256',sha256(fullfile(root,'code','+official','TickStart400.m')), ...
    'CorrectedAngularVelocityToPID',true,'StandardAltitudeKalmanFilter',true, ...
    'FirmwareFile',built{1},'FirmwareSHA256',sha256(built{1}), ...
    'FirmwareBytes',info.bytes,'BuildFiles',{built},'BuildSeconds',toc(started), ...
    'Flashed',false,'PhysicalFlightTested',false,'VerificationRecord','docs/history/kf_flight_verification.json');
fid=fopen(fullfile(root,'docs','history','kf_flight_build.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('KF400_FIRMWARE_BUILD_PASSED\n');disp(report);
end
function digest=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);digest=lower(strtrim(value));
end
