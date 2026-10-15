function report=finish_control_layout400(stage)
%FINISH_CONTROL_LAYOUT400 Resume the scoped control layout without re-copying.
% 分割済みの演算は変更せず、バス化の途中から小さい段階ごとに再開する。
arguments
    stage (1,1) string {mustBeMember(stage,["interface","parent","layout","save"])}
end
root=stampfly_project_root();
m='StampFly_Official_FlightTest400';
ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
assert(strcmp(get_param(m,'SimulationStatus'),'stopped'));
checkpoint=fullfile(root,'build','tests','control_layout_resume.mat');
if isfile(checkpoint),report=load(checkpoint,'report').report;else,report=struct;end
switch stage
    case "interface"
        report.Interface=finishInterface(m);
    case "parent"
        assert(isfield(report,'Interface'));
        report.Memory=groupMemory(m,report.Interface);
    case "layout"
        assert(isfield(report,'Memory'));
        report=applyLayout(m,report);
    case "save"
        assert(isfield(report,'LayoutComplete') && report.LayoutComplete);
        disp(model_read(m,'blk_2274','0'));
        disp(model_read(m,'blk_2297','0'));
        parentCheck=char(model_check(m,'blk_2274','["all"]'));
        innerCheck=char(model_check(m,'blk_2297','["all"]'));
        disp(parentCheck);disp(innerCheck);
        assert(~contains(parentCheck,'severity: error') && ~contains(innerCheck,'severity: error'));
        save_system(m,fullfile(root,[m '.slx']));
        report.SavedFile=get_param(m,'FileName');
        print(['-s' reorg.path(m,'blk_2274')],'-dpng','-r130',fullfile(root,'logs','flight_control_after_layout.png'));
        print(['-s' reorg.path(m,'blk_2297')],'-dpng','-r130',fullfile(root,'logs','takeoff_hover_after_layout.png'));
end
save(checkpoint,'report');
fprintf('CONTROL_LAYOUT_STAGE_COMPLETE: %s\n',stage);
end

function result=finishInterface(m)
scope='blk_2297';parent='blk_2274';
model_read(m,parent,'0');model_read(m,scope,'0');
[inports,outports]=reorg.ports(m,scope);
selectors={'blk_3786','blk_3787','blk_3788'};
inputIndexes={ [1 6 7 8],[2 3 4 5],[9 11 12 13 14 15 16 17],10 };
inputNames={'PilotInput','MeasuredState','FlightContext','Dt'};
fieldNames={{'Sticks','BatteryVoltage','RangeFlag','OverG'}, ...
    {'Angles','AngularRate','Height','Velocity'}, ...
    {'Branch','PreMode','FlipPhase','FlipThrust','FlipRate','FlipStart','FlipDone','FlipAngleReset'},{'Dt'}};
if numel(inports)==4 && numel(outports)==2
    % model_edit may report a transient branch-object error after completing
    % all operations. Inspect and accept only the complete healthy interface.
    disp(model_read(m,scope,'0'));check=char(model_check(m,scope,'["all"]'));disp(check);
    assert(startsWith(strtrim(check),'status: healthy'));
    assert(strcmp(get_param(reorg.path(m,inports{4}),'Name'),'Dt'));
    statusPath=find_system(reorg.path(m,scope),'SearchDepth',1,'Name','ControlStatusBus');
    assert(numel(statusPath)==1);
    result=struct('Inports',{inports},'Outports',{outports},'InputFields',{selectors}, ...
        'OutputBuses',{{reorg.id(statusPath{1})}});
else
assert(numel(inports)==17 && numel(outports)==8,'official:LayoutResume','Expected the preserved partial interface.');
links=readLinks(m,scope);
ops={reorg.configure(inports{10},struct('Name','LegacyDt'))};
for k=1:4
    ops{end+1}=reorg.configure(inports{k},struct('Name',inputNames{k},'Port',num2str(k))); %#ok<AGROW>
