function report=finalize_horizontal_settings()
%FINALIZE_HORIZONTAL_SETTINGS 机上観測の下限とログの日本語説明を保存します。
% 高さ8 cm以上を観測に使用します。飛行補助の開始高度や7 PIDは変えません。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
reorg.edit(m,'blk_4274',{reorg.configure('blk_4298',struct('MinHeightM','0.08', ...
    'Description','光学フロー・生角速度を同じ20 ms区間で集計し、ToF・姿勢・鉛直速度で床面へ投影します。投影高さ8 cm以上を観測し、品質・鮮度・傾き・速度の異常時は無効とします。局所Xは基準機首、Yは右です。'))});
reorg.edit(m,'root',{reorg.configure('blk_2963',struct('Description', ...
    '全ログ入力を50 Hzで同時に保存し、400 Hzタスク内で指令補足を2.5 ms後、センサー補足を5 ms後、通常ログを10 ms後に作成・送信します。水平補足は7.5 ms後です。保存時刻・Sequence・項目順・型・CRCで対応づけます。Channelは操縦受信・ログ受信機と同じ専用CHです。'))});
set_param(m,'SimulationCommand','update');
assert(slResolve(get_param(reorg.path(m,'blk_4298'),'MinHeightM'),m)==.08);
assert(numel(find_system(m,'LookUnderMasks','all','Name','DedicatedPID'))==7);
for scope={'blk_4274','blk_2963','root'}
    reply=char(model_check(m,scope{1},'["unconnected_ports","unconnected_lines"]'));
    disp(reply);assert(~contains(reply,'severity: error')&&~contains(reply,'status: error'));
end
save_system(m);
report=struct('Passed',true,'ObservationMinHeightM',.08,'AssistStartHeightM',.2, ...
    'LandingDisengageHeightM',.15,'PIDCount',7,'CaptureToSendDelayMs',[10 2.5 5]);
fid=fopen(fullfile(root,'docs','horizontal_final_settings.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
telemetry=jsondecode(fileread(fullfile(root,'docs','horizontal_telemetry_structure.json')));
telemetry.CaptureToSendDelayMs=report.CaptureToSendDelayMs;
fid=fopen(fullfile(root,'docs','horizontal_telemetry_structure.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(telemetry,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_FINAL_SETTINGS_SAVED\n');
end
