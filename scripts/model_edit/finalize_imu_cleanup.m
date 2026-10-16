function finalize_imu_cleanup()
%FINALIZE_IMU_CLEANUP 全体更新で確認した周期と不要な表示階層を修正する。
root=stampfly_project_root();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));init_imu_flight();
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
% System クラス変更で既定値へ戻った呼び出し周期を、元の 2.5 ms にそろえる。
reorg.edit(m,'blk_3178',{reorg.configure('blk_4187',struct('SampleTime','Official.Step'))});
% 出力のない Demux と終端だけの階層は、入力の終端 1 個で表す。
p=reorg.path(m,'blk_3852');
assert(strcmp(get_param(p,'TreatAsAtomicUnit'),'off'));
assert(isempty(find_system(p,'SearchDepth',1,'BlockType','Outport')));
edges=reorg.links(m,'blk_3822');input=edges(strcmp({edges.Dst},'blk_3852'));
assert(numel(input)<=1);
ops={struct('op','delete','target','blk_3852')};
if ~isempty(input)
    ops=[ops {reorg.add('Terminator','UnusedStickFields','unused', ...
        struct('Description','この処理で使用しないスティック全体を終端します。操縦指令は別の経路で制御に渡します。')), ...
        reorg.wire(sprintf('%s.y%d',input.Src,input.SrcPort),'#unused.u1')}];
end
reorg.edit(m,'blk_3822',ops);
% センサー名末尾に残った区切り文字も整える。
blocks=find_system(m,'LookUnderMasks','all','BlockType','MATLABSystem','System','stampfly.BMI270IMU');
assert(isscalar(blocks));parent=reorg.id(get_param(blocks{1},'Parent'));
reorg.edit(m,parent,{reorg.configure(reorg.id(blocks{1}),struct('Name','BMI270'))});
set_param(m,'SimulationCommand','update');
fprintf('IMU_CLEANUP_MODEL_UPDATE_PASSED\n');
for scope={'root','blk_3178','blk_3822'}
    disp(model_check(m,scope{1},'["all"]'));
end
save_system(m);
end
