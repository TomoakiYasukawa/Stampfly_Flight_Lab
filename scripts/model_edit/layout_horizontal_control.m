function report=layout_horizontal_control()
%LAYOUT_HORIZONTAL_CONTROL 水平補助を加えた図を整列し、演算・接続不変を確認。
% ユーザーから指定された可読性整理です。PIDと実行条件は変更しません。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
before=reorg.semanticSnapshot(m);
scopes={'blk_4274','blk_4316','blk_3421','blk_2297','blk_2274','blk_2963'};
for k=1:numel(scopes)
    p=reorg.path(m,scopes{k});
    blocks=find_system(p,'SearchDepth',1,'LookUnderMasks','all','Type','Block');
    for j=1:numel(blocks)
        b=blocks{j};if strcmp(b,p),continue;end
        if strcmp(get_param(b,'BlockType'),'SubSystem') && strcmp(get_param(b,'Mask'),'on')
            ports=get_param(b,'PortHandles');position=get_param(b,'Position');
            width=max(300,position(3)-position(1));height=max(90,35*max(numel(ports.Inport),numel(ports.Outport)));
            set_param(b,'Position',[position(1:2),position(1)+width,position(2)+height]);
        end
        if strcmp(get_param(b,'BlockType'),'MATLABSystem')
            ports=get_param(b,'PortHandles');position=get_param(b,'Position');
            set_param(b,'Position',[position(1:2),position(1)+350, ...
                position(2)+max(190,44*max(numel(ports.Inport),numel(ports.Outport))+55)]);
        end
        params=get_param(b,'ObjectParameters');
        if isfield(params,'ContentPreviewEnabled'),set_param(b,'ContentPreviewEnabled','off');end
    end
    Simulink.BlockDiagram.arrangeSystem(p,'FullLayout','true');
    % 自動配置の後にもSystemアイコンの表示幅を確保します。
    for j=1:numel(blocks)
        b=blocks{j};if strcmp(b,p),continue;end
        if strcmp(get_param(b,'BlockType'),'MATLABSystem')
            ports=get_param(b,'PortHandles');position=get_param(b,'Position');
            set_param(b,'Position',[position(1:2),position(1)+370, ...
                position(2)+max(190,44*max(numel(ports.Inport),numel(ports.Outport))+55)]);
        end
    end
    if strcmp(scopes{k},'blk_4316')
        positions={ ...
            'blk_4325',[520 170 950 430];'blk_4326',[1250 170 1670 430]; ...
            'blk_4327',[1950 150 2380 455];'blk_4341',[140 740 150 1000]; ...
            'blk_4342',[330 760 420 800];'blk_4343',[450 880 460 930]; ...
            'blk_4344',[450 980 460 1130];'blk_4345',[680 740 690 950]; ...
            'blk_4328',[1050 730 1060 990];'blk_4329',[1230 990 1310 1030]; ...
            'blk_4330',[1450 1050 1540 1090];'blk_4331',[1630 1110 1720 1150]; ...
            'blk_4332',[2460 515 2480 535];'blk_4333',[1840 1180 1900 1220]; ...
            'blk_4334',[2600 720 2610 1320]};
        for j=1:size(positions,1),set_param(reorg.path(m,positions{j,1}),'Position',positions{j,2});end
        [inputs,outputs]=reorg.ports(m,'blk_4316');
        xy={[40 70 70 90],[40 200 70 220],[40 830 70 850],[40 520 70 540]};
        for j=1:numel(inputs),set_param(reorg.path(m,inputs{j}),'Position',xy{j});end
        set_param(reorg.path(m,outputs{1}),'Position',[2720 250 2750 270]);
        set_param(reorg.path(m,outputs{2}),'Position',[2720 1000 2750 1020]);
    end
    lines=find_system(p,'FindAll','on','SearchDepth',1,'Type','line');
    if ~isempty(lines),Simulink.BlockDiagram.routeLine(lines);end
end
% 最上位は主経路を左→右、センサー・観測とSupervisorを別の行へ置きます。
positions={ ...
    'blk_3161',[40 390 350 500];'blk_3178',[40 640 350 765]; ...
    'blk_3171',[40 870 350 960];'blk_3198',[40 1100 350 1190]; ...
    'blk_2721',[650 400 1000 645];'blk_2231',[1340 350 1730 620]; ...
    'blk_4274',[2040 320 2460 710];'blk_2274',[2770 355 3210 650]; ...
    'blk_3265',[3520 405 3860 555];'blk_3294',[3990 450 4010 470]; ...
    'blk_3295',[3990 510 4010 530];'blk_4169',[40 210 330 290]; ...
    'blk_3131',[680 780 1050 960];'blk_3213',[1220 1000 1600 1250]; ...
    'blk_4167',[1730 955 1740 1135];'blk_4166',[1950 990 2380 1330]; ...
    'blk_4168',[2530 1040 2540 1330];'blk_4163',[3350 950 3360 1100]; ...
    'blk_3979',[40 1480 380 1580];'blk_3983',[40 1740 380 1840]; ...
    'blk_4038',[710 1450 1090 1710];'blk_2963',[1440 1580 1770 1710]; ...
    'blk_3011',[2040 1600 2350 1700];'blk_3049',[2620 1600 2930 1720]; ...
    'blk_3121',[3200 1600 3510 1720];'blk_3073',[3780 1600 4110 1720]; ...
    'blk_726',[4240 1640 4270 1660]};
for k=1:size(positions,1),set_param(reorg.path(m,positions{k,1}),'Position',positions{k,2});end
% 公開Gotoを信号源の近く、Fromを使用先の近くへ置きます。
tags=find_system(m,'SearchDepth',1,'BlockType','Goto');
for k=1:numel(tags)
    ports=get_param(tags{k},'PortHandles');line=get_param(ports.Inport,'Line');if line<0,continue;end
    source=get_param(line,'SrcPortHandle');if source<0,continue;end
    block=get_param(source,'Parent');xy=get_param(source,'Position');base=get_param(block,'Position');
    set_param(tags{k},'Position',[base(3)+100,xy(2)-10,base(3)+260,xy(2)+10]);
end
% 新しいContext生成は推定器の左下へまとめます。
set_param(reorg.path(m,'blk_4300'),'Position',[1820 840 1830 940]);
set_param(reorg.path(m,'blk_4301'),'Position',[1590 900 1630 930]);
set_param(reorg.path(m,'blk_4302'),'Position',[1480 920 1530 950]);
lines=find_system(m,'FindAll','on','SearchDepth',1,'Type','line');
Simulink.BlockDiagram.routeLine(lines);
after=reorg.semanticSnapshot(m);assert(isequaln(before,after),'horizontal:LayoutSemantics','Layout changed model semantics.');
folder=fullfile(root,'docs','images','horizontal');if ~isfolder(folder),mkdir(folder);end
for scope=[{'root'},scopes]
    p=m;if ~strcmp(scope{1},'root'),p=reorg.path(m,scope{1});end
    print(['-s' p],'-dpng','-r110',fullfile(folder,['layout_' scope{1} '.png']));
end
set_param(m,'SimulationCommand','update');save_system(m);
report=struct('Passed',true,'SemanticSnapshotEqual',true,'Scopes',{[{'root'},scopes]});
fid=fopen(fullfile(root,'docs','horizontal_layout_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_LAYOUT_SEMANTICS_VERIFIED\n');
end