end
for k=1:4
    for j=1:numel(inputIndexes{k})
        if k<4,source=sprintf('%s.y%d',selectors{k},j);else,source=[inports{k} '.y1'];end
        oldIndex=inputIndexes{k}(j);
        found=links(strcmp({links.Src},inports{oldIndex}) & ~ismember({links.Dst},selectors));
        for n=1:numel(found)
            ops{end+1}=reorg.wire(source,sprintf('%s.u%d',found(n).Dst,found(n).DstPort),fieldNames{k}{j}); %#ok<AGROW>
        end
    end
end
for k=5:17,ops{end+1}=struct('op','delete','target',inports{k});end %#ok<AGROW>
ops{end+1}=reorg.configure(outports{1},struct('Name','MotorCommand','Port','1'));
ops{end+1}=reorg.configure(outports{2},struct('Name','ControlStatus','Port','2'));
ops{end+1}=reorg.wire('blk_3674.y1',[outports{1} '.u1'],'MotorCommand');
ops{end+1}=reorg.add('BusCreator','ControlStatusBus','statusBus',struct('Inputs','6'));
outputSources={'blk_3744.y1','blk_2606.y5','blk_3774.y7','blk_3774.y2','blk_3421.y1','blk_2364.y1'};
outputFields={'Diagnostics','AltitudeEnabled','FlipPhase','Reset','RateReference','Mode'};
for k=1:6,ops{end+1}=reorg.wire(outputSources{k},sprintf('#statusBus.u%d',k),outputFields{k});end %#ok<AGROW>
ops{end+1}=reorg.wire('#statusBus.y1',[outports{2} '.u1'],'ControlStatus');
for k=3:8,ops{end+1}=struct('op','delete','target',outports{k});end %#ok<AGROW>
ops{end+1}=struct('op','delete','target','blk_3743');
reply=reorg.edit(m,scope,ops);
result=struct('Inports',{inports(1:4)},'Outports',{outports(1:2)},'InputFields',{selectors}, ...
    'OutputBuses',{{reorg.created(reply,'statusBus')}});
disp(model_read(m,scope,'0'));disp(model_check(m,scope,'["all"]'));
end

% Use the original parent sources, whose SIDs have not been moved.
sources={'blk_2284.y1','blk_2281.y1','blk_2281.y2','blk_2714.y1','blk_2714.y2', ...
    'blk_2284.y6','blk_2294.y1','blk_2292.y1','blk_2290.y1','blk_2284.y7', ...
    'blk_2290.y2','blk_2291.y3','blk_2291.y4','blk_2291.y5','blk_2291.y1','blk_2291.y2','blk_2291.y6'};
ops={};
outputFields={'Diagnostics','AltitudeEnabled','FlipPhase','Reset','RateReference','Mode'};
for k=1:3
    ref=['inputBus' num2str(k)];
    ops{end+1}=reorg.add('BusCreator',['Takeoff' inputNames{k} 'Bus'],ref,struct('Inputs',num2str(numel(inputIndexes{k})))); %#ok<AGROW>
    for j=1:numel(inputIndexes{k})
        ops{end+1}=reorg.wire(sources{inputIndexes{k}(j)},sprintf('#%s.u%d',ref,j),fieldNames{k}{j}); %#ok<AGROW>
    end
    ops{end+1}=reorg.wire(['#' ref '.y1'],sprintf('%s.u%d',scope,k),inputNames{k}); %#ok<AGROW>
end
ops{end+1}=reorg.wire(sources{10},[scope '.u4'],'Dt');
ops{end+1}=reorg.add('BusSelector','ControlStatusFields','statusFields',struct('OutputSignals',strjoin(outputFields,',')));
ops{end+1}=reorg.wire([scope '.y2'],'#statusFields.u1','ControlStatus');
destinations={{'blk_2285.u6'},{'blk_2280.u1'},{'blk_2285.u5','blk_2286.u1'}, ...
    {'blk_2282.u1'},{'blk_2295.u1'},{'blk_2288.u1','blk_2285.u1'}};
for k=1:6
    for j=1:numel(destinations{k}),ops{end+1}=reorg.wire(sprintf('#statusFields.y%d',k),destinations{k}{j},outputFields{k});end %#ok<AGROW>
