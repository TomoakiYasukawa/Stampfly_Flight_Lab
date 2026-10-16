function paths=configure_stampfly_project()
%CONFIGURE_STAMPFLY_PROJECT Resolve copied code and keep derived files in build.
% モデル・アプリを開くときに呼び出す。機器への接続や書き込みは行わない。
root=fileparts(fileparts(mfilename('fullpath')));
folders={root,fullfile(root,'config'),fullfile(root,'code'), ...
    fullfile(root,'libraries'),fullfile(root,'tests','models'), ...
    fullfile(root,'scripts','setup'),fullfile(root,'scripts','build'), ...
    fullfile(root,'scripts','verification'),fullfile(root,'scripts','analysis'), ...
    fullfile(root,'scripts','model_edit')};
existing=folders(cellfun(@isfolder,folders));
addpath(existing{:});
cacheFolder=fullfile(root,'build','cache');
codegenFolder=fullfile(root,'build','codegen');
% InitFcn also runs during slbuild. Keep the build's already-selected folders:
% changing file generation settings while a build is active is not allowed.
current=Simulink.fileGenControl('getConfig');
buildFolder=replace(string(fullfile(root,'build')),'\','/');
cacheCurrent=replace(string(current.CacheFolder),'\','/');
codegenCurrent=replace(string(current.CodeGenFolder),'\','/');
insideCache=strcmpi(cacheCurrent,buildFolder) || startsWith(cacheCurrent,buildFolder+"/",'IgnoreCase',true);
insideCodegen=strcmpi(codegenCurrent,buildFolder) || startsWith(codegenCurrent,buildFolder+"/",'IgnoreCase',true);
if ~(insideCache && insideCodegen)
    Simulink.fileGenControl('set','CacheFolder',cacheFolder, ...
        'CodeGenFolder',codegenFolder,'createDir',true);
else
    cacheFolder=current.CacheFolder;
    codegenFolder=current.CodeGenFolder;
end
paths=struct('ProjectFolder',string(root),'ModelsFolder',string(root), ...
    'LibraryFolder',string(fullfile(root,'libraries')),'CacheFolder',string(cacheFolder), ...
    'CodeGenFolder',string(codegenFolder));
end
