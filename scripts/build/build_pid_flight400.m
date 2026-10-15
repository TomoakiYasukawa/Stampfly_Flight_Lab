function report=build_pid_flight400()
%BUILD_PID_FLIGHT400 Build the dedicated-PID comparison without deploying.
root=stampfly_project_root();configure_stampfly_project();
model='StampFly_PIDBlock_FlightTest400';
open_system(fullfile(root,[model '.slx']));parameters=init_official();
target=get_param(model,'CoderTargetData');
assert(strcmp(target.Runtime.BuildAction,'Build'));
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(slResolve(get_param(model,'FixedStep'),model)==.0025);
assert(parameters.Step==.0025 && parameters.PWMHz==150000 && parameters.PWMBits==8);
verification=jsondecode(fileread(fullfile(root,'docs','pid_flight_verification.json')));
assert(verification.Passed && verification.PIDCount==7);
pid=find_system(model,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(pid)==7);
for k=1:numel(pid)
    assert(strcmp(get_param(pid{k},'Form'),'Ideal'));
    assert(strcmp(get_param(pid{k},'UseExternalTs'),'on'));
end
pwm=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
assert(numel(pwm)==1 && strcmp(get_param(pwm{1},'AllowMotorOutput'),'true'));
charts=sfroot().find('-isa','Stateflow.Chart');count=0;functions=0;
for k=1:numel(charts)
    if startsWith(charts(k).Path,[model '/'])
        count=count+1;functions=functions+numel(charts(k).find('-isa','Stateflow.EMFunction'));
    end
end
assert(count==4 && functions==0);save_system(model);
folder=fullfile(root,'build','pid_flight400');if ~isfolder(folder),mkdir(folder);end
originalFolder=pwd;restoreFolder=onCleanup(@()cd(originalFolder)); %#ok<NASGU>
fileConfig=Simulink.fileGenControl('getConfig');
restoreConfig=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
    'CodeGenFolder',folder,'createDir',true);
addpath(root);cd(folder);started=tic;slbuild(model);
firmware=fullfile(folder,[model '.bin']);assert(isfile(firmware));
report=struct('Model',model,'ModelFile',get_param(model,'FileName'), ...
    'Step',parameters.Step,'PWMHz',parameters.PWMHz,'PWMBits',parameters.PWMBits, ...
    'PIDCount',numel(pid),'StateflowChartCount',count,'EmbeddedMATLABFunctionCount',functions, ...
    'MotorOutputEnabled',true,'BuildAction','Build','BuildPassed',true, ...
    'Flashed',false,'BuildFolder',folder,'FirmwareFile',firmware, ...
    'BuildSeconds',toc(started),'PhysicalTimingMeasured',false);
save(fullfile(root,'tests','pid_flight_build.mat'),'report');
fid=fopen(fullfile(root,'docs','pid_flight_build.json'),'w','n','UTF-8');assert(fid>=0);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
fprintf('PID_FLIGHT_FIRMWARE_BUILD_PASSED\n');disp(report);
end
