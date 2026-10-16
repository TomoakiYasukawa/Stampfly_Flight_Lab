function report = build_sensor_replacement()
%BUILD_SENSOR_REPLACEMENT Validate the saved model without deploying firmware.
% 書き込み済みbinを保護し、ビルド結果は独立したフォルダーに保存する。
root=stampfly_project_root();
buildRoot=fullfile(root,'build','sensor_replacement');
if ~isfolder(buildRoot),mkdir(buildRoot);end
originalFolder=pwd;
folderCleanup=onCleanup(@()cd(originalFolder)); %#ok<NASGU>
cd(buildRoot);
addpath(root,fullfile(root,'models'));
parameters=init_official;
fileConfig=Simulink.fileGenControl('getConfig');
fileCleanup=onCleanup(@()Simulink.fileGenControl('setConfig','config',fileConfig)); %#ok<NASGU>
Simulink.fileGenControl('set','CacheFolder',fullfile(buildRoot,'cache'), ...
    'CodeGenFolder',buildRoot,'createDir',true);
model='StampFly_Official_FlightTest400';
open_system(stampfly_model_file(model));
target=get_param(model,'CoderTargetData');
assert(strcmp(target.Runtime.BuildAction,'Build'),'BuildAction must not deploy.');
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(strcmp(get_param(model,'SolverType'),'Fixed-step'));
assert(parameters.Step==.0025);
sensorPath=Simulink.ID.getFullName([model ':72']);
charts=sfroot().find('-isa','Stateflow.Chart');
chartCount=0;
for k=1:numel(charts)
    chartCount=chartCount+startsWith(charts(k).Path,[sensorPath '/']);
end
assert(chartCount==0,'Stateflow Chart remains in sensor scope.');
functions=sfroot().find('-isa','Stateflow.EMChart');
functionCount=0;
for k=1:numel(functions)
    functionCount=functionCount+startsWith(functions(k).Path,[sensorPath '/']);
end
assert(functionCount==5,'Expected five MATLAB Function blocks.');
disp(model_check(model,'blk_72','["all"]'));
slbuild(model);
report=struct('Model',model,'Step',parameters.Step,'PWMHz',parameters.PWMHz, ...
    'PWMBits',parameters.PWMBits,'StateflowChartCount',chartCount, ...
    'MATLABFunctionCount',functionCount,'BuildAction',target.Runtime.BuildAction, ...
    'BuildPassed',true,'Flashed',false,'BuildFolder',buildRoot);
save(fullfile(root,'tests','sensor_replacement_build.mat'),'report');
disp(report);
end
