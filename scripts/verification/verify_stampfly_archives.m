function report=verify_stampfly_archives()
%VERIFY_STAMPFLY_ARCHIVES アーカイブの保存状態と移動後の開き方を確認する。
% 比較版を保存し直さず、通常の検索先が現行IMU版へ戻ることも確認する。
root=stampfly_project_root();license('checkout','Navigation_Toolbox');
savedPath=path;restorePath=onCleanup(@()path(savedPath)); %#ok<NASGU>
current={'StampFly_IMU400','M5Stamp_IMU_Rx'};
currentHashes=cellfun(@(m)sha256(fullfile(root,[m '.slx'])),current,'UniformOutput',false);
archived=dir(fullfile(root,'archive','**','*.slx'));
hashes=cell(numel(archived),1);
for k=1:numel(archived)
    hashes{k}=sha256(fullfile(archived(k).folder,archived(k).name));
end
manifest=jsondecode(fileread(fullfile(root,'archive','aircraft','manifest.json')));
for k=1:numel(manifest.Models)
    entry=manifest.Models(k);
    assert(strcmp(entry.SHA256,sha256(fullfile(root,entry.ArchivedPath))), ...
        'archive:Changed','Archived bytes changed: %s',entry.ArchivedPath);
end
assert(strcmp(sha256(fullfile(root,'archive','kf400','StampFly_KF400.slx')), ...
    '7b4bfddfafad0d0a53b8b4ec998ce1f5f3be061954af273ab40c8e1d08045a0a'));
assert(strcmp(sha256(fullfile(root,'archive','kf400','baseline','StampFly_IMU400.slx')), ...
    '2f83a78a97d656741d2230512bb150f9d2b0814713dec011a13d27f52cbf86bf'));
% PID比較版の保存済みコールバックは、先に開いた公式モデルを参照する。
names={'StampFly_Official_FlightTest400','StampFly_PIDBlock_FlightTest400', ...
    'StampFly_Basic400','PIDBlockComparison400','StampFly_Official_Bench400', ...
    'StampFly_Official_EstimatorReplay400','StampFly_Official_FlightSim400', ...
    'StampFly_Official_FullReplay400','StampFly_PWM400_Probe','StampFly_KF400'};
opened=struct('File',{},'Opened',{},'FullUpdatePassed',{});
for k=1:numel(names)
    model=names{k};file=stampfly_model_file(model);open_system(file);
    assert(strcmpi(get_param(model,'FileName'),file));updated=false;
    if ismember(model,{'StampFly_Basic400','StampFly_KF400'})
        set_param(model,'SimulationCommand','update');updated=true;
    end
    opened(k)=struct('File',relative(file,root),'Opened',true,'FullUpdatePassed',updated);
    fprintf('STAMPFLY_ARCHIVE_OPENED: %s\n',model);
end
for k=1:numel(names),close_system(names{k},0);end
baseline=fullfile(root,'archive','kf400','baseline','StampFly_IMU400.slx');
open_system(baseline);assert(strcmpi(get_param('StampFly_IMU400','FileName'),baseline));
opened(end+1)=struct('File',relative(baseline,root),'Opened',true,'FullUpdatePassed',false);
close_system('StampFly_IMU400',0);
% 比較用の初期化関数を追加したパスを戻し、現行ファイルの解決先を確認する。
path(savedPath);configure_stampfly_project();
for k=1:numel(current)
    file=fullfile(root,[current{k} '.slx']);open_system(file);
    assert(strcmpi(get_param(current{k},'FileName'),file));
    assert(strcmpi(which(current{k}),file));
    set_param(current{k},'SimulationCommand','update');close_system(current{k},0);
    assert(strcmp(currentHashes{k},sha256(file)));
end
preserved=struct('File',{},'SHA256',{});
for k=1:numel(archived)
    file=fullfile(archived(k).folder,archived(k).name);
    assert(strcmp(hashes{k},sha256(file)));
    preserved(k)=struct('File',relative(file,root),'SHA256',hashes{k});
end
report=struct('OpenedModels',opened,'PreservedModels',preserved, ...
    'ArchivedModelCount',numel(archived),'AllArchivedModelBytesPreserved',true, ...
    'CurrentModelsResolveAtRoot',true,'CurrentFullModelUpdatesPassed',true, ...
    'SavedAnyModel',false,'Flashed',false,'Passed',true);
fid=fopen(fullfile(root,'docs','imu_archive_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('STAMPFLY_ARCHIVE_PRESERVATION_AND_OPEN_PASSED\n');
end
function value=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);value=lower(strtrim(value));assert(numel(value)==64);
end
function value=relative(file,root)
value=char(replace(extractAfter(string(file),strlength(string(root))+1),'\','/'));
end
