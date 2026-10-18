function folder = reference_mex_folder()
%REFERENCE_MEX_FOLDER Local compiled C++ references, rebuilt when absent.
folder = fullfile(stampfly_project_root(),'build','tests','mex');
if ~isfolder(folder),mkdir(folder);end
addpath(folder);
end
