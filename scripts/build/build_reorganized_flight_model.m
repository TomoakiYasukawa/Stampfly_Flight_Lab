function report=build_reorganized_flight_model()
%BUILD_REORGANIZED_FLIGHT_MODEL Build the saved refactor without flashing.
% 実機で成功した旧binを残し、新モデルの成果物は別のフォルダーへ保存する。
root=stampfly_project_root();
configure_stampfly_project();
model='StampFly_Official_FlightTest400';
buildRoot=fullfile(root,'build','model_reorganization');
if ~isfolder(buildRoot),mkdir(buildRoot);end
parameters=init_official();
assert(bdIsLoaded(model),'official:ModelNotOpen','Open the saved flight model first.');
target=get_param(model,'CoderTargetData');
assert(strcmp(target.Runtime.BuildAction,'Build'),'official:BuildOnly','Build must not deploy firmware.');
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(strcmp(get_param(model,'SolverType'),'Fixed-step'));
assert(parameters.Step==.0025 && parameters.PWMHz==150000 && parameters.PWMBits==8);

% 実際のチャートだけを数える。独立したMATLAB Functionは対象外。
charts=sfroot().find('-isa','Stateflow.Chart');
chartPaths={};embeddedFunctionCount=0;
for k=1:numel(charts)
    if startsWith(charts(k).Path,[model '/'])
        chartPaths{end+1}=charts(k).Path; %#ok<AGROW>
        embeddedFunctionCount=embeddedFunctionCount+numel(charts(k).find('-isa','Stateflow.EMFunction'));
    end
end
assert(numel(chartPaths)==4 && embeddedFunctionCount==0,'official:ChartStructure','Expected four native flight Charts without embedded MATLAB functions.');
pwmBlocks=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
assert(numel(pwmBlocks)==1,'official:PWMSingleOwner','Expected one motor writer.');
assert(strcmp(get_param(pwmBlocks{1},'AllowMotorOutput'),'true'),'official:FlightOutput','Flight model must retain the existing motor-output setting.');
disp(model_check(model,'root','["all"]'));
save_system(model);

originalFolder=pwd;
folderCleanup=onCleanup(@()cd(originalFolder)); %#ok<NASGU>
fileConfig=Simulink.fileGenControl('getConfig');
fileCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',fullfile(buildRoot,'cache'), ...
    'CodeGenFolder',buildRoot,'createDir',true);
cd(buildRoot);
% カレントフォルダーを移した後に、初期化関数とSystem objectを解決する。
addpath(root,fullfile(root,'models'));
assert(~isempty(which('init_official')),'official:MissingInitialization','Project initialization must remain available in the isolated build folder.');
if ~isfolder(fullfile(root,'logs')),mkdir(fullfile(root,'logs'));end
diary(fullfile(root,'logs','reorganized_flight_build.log'));
diaryCleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('Building saved model: %s\n',get_param(model,'FileName'));
started=tic;
slbuild(model);
firmware=fullfile(buildRoot,[model '.bin']);
assert(isfile(firmware),'official:MissingFirmware','Build did not produce the expected firmware binary.');
report=struct('Model',model,'ModelFile',get_param(model,'FileName'), ...
    'Step',parameters.Step,'PWMHz',parameters.PWMHz,'PWMBits',parameters.PWMBits, ...
    'StateflowChartCount',numel(chartPaths),'ChartPaths',{chartPaths}, ...
    'EmbeddedMATLABFunctionCount',embeddedFunctionCount, ...
    'MotorOutputEnabled',true,'BuildAction',target.Runtime.BuildAction, ...
    'BuildPassed',true,'Flashed',false,'BuildFolder',buildRoot, ...
    'FirmwareFile',firmware,'BuildSeconds',toc(started), ...
    'PhysicalTimingMeasured',false);
save(fullfile(root,'tests','reorganized_flight_build.mat'),'report');
fid=fopen(fullfile(root,'docs','reorganized_flight_build.json'),'w','n','UTF-8');
assert(fid>=0);fileClose=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
disp(report);
end
