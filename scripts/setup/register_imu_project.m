function report=register_imu_project()
%REGISTER_IMU_PROJECT 配布ファイルと現行モデルの入口をプロジェクトへ登録。
% 機器への接続・書き込みは行わない。アーカイブは通常のパスへ追加しない。
root=stampfly_project_root();
try,project=currentProject();catch,project=[];end
if isempty(project) || ~strcmpi(project.RootFolder,root)
    project=matlab.project.loadProject(fullfile(root,'StampFly_Official.prj'));
end
removed={};files=project.Files;
for k=1:numel(files)
    file=char(files(k).Path);
    if ~isfile(file) && ~isfolder(file)
        removeFile(project,file);removed{end+1}=relative(file,root); %#ok<AGROW>
    end
end
% Gitの追跡対象と配布予定のファイルを登録し、生成物は除く。
[status,output]=system('git -c core.quotepath=false ls-files --cached --others --exclude-standard');
assert(status==0);names=regexp(strtrim(output),'\r?\n','split');registered=0;
members=project.Files;known=lower(string({members.Path}));
for k=1:numel(names)
    name=names{k};
    if startsWith(name,'resources/project/') || isempty(name) || endsWith(name,'.prj'),continue;end
    if isfile(fullfile(root,name))
        absolute=fullfile(root,strrep(name,'/',filesep));
        if ~any(strcmpi(absolute,known)),addFile(project,name);end
        registered=registered+1;
        if mod(registered,200)==0,fprintf('IMU_PROJECT_REGISTRATION_PROGRESS: %d files\n',registered);end
    end
end
fprintf('IMU_PROJECT_PATH_AND_SHORTCUTS\n');
folders={'','config','code','libraries','tests/models','scripts/setup','scripts/build', ...
    'scripts/verification','scripts/analysis','scripts/model_edit'};
wanted=cellfun(@(f)fullfile(root,f),folders,'UniformOutput',false);
existing=project.ProjectPath;
for k=1:numel(existing)
    if ~any(strcmpi(char(existing(k).File),wanted)),removePath(project,char(existing(k).File));end
end
existing=project.ProjectPath;
for k=1:numel(folders)
    if ~any(strcmpi(wanted{k},string({existing.File}))),addPath(project,wanted{k});end
end
% メニューには現行機体、受信機、アプリ、READMEだけを置く。
shortcutFiles={'StampFly_IMU400.slx','M5Stamp_IMU_Rx.slx', ...
    'scripts/setup/run_stampfly_imu_app.m','README.md'};
shortcutNames={'機体モデル','ログ受信機','ロガーアプリ','はじめに'};
shortcutPaths=cellfun(@(f)fullfile(root,strrep(f,'/',filesep)),shortcutFiles,'UniformOutput',false);
shortcuts=project.Shortcuts;
for k=1:numel(shortcuts)
    if ~any(strcmpi(shortcuts(k).File,shortcutPaths)),removeShortcut(project,shortcuts(k));end
end
for k=1:numel(shortcutFiles)
    shortcuts=project.Shortcuts;
    match=find(strcmpi(string({shortcuts.File}),shortcutPaths{k}),1);
    if isempty(match),shortcut=addShortcut(project,shortcutFiles{k});
    else,shortcut=shortcuts(match);end
    if ~strcmp(shortcut.Name,shortcutNames{k}),shortcut.Name=shortcutNames{k};end
    if ~strcmp(shortcut.Group,'StampFly'),shortcut.Group='StampFly';end
end
project.SimulinkCacheFolder=fullfile(root,'build','cache');
project.SimulinkCodeGenFolder=fullfile(root,'build','codegen');
project.DependencyCacheFile=fullfile(root,'build','project','dependencies.graphml');
refreshSourceControl(project);checks=runChecks(project);
fprintf('IMU_PROJECT_DEPENDENCY_SCAN\n');updateDependencies(project);
summary=struct('ID',{},'Description',{},'Passed',{},'ProblemFiles',{});
for k=1:numel(checks)
    summary(k)=struct('ID',checks(k).ID,'Description',checks(k).Description, ...
        'Passed',checks(k).Passed,'ProblemFiles',{checks(k).ProblemFiles});
end
report=struct('ProjectFile','StampFly_Official.prj','CurrentAircraft','StampFly_IMU400.slx', ...
    'CurrentReceiver','M5Stamp_IMU_Rx.slx','RegistrationComplete',true, ...
    'RegisteredFileCount',registered,'RemovedMissingEntries',{removed}, ...
    'ProjectPath',{folders},'Shortcuts',{shortcutNames},'Checks',summary, ...
    'ChecksPassed',all([checks.Passed]),'DependencyNodeCount',numnodes(project.Dependencies), ...
    'DependencyEdgeCount',numedges(project.Dependencies), ...
    'SourceControlIntegration',project.SourceControlIntegration);
writeJSON(fullfile(root,'docs','imu_project_verification.json'),report);
fprintf('IMU_PROJECT_REGISTERED: %d files, checks passed=%d\n',registered,report.ChecksPassed);
end
function path=relative(file,root)
path=char(replace(extractAfter(string(file),strlength(string(root))+1),'\','/'));
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
