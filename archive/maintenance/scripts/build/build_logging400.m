function report=build_logging400(modelFile)
%BUILD_LOGGING400 Build aircraft and receiver without accessing serial ports.
root=stampfly_project_root();configure_stampfly_project();
model='StampFly_PIDBlock_FlightTest400';
if nargin<1,modelFile=stampfly_model_file(model);end
open_system(modelFile);init_official();
assert(strcmp(get_param(model,'CoderTargetData').Runtime.BuildAction,'Build'));
assert(slResolve(get_param(model,'FixedStep'),model)==.0025);
assert(numel(find_system(model,'LookUnderMasks','all','Name','DedicatedPID'))==7);
assert(numel(find_system(model,'LookUnderMasks','all','System','stampfly.PMW3901MB'))==1);
assert(numel(find_system(model,'LookUnderMasks','all','System','stampfly.BMM150'))==1);
compile=Simulink.SimulationInput(model);compile=compile.setModelParameter('StopTime','0');sim(compile);
folder=fullfile(root,'build','logging400');if ~isfolder(folder),mkdir(folder);end
originalFolder=pwd;restore=onCleanup(@()cd(originalFolder)); %#ok<NASGU>
fileConfig=Simulink.fileGenControl('getConfig');
restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'),'CodeGenFolder',folder,'createDir',true);
cd(folder);started=tic;slbuild(model);
assert(isfile(fullfile(folder,[model '.bin'])));
fprintf('AIRCRAFT_LOGGING_BUILD_PASSED\n');
receiver='M5Stamp_IMU_Rx';open_system(fullfile(root,[receiver '.slx']));
reorg.edit(receiver,'root',{reorg.configure(['config:' receiver],struct('CoderTargetData', ...
    receiverBuildOnly(get_param(receiver,'CoderTargetData'))))});
slbuild(receiver);assert(isfile(fullfile(folder,[receiver '.bin'])));
save_system(receiver);
report=struct('Aircraft',model,'Receiver',receiver,'BuildPassed',true,'Flashed',false, ...
    'BuildFolder',folder,'BuildSeconds',toc(started),'ControlHz',400,'PWMRequestedHz',150000,'PWMBits',8, ...
    'FlowReadHz',400,'MagODRHz',30,'LogHz',50,'FrameBytes',[190 190 246]);
fid=fopen(fullfile(root,'docs','history','logging_build.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);disp(report);
fprintf('LOGGING_BOTH_FIRMWARE_BUILDS_PASSED\n');
end
function target=receiverBuildOnly(target)
target.Runtime.BuildAction='Build';
end
