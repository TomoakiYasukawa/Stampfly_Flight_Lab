function finish_imu_display()
%FINISH_IMU_DISPLAY 診断の項目名と、残ったサブシステム表示をそろえる。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
model='StampFly_IMU400';open_system(fullfile(root,[model '.slx']));init_imu_flight();
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(model); %#ok<NASGU>
reorg.edit(model,'blk_3073',{ ...
    reorg.configure('blk_4203.y1 -> blk_4206.u13',struct('Name','RadioQueued')), ...
    reorg.configure('blk_4204.y1 -> blk_4206.u14',struct('Name','LEDMode')), ...
    reorg.configure('blk_4205.y1 -> blk_4206.u18',struct('Name','JoyTelemetrySent'))});
save_system(model);layout_imu_cleanup();
end
