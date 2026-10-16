function report=build_imu_flight400()
%BUILD_IMU_FLIGHT400 Build the saved IMU Filter ESP32-S3 variant.
root=stampfly_project_root();configure_stampfly_project();model='StampFly_IMU400';
open_system(stampfly_model_file(model));parameters=init_imu_flight();
target=get_param(model,'CoderTargetData');assert(strcmp(target.Runtime.BuildAction,'Build'));
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(slResolve(get_param(model,'FixedStep'),model)==.0025);
assert(parameters.Step==.0025&&parameters.PWMHz==150000&&parameters.PWMBits==8);
verification=jsondecode(fileread(fullfile(root,'docs','history','imu_flight_verification.json')));assert(verification.Passed);
pid=find_system(model,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(pid)==7);
pwm=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
assert(numel(pwm)==1&&strcmp(get_param(pwm{1},'AllowMotorOutput'),'true'));
assert(isempty(find_system(model,'LookUnderMasks','all','Name','OfficialFlipSequence')));
assert(isempty(find_system(model,'LookUnderMasks','all','Name','MadgwickAttitude')));
filter=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','fusion.internal.simulink.imufilter');
assert(numel(filter)==1&&strcmp(get_param(filter{1},'DecimationFactor'),'1'));
assert(strcmp(get_param(filter{1},'DispRefFrame'),'NED'));
logger=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','basic.ExtendedLogger50');
assert(numel(logger)==1);
buildID=slResolve(get_param(logger{1},'BuildID'),logger{1});revision=slResolve(get_param(logger{1},'FirmwareRevision'),logger{1});
assert(buildID==1401&&revision==1701);
folder=fullfile(root,'build','imu400','firmware');if ~isfolder(folder),mkdir(folder);end
originalFolder=pwd;restoreFolder=onCleanup(@()cd(originalFolder));
fileConfig=Simulink.fileGenControl('getConfig');restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig));
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',folder,'createDir',true);
addpath(root);cd(folder);started=tic;slbuild(model);
firmware=fullfile(folder,[model '.bin']);assert(isfile(firmware));
destination=fullfile(root,'firmware','imu400');if ~isfolder(destination),mkdir(destination);end
suffixes={'.bin','.bootloader.bin','.partitions.bin'};files=cell(1,3);
for k=1:numel(suffixes)
    built=fullfile(folder,[model suffixes{k}]);assert(isfile(built));
    files{k}=fullfile(destination,[model suffixes{k}]);copyfile(built,files{k});
end
report=struct('Model',model,'ModelFile',get_param(model,'FileName'),'Step',parameters.Step, ...
    'PWMHz',parameters.PWMHz,'PWMBits',parameters.PWMBits,'PIDCount',numel(pid), ...
    'MotorOutputEnabled',true,'BuildID',buildID,'FirmwareRevision',revision,'IMUFilterCount',numel(filter), ...
    'CorrectedAngularVelocityToPID',true,'BuildAction','Build','BuildPassed',true,'Flashed',false, ...
    'PhysicalFlightTested',false,'BuildFolder',folder,'FirmwareFile',firmware, ...
    'DistributionFiles',{files},'BuildSeconds',toc(started));
fid=fopen(fullfile(root,'docs','history','imu_flight_build.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('IMU400_FIRMWARE_BUILD_PASSED\n');disp(report);
end
