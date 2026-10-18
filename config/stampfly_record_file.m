function file = stampfly_record_file(name)
%STAMPFLY_RECORD_FILE Resolve immutable evidence stored in docs/history/records.zip.
% Use the original path from docs/history/index.json. Extraction is a local cache.
arguments
    name (1,1) string
end
root = stampfly_project_root();
name = replace(name,'\','/');
assert(~contains(name,"..") && ~startsWith(name,"/") && ~contains(name,":"), ...
    'lab:RecordName','Use a project-relative history record name.');
index = jsondecode(fileread(fullfile(root,'docs','history','index.json')));
entries = string({index.Records.Entry});
match = find(entries==name,1);
if isempty(match)
    [~,stem,extension] = fileparts(name);
    match = find(endsWith(entries,"/"+stem+extension));
end
assert(isscalar(match),'lab:RecordMissing','Record name is missing or ambiguous: %s',name);
folder = fullfile(root,'build','history','records');
file = fullfile(folder,index.Records(match).Entry);
if ~isfile(file)
    if ~isfolder(folder),mkdir(folder);end
    unzip(fullfile(root,'docs','history',index.Archive),folder);
end
assert(isfile(file),'lab:RecordExtract','Could not extract the requested record.');
end
