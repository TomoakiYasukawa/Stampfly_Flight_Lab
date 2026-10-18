function report = build_stampfly_lab(models)
%BUILD_STAMPFLY_LAB Build saved models without connecting or flashing hardware.
% New artifacts go to build/firmware and firmware/current with their SHA-256.
arguments
    models (1,:) string = ["Stampfly_Tx","M5Stamp_Rx"]
end
assert(all(ismember(models,["Stampfly_Tx","M5Stamp_Rx"])), ...
    'lab:BuildModel','Choose Stampfly_Tx or M5Stamp_Rx.');
root = stampfly_project_root(); configure_stampfly_project(); init_imu_flight();
folderBefore = pwd; restoreFolder = onCleanup(@()cd(folderBefore)); %#ok<NASGU>
configBefore = Simulink.fileGenControl('getConfig');
restoreConfig = onCleanup(@()Simulink.fileGenControl('setConfig','config',configBefore)); %#ok<NASGU>
destination = fullfile(root,'firmware','current');
if ~isfolder(destination),mkdir(destination);end
items = struct('Model',{},'ModelSHA256',{},'BuildPassed',{},'BuildAction',{}, ...
    'FixedStep',{},'BuildSeconds',{},'Binaries',{},'Dependencies',{});
for k = 1:numel(models)
    model = char(models(k)); file = fullfile(root,[model '.slx']);
    load_system(file);
    assert(strcmp(get_param(model,'Dirty'),'off'),'lab:UnsavedModel','Save %s before building.',model);
    assert(strcmp(get_param(model,'HardwareBoard'),'ESP32-S3 Series (Arduino Compatible)'));
    target = get_param(model,'CoderTargetData');
    assert(strcmp(target.Runtime.BuildAction,'Build'),'lab:BuildAction','Choose Build to avoid deployment.');
    step = slResolve(get_param(model,'FixedStep'),model);
    assert((strcmp(model,'Stampfly_Tx') && step==.0025) || (strcmp(model,'M5Stamp_Rx') && step==.01));
    folder = fullfile(root,'build','firmware',model);
    Simulink.fileGenControl('set','CacheFolder',fullfile(folder,'cache'), ...
        'CodeGenFolder',folder,'createDir',true);
    cd(folder); clock=tic; slbuild(model); elapsed=toc(clock);
    binaries=struct('File',{},'SHA256',{},'Bytes',{});
    suffixes={'.bin','.bootloader.bin','.partitions.bin'};
    for j=1:3
        name=[model suffixes{j}]; source=fullfile(folder,name);
        assert(isfile(source),'lab:MissingBinary','Build did not produce %s.',name);
        bytes=dir(source); copyfile(source,fullfile(destination,name));
        binaries(j)=struct('File',['firmware/current/' name],'SHA256',sha256(source),'Bytes',bytes.bytes);
    end
    assert(binaries(1).Bytes<=hex2dec('140000'),'lab:Partition','Application exceeds the current partition.');
    buildData=load(fullfile(folder,[model '_ert_rtw'],'buildInfo.mat'),'buildInfo');
    dependencies=dependencySummary(getSourceFiles(buildData.buildInfo,true,true),root);
    if strcmp(model,'Stampfly_Tx')
        flags=string(getLinkFlags(buildData.buildInfo));
        assert(any(contains(flags,'--wrap=Stampfly_Tx_step')),'lab:StepWrapper','New-name scheduler wrapper is absent.');
        assert(any(contains(flags,'--wrap=mw_osThreadCreate')),'lab:CoreWrapper','CPU1 wrapper is absent.');
    end
    items(k)=struct('Model',[model '.slx'],'ModelSHA256',sha256(file),'BuildPassed',true, ...
        'BuildAction','Build','FixedStep',step,'BuildSeconds',elapsed, ...
        'Binaries',binaries,'Dependencies',dependencies);
    fprintf('STAMPFLY_LAB_BUILT: %s (%d bytes, %.1f seconds)\n',model,binaries(1).Bytes,elapsed);
end
report=struct('Project','StampFly_Lab','RecordedAt',string(datetime('now','TimeZone','UTC')), ...
    'MATLABRelease',version('-release'),'BuildPassed',true,'Flashed',false,'Models',items);
fid=fopen(fullfile(destination,'manifest.json'),'w','n','UTF-8');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end
function result=dependencySummary(sources,root)
% Keep the manifest portable and reject uncopied custom source inputs.
sources=replace(string(sources),'\','/');
prefix=replace(string(root),'\','/')+"/";
local=startsWith(sources,prefix,'IgnoreCase',true);
installed=startsWith(sources,replace(string(matlabroot),'\','/')+"/",'IgnoreCase',true) | ...
    contains(sources,'/ProgramData/MATLAB/','IgnoreCase',true) | ...
    startsWith(sources,'$(ARDUINO_ESP32_ROOT)');
assert(all(local | installed),'lab:ExternalSource','Build contains an external custom source.');
relative=extractAfter(sources(local),strlength(prefix));
generated=startsWith(relative,'build/','IgnoreCase',true);
result=struct('ProjectSources',relative(~generated),'GeneratedSources',relative(generated), ...
    'InstalledProductSourceCount',nnz(installed & ~local),'ExternalCustomDependencyCount',0);
end
function value=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);value=lower(strtrim(value));assert(numel(value)==64);
end
