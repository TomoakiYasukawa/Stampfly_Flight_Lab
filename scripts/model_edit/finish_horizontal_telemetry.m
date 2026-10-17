function report=finish_horizontal_telemetry()
%FINISH_HORIZONTAL_TELEMETRY System変更後の識別値・CHを保存し、設定を確認。
% MATLAB Systemのクラス変更ではダイアログ値が既定値へ戻るため明示します。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
assert(strcmp(get_param(reorg.path(m,'blk_3995'),'System'),'horizontal.TelemetryPacker'));
assert(strcmp(get_param(reorg.path(m,'blk_3996'),'System'),'horizontal.TelemetryTransport'));
pilot=find_system(m,'LookUnderMasks','all','BlockType','MATLABSystem','System','basic.Joystick400');assert(isscalar(pilot));
channel=slResolve(get_param(pilot{1},'Channel'),m);
reorg.edit(m,'blk_2963',{ ...
    reorg.configure('blk_3995',struct('BuildID','uint32(1401)','FirmwareRevision','uint32(1801)')), ...
    reorg.configure('blk_3996',struct('Channel',sprintf('uint8(%d)',channel)))});
assert(slResolve(get_param(reorg.path(m,'blk_3995'),'FirmwareRevision'),m)==uint32(1801));
assert(slResolve(get_param(reorg.path(m,'blk_3996'),'Channel'),m)==channel);
set_param(m,'SimulationCommand','update');save_system(m);
report=struct('Passed',true,'BuildID',1401,'FirmwareRevision',1801,'RadioChannel',double(channel));
fprintf('HORIZONTAL_TELEMETRY_PARAMETERS_SAVED\n');
end
