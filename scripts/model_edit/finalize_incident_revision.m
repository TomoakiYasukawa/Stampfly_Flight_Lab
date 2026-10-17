function report=finalize_incident_revision()
%FINALIZE_INCIDENT_REVISION 概要：時刻リセット診断を含むビルドの識別値を更新。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
reorg.edit(m,'blk_2963',{reorg.configure('blk_3995',struct('FirmwareRevision','uint32(1802)')), ...
    reorg.configure('blk_4339',struct('Description', ...
        '50 Hzログと同じ時刻の水平診断を保存し、15 ms後にCRC作成、17.5 ms後に送信します。他のログ計算と重ならない400 Hz周期へ分散します。'))});
set_param(m,'SimulationCommand','update');save_system(m);
report=struct('Passed',true,'FirmwareRevision',1802,'ResetReasonTelemetry',true, ...
    'WatchdogDisabled',false,'HorizontalPackPhase',6,'HorizontalSendPhase',7,'Flashed',false);
fid=fopen(fullfile(root,'docs','incident_revision_settings.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('INCIDENT_REVISION_SAVED\n');
end
