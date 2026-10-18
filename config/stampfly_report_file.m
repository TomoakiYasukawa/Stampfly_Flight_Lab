function file = stampfly_report_file(name)
%STAMPFLY_REPORT_FILE Keep new verification output under build/reports.
arguments
    name (1,1) string
end
[~,stem,extension] = fileparts(name);
assert(strlength(stem)>0 && ~contains(stem,".."),'lab:ReportName','Invalid report name.');
folder = fullfile(stampfly_project_root(),'build','reports');
if ~isfolder(folder),mkdir(folder);end
file = fullfile(folder,stem+extension);
end
