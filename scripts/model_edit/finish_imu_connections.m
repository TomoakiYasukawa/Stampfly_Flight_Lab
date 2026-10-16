function finish_imu_connections()
%FINISH_IMU_CONNECTIONS PIDラッパー削除後に残った未使用信号を整理する。
root=stampfly_project_root();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
model='StampFly_IMU400';open_system(fullfile(root,[model '.slx']));init_imu_flight();
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(model); %#ok<NASGU>
for id={'blk_3415','blk_3672'}
    p=reorg.path(model,id{1});ports=get_param(p,'PortHandles');
    fields=strsplit(get_param(p,'OutputSignals'),',');
    if strcmp(fields{end},'PreviousError')
        assert(get_param(ports.Outport(end),'Line')<0);
        selected=strjoin(fields(1:end-1),',');
        reorg.edit(model,reorg.id(get_param(p,'Parent')), ...
            {reorg.configure(id{1},struct('OutputSignals',selected, ...
                'Description',['制御の実行・リセット条件と実測 dt を選びます。' ...
                'DedicatedPID 内部で前回誤差を保持するため、未使用の PreviousError は取り出しません。']))});
    end
end
% 旧PIDへ渡していた2成分の初期誤差は、今は専用PID内で管理する。
p=reorg.path(model,'blk_3432');ports=get_param(p,'PortHandles');
assert(all(arrayfun(@(h)get_param(h,'Line')<0,ports.Outport)));
edges=reorg.links(model,'blk_3421');edge=edges(strcmp({edges.Dst},'blk_3432'));assert(isscalar(edge));
reorg.edit(model,'blk_3421',{struct('op','delete','target','blk_3432'), ...
    reorg.add('Terminator','UnusedInitialErrors','unusedErrors',struct('Description', ...
        '操縦指令の既存関数が返す初期誤差を終端します。DedicatedPID の Reset により内部誤差を管理します。')), ...
    reorg.wire(sprintf('%s.y%d',edge.Src,edge.SrcPort),'#unusedErrors.u1')});
% レート保持後も診断バスの項目名を保ち、無名signalNを作らない。
reorg.edit(model,'blk_3073',{ ...
    reorg.configure('blk_4203.y1 -> blk_4206.u13',struct('Name','RadioQueued')), ...
    reorg.configure('blk_4204.y1 -> blk_4206.u14',struct('Name','LEDMode')), ...
    reorg.configure('blk_4205.y1 -> blk_4206.u18',struct('Name','JoyTelemetrySent'))});
set_param(model,'SimulationCommand','update');
save_system(model);fprintf('IMU_CLEANUP_UNUSED_CONNECTIONS_REMOVED\n');
end