end
ops{end+1}=reorg.wire([scope '.y1'],'blk_2715.u1','MotorCommand');
ops{end+1}=struct('op','delete','target','blk_2289');
reply=reorg.edit(m,parent,ops);
result.StatusFields=reorg.created(reply,'statusFields');
for k=1:3,result.InputBuses{k}=reorg.created(reply,['inputBus' num2str(k)]);end
disp(model_read(m,parent,'0'));disp(model_check(m,parent,'["all"]'));
end

function result=groupMemory(m,interface)
scope='blk_2274';
status=interface.StatusFields;
inputs=[reorg.group('ControlState',arrayfun(@(x)sprintf('%s.y%d',status,x),[2 3 4 5 6],'UniformOutput',false), ...
    {'AltitudeEnabled','FlipPhase','Reset','RateReference','Mode'}), ...
    reorg.group('SupervisorReset',{'blk_2290.y3','blk_2290.y4','blk_2291.y7'}, ...
    {'AttitudeReset','ParkingReset','FlipAttitudeReset'})];
outputs=[reorg.group('EstimatorFeedback',{'blk_2283.y1'},{'EstimatorFeedback'}), ...
    reorg.group('PriorControl',{'blk_2288.y1','blk_2282.y1','blk_2295.y1'},{'PreviousMode','Reset','RateReference'}), ...
    reorg.group('AltitudeEnabled',{'blk_2280.y1'},{'AltitudeEnabled'})];
selected=arrayfun(@(x)['blk_' num2str(x)],[2278 2279 2280 2282 2283 2286 2288 2293 2295 2296],'UniformOutput',false);
links=readLinks(m,scope);
result=reorg.groupCopy(m,scope,scope,selected,'PreviousCycle400',inputs,outputs);
ops={};
for k=1:numel(inputs)
    ref=['input' num2str(k)];members=inputs(k).Members;
    ops{end+1}=reorg.add('BusCreator',['Previous' inputs(k).Name 'Bus'],ref,struct('Inputs',num2str(numel(members)))); %#ok<AGROW>
    for j=1:numel(members),ops{end+1}=reorg.wire(members(j).Endpoint,sprintf('#%s.u%d',ref,j),members(j).Name);end %#ok<AGROW>
    ops{end+1}=reorg.wire(['#' ref '.y1'],sprintf('%s.u%d',result.ID,k),inputs(k).Name); %#ok<AGROW>
end
reply=reorg.edit(m,scope,ops);
result.InputBuses={reorg.created(reply,'input1'),reorg.created(reply,'input2')};
result.OutputFields=reorg.outputMap(m,scope,result.ID,outputs);
ops={};
for k=1:numel(links)
    if ~ismember(links(k).Src,selected)||ismember(links(k).Dst,selected),continue;end
    endpoint=sprintf('%s.y%d',links(k).Src,links(k).SrcPort);
    source='';
    for g=1:numel(outputs)
        j=find(strcmp({outputs(g).Members.Endpoint},endpoint),1);
        if ~isempty(j),source=result.OutputFields.Groups.(outputs(g).Name).(outputs(g).Members(j).Name);break;end
    end
    assert(~isempty(source));
    ops{end+1}=reorg.wire(source,sprintf('%s.u%d',links(k).Dst,links(k).DstPort)); %#ok<AGROW>
end
for k=1:numel(selected),ops{end+1}=struct('op','delete','target',selected{k});end %#ok<AGROW>
reorg.edit(m,scope,ops);
disp(model_read(m,scope,'0'));disp(model_check(m,scope,'["all"]'));
end

function report=applyLayout(m,report)
% Explicitly requested layout changes affect positions and routes only.
scope='blk_2297';parent='blk_2274';
groups={'blk_3312','blk_3421','blk_3529','blk_3674','blk_3744','blk_3758',report.Memory.ID};
for k=1:numel(groups)
    Simulink.BlockDiagram.arrangeSystem(reorg.path(m,groups{k}),'FullLayout','true');
    route(m,groups{k});
