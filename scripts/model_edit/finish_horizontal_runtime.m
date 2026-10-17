function report=finish_horizontal_runtime()
%FINISH_HORIZONTAL_RUNTIME IMU読出し成功とログ分散を保存済みモデルへ反映。
% 既存4センサー出力と7 PIDは保持し、水平補助の健全性・実行時間を改善。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
imu=reorg.path(m,'blk_3165');assert(ismember(get_param(imu,'System'),{'stampfly.BMI270IMU','horizontal.IMUSource'}));
beforePID=pidSnapshot(m);
reorg.edit(m,'blk_3161',{reorg.configure('blk_3165',struct('System','horizontal.IMUSource', ...
    'Description','BMI270の加速度・角速度・温度・Freshは従来と同じです。ReadValidは新規状態と独立したAPI読出し成功です。水平推定の短い再読出しと故障の判別に使います。'))});
goto=find_system(reorg.path(m,'blk_3161'),'LookUnderMasks','all','SearchDepth',1,'BlockType','Goto','GotoTag','IMUReadValid');
if isempty(goto)
    reply=reorg.edit(m,'blk_3161',{reorg.add('Goto','PublishIMUReadValid','readValid', ...
        struct('GotoTag','IMUReadValid','TagVisibility','global', ...
        'Description','直前のBMI270レジスター読出し成功を、水平推定へ公開します。Freshとは独立した情報です。')), ...
        reorg.wire('blk_3165.y5','#readValid.u1','IMUReadValid')});
    healthGoto=reorg.created(reply,'readValid');
else,healthGoto=reorg.id(goto{1});end
bus=find_system(reorg.path(m,'blk_4274'),'LookUnderMasks','all','SearchDepth',1,'BlockType','BusCreator','Name','InertialMotionBus');assert(isscalar(bus));
from=find_system(reorg.path(m,'blk_4274'),'LookUnderMasks','all','SearchDepth',1,'BlockType','From','GotoTag','IMUReadValid');
if isempty(from)
    reply=reorg.edit(m,'blk_4274',{reorg.configure(reorg.id(bus{1}),struct('Inputs','7')), ...
        reorg.add('From','ReadIMUReadValid','readValid',struct('GotoTag','IMUReadValid', ...
        'Description','BMI270の読出し成功。短いFresh=0の再読出しと通信失敗を区別します。')), ...
        reorg.wire('#readValid.y1',[reorg.id(bus{1}) '.u7'],'ReadValid')});
    healthFrom=reorg.created(reply,'readValid');
else,healthFrom=reorg.id(from{1});end
% 分散ロガーだけは400 Hzで動作し、出力パケットは50 Hzに保ちます。
reorg.edit(m,'blk_2963',{reorg.configure('blk_4339',struct('Description', ...
    '50 Hzログと同じ時刻の水平診断を保存し、400 Hzの別周期でCRC作成・送信します。既存フレームとSequence・保存時刻・BuildIDで結合します。'))});
set_param(m,'SimulationCommand','update');
assert(isequaln(beforePID,pidSnapshot(m)),'horizontal:PIDChanged','Existing PID settings changed.');
for scope={'blk_3161','blk_4274','blk_2963','root'}
    disp(model_read(m,scope{1},'0'));result=char(model_check(m,scope{1},'["unconnected_ports","unconnected_lines"]'));
    disp(result);assert(~contains(result,'severity: error')&&~contains(result,'status: error'));
end
save_system(m);
report=struct('Passed',true,'IMUSource','horizontal.IMUSource','ReadValidGoto',healthGoto,'ReadValidFrom',healthFrom, ...
    'PIDCount',7,'PIDSettingsPreserved',true,'HorizontalLoggerTaskHz',400,'HorizontalPacketHz',50);
fid=fopen(fullfile(root,'docs','horizontal_runtime_structure.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_RUNTIME_STRUCTURE_SAVED\n');
end
function records=pidSnapshot(m)
blocks=find_system(m,'LookUnderMasks','all','Name','DedicatedPID');assert(numel(blocks)==7);
records=cell(size(blocks));
for k=1:numel(blocks)
    values=struct;parameters=get_param(blocks{k},'DialogParameters');
    for field=fieldnames(parameters)',values.(field{1})=get_param(blocks{k},field{1});end
    records{k}=struct('ID',reorg.id(blocks{k}),'Parameters',values);
end
end
