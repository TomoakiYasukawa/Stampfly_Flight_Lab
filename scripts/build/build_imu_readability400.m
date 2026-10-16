function report=build_imu_readability400()
%BUILD_IMU_READABILITY400 Build the reorganized model, retaining flown BINs.
root=stampfly_project_root();configure_stampfly_project();init_imu_flight();
model='StampFly_IMU400';open_system(fullfile(root,[model '.slx']));
assert(strcmp(get_param(model,'Dirty'),'off'),'imu400:Unsaved','Save the model before building.');
target=get_param(model,'CoderTargetData');assert(strcmp(target.Runtime.BuildAction,'Build'));
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(slResolve(get_param(model,'FixedStep'),model)==.0025);
verification=jsondecode(fileread(fullfile(root,'docs','imu_readability_verification.json')));
assert(verification.Passed&&strcmp(verification.ModelSHA256,sha256(get_param(model,'FileName'))));
pid=find_system(model,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(pid)==7);
pwm=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
assert(numel(pwm)==1&&strcmp(get_param(pwm{1},'AllowMotorOutput'),'true'));
filter=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','fusion.internal.simulink.imufilter');
assert(numel(filter)==1&&strcmp(get_param(filter{1},'DecimationFactor'),'1'));
assert(isempty(find_system(model,'LookUnderMasks','all','Name','OfficialFlipSequence')));
assert(isempty(find_system(model,'LookUnderMasks','all','Name','MadgwickAttitude')));
set_param(model,'SimulationCommand','update');fprintf('IMU400_READABILITY_MODEL_UPDATE_PASSED\n');
folder=fullfile(root,'build','imu400','readability','firmware');if ~isfolder(folder),mkdir(folder);end
originalFolder=pwd;restoreFolder=onCleanup(@()cd(originalFolder));
fileConfig=Simulink.fileGenControl('getConfig');
restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',folder,'createDir',true);
addpath(root);cd(folder);started=tic;slbuild(model);
suffixes={'.bin','.bootloader.bin','.partitions.bin'};built=cell(1,3);
for k=1:3,built{k}=fullfile(folder,[model suffixes{k}]);assert(isfile(built{k}));end
info=dir(built{1});assert(info.bytes<=hex2dec('140000'));
report=struct('Model',model,'ModelSHA256',sha256(get_param(model,'FileName')), ...
    'BuildPassed',true,'BuildAction','Build','Step',.0025,'PWMHz',150000,'PWMBits',8,'PIDCount',7, ...
    'MotorOutputEnabled',true,'BuildID',1401,'FirmwareRevision',1701,'RadioChannel',3, ...
    'CorrectedAngularVelocityToPID',true,'FirmwareFile',built{1},'FirmwareSHA256',sha256(built{1}), ...
    'FirmwareBytes',info.bytes,'BuildFiles',{built},'BuildSeconds',toc(started), ...
    'Flashed',false,'PhysicalFlightTested',false,'VerificationRecord','docs/imu_readability_verification.json');
fid=fopen(fullfile(root,'docs','imu_readability_build.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('IMU400_READABILITY_FIRMWARE_BUILD_PASSED\n');disp(report);
end

function digest=sha256(file)
command=sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"', ...
    strrep(file,'''',''''''));
[status,value]=system(command);assert(status==0);digest=lower(strtrim(value));
assert(~isempty(regexp(digest,'^[0-9a-f]{64}$','once')));
end
