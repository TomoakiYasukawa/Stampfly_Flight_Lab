% 整理後のファイル解決を、独立したMATLABセッションで確認する。
projectRoot=fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
run(fullfile(projectRoot,'config','startup.m'));
init_imu_flight();
assert(strcmp(stampfly.BMI270IMU.libsRoot(),projectRoot));
assert(strcmp(stampfly.VL53L3CX.libsRoot(),projectRoot));
assert(isfile(DataLogger.AppConfigFilename));
models={'Stampfly_Tx','M5Stamp_Rx'};
for modelIndex=1:numel(models)
    open_system(stampfly_model_file(models{modelIndex}));
    set_param(models{modelIndex},'SimulationCommand','update');
    fprintf('COMPILE_PASSED: %s\n',models{modelIndex});
end
configuration=Simulink.fileGenControl('getConfig');
assert(strcmp(configuration.CacheFolder,fullfile(projectRoot,'build','cache')));
assert(strcmp(configuration.CodeGenFolder,fullfile(projectRoot,'build','codegen')));
report=struct('FlightModelCompilePassed',true,'ReceiverModelCompilePassed',true, ...
    'PackageRootsResolved',true,'AppXMLAtRoot',true, ...
    'CacheFolder','build/cache','CodeGenFolder','build/codegen');
fid=fopen(stampfly_report_file('docs/project_layout_verification.json'),'w');
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
disp('PROJECT_LAYOUT_VERIFICATION_PASSED');
