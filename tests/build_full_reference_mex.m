function folder = build_full_reference_mex()
%BUILD_FULL_REFERENCE_MEX Compile the preserved official full-loop oracle.
root = stampfly_project_root();
ref = fullfile(root,'tests','reference');
folder = reference_mex_folder();
if ~isfile(fullfile(folder,['official_full_reference.' mexext]))
    mex('-R2018a','COMPFLAGS=$COMPFLAGS /utf-8 /wd4305 /wd4244', ...
        ['-I' ref],['-I' fullfile(root,'official_sources','M5StampFly','src')], ...
        fullfile(ref,'official_full_reference.cpp'),fullfile(ref,'pid_reference.cpp'), ...
        '-outdir',folder,'-output','official_full_reference');
end
end
