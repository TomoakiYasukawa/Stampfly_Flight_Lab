function report = register_stampfly_project()
%REGISTER_STAMPFLY_PROJECT Refresh metadata in an isolated copy without Git.
% MATLAB's project removeFile/addFile can stage changes when Git is enabled.
% Use tools/create_distribution_check.py and a separate MATLAB session for
% Git projects; copy only the closed copy's resources/project metadata back.
root = stampfly_project_root();
ancestor = root;
while true
    assert(~isfolder(fullfile(ancestor,'.git')) && ~isfile(fullfile(ancestor,'.git')), ...
        'lab:GitRegistration','Refresh registration in an isolated Git-free copy; see docs/development.md.');
    parent = fileparts(ancestor);
    if strcmp(parent,ancestor),break;end
    ancestor = parent;
end
try, project = currentProject(); catch, project = []; end
if isempty(project) || ~strcmpi(project.RootFolder,root)
    project = matlab.project.loadProject(fullfile(root,'StampFly_Lab.prj'));
end
assert(~contains(string(project.SourceControlIntegration),'Git','IgnoreCase',true), ...
    'lab:GitRegistration','MATLAB source control must be disabled in the verification copy.');
project.Name = 'StampFly_Lab';
excluded = {'build','logs','recordings','backups','.git','.runtime_temp'};
members = project.Files;
removed = strings(0,1); removePaths = strings(0,1);
for k = 1:numel(members)
    file = string(members(k).Path);
    relative = replace(extractAfter(file,strlength(root)+1),'\','/');
    first = extractBefore(relative+"/","/");
    if (~isfile(file) && ~isfolder(file)) || any(first==string(excluded))
        removePaths(end+1)=file; removed(end+1)=relative; %#ok<AGROW>
    end
end
fprintf('STAMPFLY_LAB_REMOVE_STALE: %d entries\n',numel(removePaths));
if ~isempty(removePaths),removeFile(project,removePaths);end
members = project.Files; known = lower(string({members.Path}));
files = dir(fullfile(root,'*')); registered = 0; addPaths = strings(0,1);
for folder={'config','code','src','scripts','tests','tools','docs','archive','firmware', ...
        'libraries','third_party','official_sources','resources/stampfly_mesh'}
    files = [files; dir(fullfile(root,folder{1},'**','*'))]; %#ok<AGROW>
end
for k = 1:numel(files)
    if files(k).isdir,continue;end
    file = fullfile(files(k).folder,files(k).name);
    relative = replace(extractAfter(string(file),strlength(root)+1),'\','/');
    first = extractBefore(relative+"/","/");
    if any(first==string(excluded)) || startsWith(relative,'resources/project/') || endsWith(relative,'.prj')
        continue
    end
    if ~any(strcmpi(file,known)),addPaths(end+1)=file;end %#ok<AGROW>
    registered = registered+1;
end
fprintf('STAMPFLY_LAB_ADD_CURRENT: %d entries\n',numel(addPaths));
if ~isempty(addPaths),addFile(project,addPaths);end
folders = {'','config','code','libraries','tests','tests/models', ...
    'scripts/setup','scripts/build','scripts/verification','scripts/analysis'};
wanted = cellfun(@(f)fullfile(root,f),folders,'UniformOutput',false);
existing = string(project.PathFolders);
for k = 1:numel(existing)
    if ~any(strcmpi(existing(k),wanted)),removePath(project,existing(k));end
end
for k = 1:numel(wanted)
    existing = string(project.PathFolders);
    if isfolder(wanted{k}) && ~any(strcmpi(wanted{k},existing)),addPath(project,wanted{k});end
end
shortcutFiles = {'Stampfly_Tx.slx','M5Stamp_Rx.slx','scripts/setup/run_datalogger.m', ...
    'README.md','DataLogger_GUIDE.md'};
shortcutNames = {'機体モデル Stampfly_Tx','受信モデル M5Stamp_Rx','DataLogger', ...
    'はじめに・飛ばし方','DataLogger 操作ガイド'};
shortcuts = project.Shortcuts;
for k = 1:numel(shortcuts),removeShortcut(project,shortcuts(k));end
for k = 1:numel(shortcutFiles)
    shortcut = addShortcut(project,shortcutFiles{k});
    shortcut.Name = shortcutNames{k}; shortcut.Group = 'StampFly_Lab';
end
startupFile = fullfile(root,'config','startup.m');
if ~any(strcmpi(project.StartupFiles,startupFile)),addStartupFile(project,startupFile);end
project.SimulinkCacheFolder = fullfile(root,'build','cache');
project.SimulinkCodeGenFolder = fullfile(root,'build','codegen');
project.DependencyCacheFile = fullfile(root,'build','project','dependencies.graphml');
checks = runChecks(project);
fprintf('STAMPFLY_LAB_DEPENDENCY_SCAN\n'); updateDependencies(project);
summary = struct('ID',{},'Description',{},'Passed',{},'ProblemFiles',{});
for k = 1:numel(checks)
    summary(k) = struct('ID',checks(k).ID,'Description',checks(k).Description, ...
        'Passed',checks(k).Passed,'ProblemFiles',{checks(k).ProblemFiles});
end
report = struct('ProjectFile','StampFly_Lab.prj','ProjectName',project.Name, ...
    'CurrentAircraft','Stampfly_Tx.slx','CurrentReceiver','M5Stamp_Rx.slx', ...
    'App','DataLogger.m','RegisteredFileCount',registered,'RemovedEntries',removed, ...
    'ProjectPath',{folders},'Checks',summary,'ChecksPassed',all([checks.Passed]), ...
    'DependencyNodeCount',numnodes(project.Dependencies), ...
    'DependencyEdgeCount',numedges(project.Dependencies), ...
    'SourceControlIntegration',string(project.SourceControlIntegration),'GitCommandsExecuted',false);
fid = fopen(stampfly_report_file('project_registration.json'),'w','n','UTF-8');assert(fid>=0);
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
fprintf('STAMPFLY_LAB_REGISTERED: %d files, checks passed=%d\n',registered,report.ChecksPassed);
end
