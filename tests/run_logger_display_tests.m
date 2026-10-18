function report = run_logger_display_tests()
%RUN_LOGGER_DISPLAY_TESTS Verify the app without connecting any serial device.
root = fileparts(fileparts(mfilename('fullpath')));
originalFolder = pwd;
restoreFolder = onCleanup(@()cd(originalFolder)); %#ok<NASGU>
cd(root);
addpath(fullfile(root,'config'));
configure_stampfly_project();
results = runtests(fullfile(root,'tests','DataLoggerDisplayTest.m'));
report = struct('Tests',numel(results),'Passed',nnz([results.Passed]), ...
    'Failed',nnz([results.Failed]),'Incomplete',nnz([results.Incomplete]), ...
    'ExpectedBuildID',1401,'ReceiveRatesHz',[25 50 400], ...
    'WindowSeconds',10,'SerialConnectionsOpened',0);
report.Cases = {results.Name};
if ~isfolder(fullfile(root,'build','tests')),mkdir(fullfile(root,'build','tests'));end
save(fullfile(root,'build','tests','logger_display_results.mat'),'results','report');
fid = fopen(stampfly_report_file('docs/logger_display_verification.json'),'w','n','UTF-8');
fileCleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
disp(report);
assert(report.Failed==0 && report.Incomplete==0,'imu:DisplayRegression', ...
    'Logger display tests failed.');
end