end
captions={'blk_3312','高度・鉛直速度の制御';'blk_3421','姿勢角から角速度指令'; ...
    'blk_3529','3軸の角速度制御';'blk_3674','4モーター配分・制限'; ...
    'blk_3744','記録用の制御診断';'blk_3758','制御の実行・リセット'};
ops=captionOps(captions);
ops{end+1}=reorg.configure('blk_3307',struct('MaskDisplay',jtext( ...
    '離陸・ホバリング制御（400 Hz / 2.5 ms）', ...
    '上段：高度 → 鉛直速度 → 共通推力。中段：姿勢角 → 角速度 → 3軸トルク → 4モーター。', ...
    '下段：飛行モード・実行条件・前周期の推力・診断。各PIDはサブシステム内で個別に編集できます。'), ...
    'MaskIconFrame','off','FontSize','14','ShowName','off'));
ops{end+1}=reorg.configure('blk_2606',struct('AttributesFormatString','離陸・高度指令・着陸'));
ops{end+1}=reorg.configure('blk_2364',struct('AttributesFormatString','飛行モードの確定'));
ops{end+1}=struct('op','delete','target','blk_2367');
reorg.edit(m,scope,ops);
items={ ...
    'blk_2298',[30 240 60 260];'blk_2299',[30 510 60 530]; ...
    'blk_2300',[30 790 60 810];'blk_2301',[30 1150 60 1170]; ...
    'blk_3786',[190 170 200 340];'blk_3787',[190 440 200 610];'blk_3788',[190 680 200 1010]; ...
    'blk_2606',[480 170 730 410];'blk_2364',[480 660 730 870]; ...
    'blk_3758',[1040 760 1320 950];'blk_3312',[1600 180 1900 390]; ...
    'blk_3421',[1600 560 1900 770];'blk_3529',[2230 560 2530 770]; ...
    'blk_3674',[2850 310 3150 500];'blk_3744',[2850 900 3150 1090]; ...
    'blk_3775',[480 1080 700 1140];'blk_2705',[920 1110 1040 1150]; ...
    report.Interface.OutputBuses{1},[3280 750 3290 1080]; ...
    'blk_2706',[3460 385 3490 405];'blk_2707',[3460 905 3490 925]; ...
    'blk_3307',[30 20 3490 125]};
place(m,items);
groupBuses(m,'blk_3312',{'blk_3417','blk_3418','blk_3419'});
groupBuses(m,'blk_3421',{'blk_3527','blk_3528'});
groupBuses(m,'blk_3529',{'blk_3673'});
groupBuses(m,'blk_3674',{'blk_3741','blk_3742'});
groupBuses(m,'blk_3744',{'blk_3755','blk_3756','blk_3757'});
groupBuses(m,'blk_3758',{'blk_3771','blk_3772','blk_3773'});
route(m,scope);

ops=captionOps({'blk_2297','離陸・ホバリング制御';report.Memory.ID,'前周期の状態とリセット'});
ops{end+1}=reorg.configure(report.Memory.ID,struct('Description', ...
    '元のUnit Delayと型変換をそのまま保持。モード、リセット、角速度指令を元と同じ1周期遅延で返します。'));
ops{end+1}=reorg.configure('blk_3298',struct('MaskDisplay',jtext( ...
    '飛行制御（400 Hz / 2.5 ms）', ...
    '左：推定値・操作入力。中央：Stateflowの飛行モードとFlip → 離陸・ホバリング制御。', ...
    '右下：前周期の状態を保持し、推定器とモード判断へ直接フィードバックします。'), ...
    'MaskIconFrame','off','FontSize','14','ShowName','off'));
