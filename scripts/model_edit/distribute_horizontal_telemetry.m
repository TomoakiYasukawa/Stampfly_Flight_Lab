function report=distribute_horizontal_telemetry()
%DISTRIBUTE_HORIZONTAL_TELEMETRY ログ3種を50 Hzの保存時刻を保って分散する。
% PID・Supervisorの処理は変更せず、ログ枝のSystemブロックだけを設定します。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
beforePID=pidSnapshot(m);
reorg.edit(m,'blk_2963',{ ...
    reorg.configure('blk_3995',struct('System','horizontal.TelemetryPacker', ...
    'Description','50 Hzで全ログ入力を同時に保存し、SFI8・SFIX・SFIYを別の400 Hz周期で作成します。保存時刻・Sequence・項目順・型・CRCは従来と同じです。')), ...
    reorg.configure('blk_3996',struct('System','horizontal.TelemetryTransport', ...
    'Description','完成した通常・指令・センサー補足を一度ずつ別周期でESP-NOW/USBキューへ送ります。Channelは操縦受信・ログ受信機と同じ専用CHです。'))});
% BusSelector由来の同名信号には境界名を付けて、日本語の説明とともに読みやすくします。
bus=find_system(reorg.path(m,'blk_4274'),'SearchDepth',1,'LookUnderMasks','all', ...
    'BlockType','BusCreator','Name','InertialMotionBus');assert(isscalar(bus));
ports=get_param(bus{1},'PortHandles');names={'Quaternion','RawAngularRate','StaticOffsets', ...
    'FilteredRate','CorrectedRate','Fresh','ReadValid'};ops={};
for k=1:numel(names)
    line=get_param(ports.Inport(k),'Line');source=get_param(line,'SrcPortHandle');
    sourceID=reorg.id(get_param(source,'Parent'));sourcePort=get_param(source,'PortNumber');
    ops{end+1}=reorg.wire(sprintf('%s.y%d',sourceID,sourcePort), ...
        sprintf('%s.u%d',reorg.id(bus{1}),k),names{k}); %#ok<AGROW>
end
reorg.edit(m,'blk_4274',ops);
set_param(m,'SimulationCommand','update');assert(isequaln(beforePID,pidSnapshot(m)));
for scope={'blk_2963','blk_4274','root'}
    disp(model_read(m,scope{1},'0'));result=char(model_check(m,scope{1},'["unconnected_ports","unconnected_lines"]'));
    disp(result);assert(~contains(result,'severity: error')&&~contains(result,'status: error'));
end
save_system(m);
report=struct('Passed',true,'PIDCount',7,'PIDSettingsPreserved',true, ...
    'TaskHz',400,'PacketHz',50,'CaptureToSendDelayMs',[10 2.5 5], ...
    'Packer','horizontal.TelemetryPacker','Transport','horizontal.TelemetryTransport');
fid=fopen(fullfile(root,'docs','horizontal_telemetry_structure.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_DISTRIBUTED_TELEMETRY_SAVED\n');
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
