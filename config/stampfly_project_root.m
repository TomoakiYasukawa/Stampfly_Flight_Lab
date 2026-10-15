function root=stampfly_project_root()
%STAMPFLY_PROJECT_ROOT Locate this checkout independently of the current folder.
root=fileparts(fileparts(mfilename('fullpath')));
end