ops{end+1}=reorg.configure('blk_2290',struct('AttributesFormatString','通信・ボタン・飛行モード'));
ops{end+1}=reorg.configure('blk_2291',struct('AttributesFormatString','Flipのフェーズ遷移'));
reorg.edit(m,parent,ops);
items={ ...
    'blk_2275',[30 310 60 330];'blk_2276',[30 510 60 530];'blk_2277',[30 780 60 800]; ...
    'blk_2281',[210 270 220 370];'blk_2714',[210 470 220 570];'blk_2284',[210 660 220 1050]; ...
    'blk_2294',[450 1070 530 1110];'blk_2292',[450 1160 530 1200]; ...
    'blk_2290',[590 190 850 440];'blk_2291',[590 660 850 970]; ...
    report.Interface.InputBuses{1},[1080 1010 1090 1180]; ...
    report.Interface.InputBuses{2},[1080 370 1090 550]; ...
    report.Interface.InputBuses{3},[1250 650 1260 990]; ...
    'blk_2297',[1510 370 1850 690];report.Interface.StatusFields,[2020 710 2030 1010]; ...
    'blk_2285',[2510 610 2520 920];'blk_2715',[2740 450 2770 470]; ...
    'blk_2716',[2740 755 2770 775];'blk_2717',[2740 1240 2770 1260]; ...
    report.Memory.ID,[2170 1190 2450 1410];'blk_2287',[920 980 940 1000]; ...
    'blk_3298',[30 20 2770 125]};
place(m,items);groupBuses(m,report.Memory.ID,report.Memory.InputBuses);route(m,parent);
report.LayoutComplete=true;
open_system(reorg.path(m,parent));
end

function ops=captionOps(items)
ops={};
for k=1:size(items,1)
    ops{end+1}=reorg.configure(items{k,1},struct('Mask','on','MaskDisplay', ...
        jtext(items{k,2},'ダブルクリックで内部を編集'),'MaskIconOpaque','opaque', ...
        'ShowPortLabels','FromPortBlockName','FontSize','13','ShowName','on')); %#ok<AGROW>
end
end
function place(m,items)
for k=1:size(items,1)
    set_param(reorg.path(m,items{k,1}),'Position',items{k,2});
end
end
function groupBuses(m,group,busIds)
ports=get_param(reorg.path(m,group),'PortHandles');
for k=1:numel(ports.Inport)
    ln=get_param(ports.Inport(k),'Line');if ln<0,continue;end
    source=get_param(ln,'SrcPortHandle');p=get_param(source,'Parent');
    if ismember(reorg.id(p),busIds)
        q=get_param(ports.Inport(k),'Position');n=str2double(get_param(p,'Inputs'));h=max(60,n*25);
        set_param(p,'Position',[q(1)-180 q(2)-h/2 q(1)-170 q(2)+h/2]);
    end
end
for k=1:numel(ports.Outport)
    ln=get_param(ports.Outport(k),'Line');if ln<0,continue;end
    dst=get_param(ln,'DstPortHandle');dst=dst(dst>0);
    for j=1:numel(dst)
        p=get_param(dst(j),'Parent');
        if strcmp(get_param(p,'BlockType'),'BusSelector')
            q=get_param(ports.Outport(k),'Position');n=numel(strsplit(get_param(p,'OutputSignals'),','));h=max(60,n*25);
            set_param(p,'Position',[q(1)+100 q(2)-h/2 q(1)+110 q(2)+h/2]);
        end
    end
end
end
function route(m,scope)
lines=find_system(reorg.path(m,scope),'SearchDepth',1,'FindAll','on','Type','line');
if ~isempty(lines),Simulink.BlockDiagram.routeLine(lines);end
end
function result=jtext(varargin)
value=strjoin(varargin,newline);value=strrep(strrep(value,"'","''"),newline,'\n');
result=['disp(''' char(value) ''')'];
end

function links=readLinks(m,scope)
parent=reorg.path(m,scope);blocks=find_system(parent,'SearchDepth',1,'Type','Block');
links=struct('Src',{},'SrcPort',{},'Dst',{},'DstPort',{});
for k=1:numel(blocks)
    if strcmp(blocks{k},parent),continue;end
    handles=get_param(blocks{k},'PortHandles');
    for j=1:numel(handles.Inport)
        ln=get_param(handles.Inport(j),'Line');if ln<0,continue;end
        src=get_param(ln,'SrcPortHandle');if src<0,continue;end
        links(end+1)=struct('Src',reorg.id(get_param(src,'Parent')),'SrcPort',get_param(src,'PortNumber'), ...
            'Dst',reorg.id(blocks{k}),'DstPort',j); %#ok<AGROW>
    end
end
end
