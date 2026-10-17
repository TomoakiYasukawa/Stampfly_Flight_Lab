function report=finish_incident_layout()
%FINISH_INCIDENT_LAYOUT 概要：単位換算と待機リセットを見やすく配置します。
% 入力・出力・実行周期は変えず、singleで使う定数の型を明示します。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
disp(model_read(m,'blk_2231','1'));
reorg.edit(m,'blk_2231',{reorg.configure('blk_4348',struct('Gain','single(9.80665)')), ...
    reorg.configure('blk_4352',struct('Gain','single(1/9.80665)'))},'incremental');
before=reorg.semanticSnapshot(m);
p=reorg.path(m,'blk_2231');Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
lines=find_system(p,'FindAll','on','SearchDepth',1,'Type','line');
if ~isempty(lines),Simulink.BlockDiagram.routeLine(lines);end
assert(isequaln(before,reorg.semanticSnapshot(m)),'vertical:LayoutChanged','配置整理で演算・接続が変化しました。');
set_param(m,'SimulationCommand','update');
check=char(model_check(m,'blk_2231','["unconnected_ports","unconnected_lines"]'));disp(check);
assert(~contains(check,'severity: error')&&~contains(check,'status: error'));
save_system(m);
folder=fullfile(root,'docs','images','horizontal');if ~isfolder(folder),mkdir(folder);end
print(['-s' p],'-dpng','-r110',fullfile(folder,'layout_blk_2231.png'));
report=struct('Passed',true,'SemanticLayoutUnchanged',true,'GainConstantsSingle',true);
fid=fopen(fullfile(root,'docs','incident_layout_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('INCIDENT_LAYOUT_VERIFIED\n');
end
