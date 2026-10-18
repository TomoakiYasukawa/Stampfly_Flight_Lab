function report=verify_horizontal_behavior()
%VERIFY_HORIZONTAL_BEHAVIOR 保存した実制御ブロックをGherkin仕様で確認する。
root=stampfly_project_root();init_imu_flight();ensure_simulink_toolkit();
[~,~,~,~,motion,context]=horizontal.fixture();
assignin('base','HorizontalTestMotion',motion);assignin('base','HorizontalTestContext',context);
folder=fullfile(root,'tests','models');addpath(folder);
if bdIsLoaded('HorizontalControllerTest'),close_system('HorizontalControllerTest',0);end
oldFolder=pwd;restoreFolder=onCleanup(@()cd(oldFolder)); %#ok<NASGU>
cd(folder);
open_system(fullfile(folder,'HorizontalControllerTest.slx'));
set_param('HorizontalControllerTest','SimulationCommand','update');
reply=char(model_test('HorizontalControllerTest.slx',fullfile(root,'tests','horizontal_controller.feature'), ...
    '[]','true','false','none'));
disp(reply);fid=fopen(fullfile(root,'build','horizontal_control','behavior_tests.txt'),'w','n','UTF-8');
assert(fid>=0);fprintf(fid,'%s\n',reply);fclose(fid);
assert(~contains(reply,'FAILED scenario:')&&~contains(reply,'FAILED Assessment:')&& ...
    isempty(regexp(reply,'status\s*:\s*error','once'))&&contains(reply,'Summary: 4 passed')&& ...
    contains(reply,'16 passed, 0 failed, 0 untested'), ...
    'horizontal:Behavior','%s',reply);
report=struct('Passed',true,'ActualSavedBlocks',true,'DraftMode',false, ...
    'ScenarioCount',4,'AssessmentCount',16,'Output',reply);
save(fullfile(root,'build','horizontal_control','behavior_verification.mat'),'report');
fid=fopen(stampfly_report_file('docs/horizontal_behavior_verification.json'),'w','n','UTF-8');
assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_BEHAVIOR_VERIFICATION_PASSED\n');
end
