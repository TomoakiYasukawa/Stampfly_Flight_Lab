function report = tidy_flight_control400()
%TIDY_FLIGHT_CONTROL400 Expose control loops with short, named bus connections.
% 元の演算ブロックと状態をコピーし、遅延・リセット・データ型を維持する。
root = stampfly_project_root();
model = 'StampFly_Official_FlightTest400';
scope = 'blk_2297';
ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
assert(strcmp(get_param(model,'SimulationStatus'),'stopped'));
model_read(model,'blk_2274','0');
model_read(model,scope,'0');
mapping = struct;

inputs = [ ...
    reorg.group('VerticalEstimate',eps(mapping,{'blk_2301.y1','blk_2302.y1'}),{'Height','Velocity'}), ...
    reorg.group('AltitudeCommand',eps(mapping,{'blk_2606.y1','blk_2606.y2','blk_2606.y5','blk_2606.y6'}), ...
        {'HeightReference','BaseThrust','AutoAltitude','ManualAltitude'}), ...
    reorg.group('AltitudeContext',eps(mapping,{'blk_2361.y1','blk_2361.y6','blk_2361.y4','blk_2361.y3', ...
        'blk_2361.y8','blk_2306.y1','blk_2364.y1','blk_2307.y1','blk_2705.y1'}), ...
        {'ThrustRequest','VelocityEnabled','AltitudeEnabled','Reset','FlipPhase','Branch','Mode','Dt','PreviousError'})];
outputs = [ ...
    reorg.group('Thrust',{'blk_2608.y1'},{'Thrust'}), ...
    reorg.group('VerticalReference',{'blk_2316.y1'},{'VelocityReference'}), ...
    reorg.group('ThrustState',{'blk_2609.y1','blk_2365.y1'},{'FilteredThrust','HeldThrust'})];
[report.Altitude,mapping] = pack(model,scope,ids([2315 2316 2603 2617 2618 2608 2609 2365]), ...
    'AltitudeControl400',inputs,outputs,mapping);

inputs = [ ...
    reorg.group('Angles',{'blk_2299.y1'},{'Angles'}), ...
    reorg.group('PilotAndMode',eps(mapping,{'blk_2298.y1','blk_2306.y1','blk_2309.y1', ...
        'blk_2311.y1','blk_2313.y1','blk_2606.y7'}), ...
        {'Sticks','Branch','FlipPhase','FlipRate','FlipDone','ControlMode'}), ...
    reorg.group('AttitudeContext',eps(mapping,{'blk_2361.y2','blk_2361.y3','blk_2361.y5', ...
        'blk_2361.y7','blk_2314.y1','blk_2307.y1'}), ...
        {'Run','Reset','AngleEnabled','AngleReset','FlipAngleReset','Dt'})];
outputs = [reorg.group('RateReference',{'blk_2602.y1'},{'RateReference'}), ...
    reorg.group('AngleReference',{'blk_2605.y1'},{'AngleReference'})];
[report.Attitude,mapping] = pack(model,scope,ids([2605 2359 2362 2513 2512 2514 2515 2424 2425 2602 2366 2616]), ...
    'AttitudeControl400',inputs,outputs,mapping);

inputs = [ ...
    reorg.group('RateReference',eps(mapping,{'blk_2602.y1'}),{'RateReference'}), ...
    reorg.group('MeasuredRates',{'blk_2300.y1'},{'MeasuredRates'}), ...
    reorg.group('RateContext',eps(mapping,{'blk_2361.y2','blk_2361.y3','blk_2307.y1','blk_2705.y1'}), ...
        {'Run','Reset','Dt','PreviousError'})];
outputs = [reorg.group('RollTorque',{'blk_2559.y1'},{'RollTorque'}), ...
    reorg.group('PitchTorque',{'blk_2469.y1'},{'PitchTorque'}), ...
    reorg.group('YawTorque',{'blk_2662.y1'},{'YawTorque'})];
[report.Rate,mapping] = pack(model,scope,ids([2607 2363 2558 2559 2468 2469 2661 2662]), ...
    'BodyRateControl400',inputs,outputs,mapping);

inputs = [ ...
    reorg.group('MotorEffort',eps(mapping,{'blk_2608.y1','blk_2559.y1','blk_2469.y1','blk_2662.y1'}), ...
        {'Thrust','RollTorque','PitchTorque','YawTorque'}), ...
    reorg.group('MotorContext',eps(mapping,{'blk_2361.y2','blk_2361.y3','blk_2305.y1','blk_2306.y1','blk_2307.y1','blk_2313.y1'}), ...
        {'Run','Reset','OverG','Branch','Dt','HoldApplied'})];
outputs = [reorg.group('MotorCommand',{'blk_2368.y1','blk_2368.y2'},{'Duty','Counts'}), ...
    reorg.group('BeforeLimit',{'blk_2368.y3'},{'BeforeLimit'})];
[report.Motor,mapping] = pack(model,scope,{'blk_2368'},'MotorAllocation400',inputs,outputs,mapping);

inputs = [ ...
    reorg.group('FlightCommand',eps(mapping,{'blk_2606.y1','blk_2606.y2','blk_2606.y3'}), ...
        {'HeightReference','BaseThrust','RampCounter'}), ...
    reorg.group('ControlReferences',eps(mapping,{'blk_2316.y1','blk_2608.y1','blk_2605.y1','blk_2602.y1'}), ...
        {'VelocityReference','Thrust','Angles','Rates'}), ...
    reorg.group('MotorDiagnostics',eps(mapping,{'blk_2559.y1','blk_2469.y1','blk_2662.y1','blk_2368.y3'}), ...
        {'RollTorque','PitchTorque','YawTorque','BeforeLimit'})];
outputs = reorg.group('Diagnostics',{'blk_2360.y1'},{'Diagnostics'});
[report.Diagnostics,mapping] = pack(model,scope,{'blk_2360'},'FlightDiagnostics400',inputs,outputs,mapping);

inputs = [ ...
    reorg.group('CommandMode',eps(mapping,{'blk_2606.y4','blk_2606.y6','blk_2606.y5','blk_2606.y7'}), ...
        {'RawThrust','ManualAltitude','AutoAltitude','ControlMode'}), ...
    reorg.group('ModeContext',eps(mapping,{'blk_2306.y1','blk_2307.y1','blk_2309.y1','blk_2310.y1', ...
        'blk_2312.y1','blk_2313.y1','blk_2364.y1'}), ...
        {'Branch','Dt','FlipPhase','FlipThrust','FlipStart','FlipDone','Mode'}), ...
    reorg.group('ThrustState',eps(mapping,{'blk_2609.y1','blk_2365.y1'}),{'FilteredThrust','HeldThrust'})];
outputs = [reorg.group('ThrustRequest',{'blk_2361.y1'},{'ThrustRequest'}), ...
    reorg.group('ControlContext',{'blk_2361.y2','blk_2361.y3','blk_2361.y4','blk_2361.y5','blk_2361.y6','blk_2361.y7','blk_2361.y8'}, ...
        {'Run','Reset','AltitudeEnabled','AngleEnabled','VelocityEnabled','AngleReset','FlipPhase'})];
[report.Gating,mapping] = pack(model,scope,{'blk_2361'},'ControlGating400',inputs,outputs,mapping);

% StickFields was used only by six diagnostic terminators; retain it as a group.
inputs = reorg.group('Sticks',{'blk_2298.y1'},{'Sticks'});
[report.Unused,mapping] = pack(model,scope,ids([2604 2610 2611 2612 2613 2614 2615]), ...
    'UnusedStickFields',inputs,struct('Name',{},'Members',{}),mapping);

report.Interface = bundleTakeoff(model,scope);
parentMap = report.Interface.ParentMap;
inputs = [ ...
    reorg.group('ControlState',eps(parentMap,{'blk_2297.y4','blk_2297.y5','blk_2297.y6','blk_2297.y7','blk_2297.y8'}), ...
        {'AltitudeEnabled','FlipPhase','Reset','RateReference','Mode'}), ...
    reorg.group('SupervisorReset',{'blk_2290.y3','blk_2290.y4','blk_2291.y7'}, ...
        {'AttitudeReset','ParkingReset','FlipAttitudeReset'})];
outputs = [ ...
    reorg.group('EstimatorFeedback',{'blk_2283.y1'},{'EstimatorFeedback'}), ...
    reorg.group('PriorControl',{'blk_2288.y1','blk_2282.y1','blk_2295.y1'}, ...
        {'PreviousMode','Reset','RateReference'}), ...
    reorg.group('AltitudeEnabled',{'blk_2280.y1'},{'AltitudeEnabled'})];
[report.Memory,parentMap] = pack(model,'blk_2274',ids([2278 2279 2280 2282 2283 2286 2288 2293 2295 2296]), ...
    'PreviousCycle400',inputs,outputs,parentMap);
report.ParentMap = parentMap;
report.InnerMap = mapping;

for item = {'Altitude','Attitude','Rate','Motor','Diagnostics','Gating','Memory'}
    arrangeGroup(model,report.(item{1}).ID,item{1});
end
layoutInner(model,scope,report);
layoutParent(model,report);
disp(model_read(model,'blk_2274','0'));
disp(model_read(model,scope,'0'));
disp(model_check(model,'blk_2274','["all"]'));
disp(model_check(model,scope,'["all"]'));
save_system(model);
save(fullfile(root,'build','tests','control_layout_ids.mat'),'report');
print(['-s' reorg.path(model,'blk_2274')],'-dpng','-r110',fullfile(root,'logs','flight_control_after_layout.png'));
print(['-s' reorg.path(model,scope)],'-dpng','-r110',fullfile(root,'logs','takeoff_hover_after_layout.png'));
open_system(reorg.path(model,'blk_2274'));
open_system(reorg.path(model,scope));
end

function [result,mapping] = pack(model,scope,selected,name,inputGroups,outputGroups,mapping)
% Copy actual blocks, map each crossing connection, and remove only originals.
links = readLinks(model,scope);
result = reorg.groupCopy(model,scope,scope,selected,name,inputGroups,outputGroups);
operations = {};
result.InputBuses = {};
for k = 1:numel(inputGroups)
    members = inputGroups(k).Members;
    if numel(members) == 1
        operations{end+1} = reorg.wire(members(1).Endpoint,sprintf('%s.u%d',result.ID,k),inputGroups(k).Name);
    else
        ref = ['inputBus' num2str(k)];
        operations{end+1} = reorg.add('BusCreator',[name 'Input' num2str(k)],ref,struct('Inputs',num2str(numel(members))));
        for j = 1:numel(members)
            operations{end+1} = reorg.wire(members(j).Endpoint,sprintf('#%s.u%d',ref,j),members(j).Name);
        end
        operations{end+1} = reorg.wire(['#' ref '.y1'],sprintf('%s.u%d',result.ID,k),inputGroups(k).Name);
    end
end
reply = reorg.edit(model,scope,operations);
for k = 1:numel(inputGroups)
    if numel(inputGroups(k).Members)>1
        result.InputBuses{end+1}=reorg.created(reply,['inputBus' num2str(k)]);
    end
end
fields = reorg.outputMap(model,scope,result.ID,outputGroups);
operations = {};
for k = 1:numel(links)
    link = links(k);
    if ~ismember(link.Src,selected) || ismember(link.Dst,selected),continue;end
    oldEndpoint = sprintf('%s.y%d',link.Src,link.SrcPort);
    [g,j] = memberIndex(outputGroups,oldEndpoint);
    assert(~isempty(g),'official:MissingControlOutput','Missing %s from %s.',oldEndpoint,name);
    newEndpoint = fields.Groups.(outputGroups(g).Name).(outputGroups(g).Members(j).Name);
    operations{end+1} = reorg.wire(newEndpoint,sprintf('%s.u%d',link.Dst,link.DstPort));
end
for k=1:numel(selected),operations{end+1}=struct('op','delete','target',selected{k});end
reorg.edit(model,scope,operations);
for g=1:numel(outputGroups)
    for j=1:numel(outputGroups(g).Members)
        member=outputGroups(g).Members(j);
        mapping.(key(member.Endpoint))=fields.Groups.(outputGroups(g).Name).(member.Name);
    end
end
result.OutputFields=fields;
result.Description=groupDescription(name);
reorg.edit(model,scope,{reorg.configure(result.ID,struct('Description',result.Description,'ShowPortLabels','FromPortBlockName'))});
end

function result = bundleTakeoff(model,scope)
% Keep the existing subsystem SID; change only its transport interface.
parent='blk_2274';
[inports,outports]=reorg.ports(model,scope);
assert(numel(inports)==17 && numel(outports)==8);
outerLinks=readLinks(model,parent);
innerLinks=readLinks(model,scope);
sources=cell(1,17);destinations=cell(1,8);
operations={};
for k=1:17
    e=outerLinks(strcmp({outerLinks.Dst},scope) & [outerLinks.DstPort]==k);
    assert(numel(e)==1);
    sources{k}=sprintf('%s.y%d',e.Src,e.SrcPort);
    operations{end+1}=struct('op','disconnect','target',sprintf('%s -> %s.u%d',sources{k},scope,k));
end
for k=1:8
    e=outerLinks(strcmp({outerLinks.Src},scope) & [outerLinks.SrcPort]==k);
    destinations{k}=arrayfun(@(x)sprintf('%s.u%d',x.Dst,x.DstPort),e,'UniformOutput',false);
    for j=1:numel(e)
        operations{end+1}=struct('op','disconnect','target',sprintf('%s.y%d -> %s.u%d',scope,k,e(j).Dst,e(j).DstPort));
    end
end
reorg.edit(model,parent,operations);
inputIndexes={ [1 6 7 8],[2 3 4 5],[9 11 12 13 14 15 16 17],10 };
inputNames={'PilotInput','MeasuredState','FlightContext','Dt'};
fieldNames={{'Sticks','BatteryVoltage','RangeFlag','OverG'}, ...
    {'Angles','AngularRate','Height','Velocity'}, ...
    {'Branch','PreMode','FlipPhase','FlipThrust','FlipRate','FlipStart','FlipDone','FlipAngleReset'},{'Dt'}};
operations={};
% Release the existing Dt name before reusing the fourth Inport.
% This matters because model_edit applies configure operations in order.
operations{end+1}=reorg.configure(inports{10},struct('Name','LegacyDt'));
for k=1:4
    operations{end+1}=reorg.configure(inports{k},struct('Name',inputNames{k},'Port',num2str(k)));
    if k<4
        operations{end+1}=reorg.add('BusSelector',[inputNames{k} 'Fields'],['fields' num2str(k)], ...
            struct('OutputSignals',strjoin(fieldNames{k},',')));
        operations{end+1}=reorg.wire([inports{k} '.y1'],sprintf('#fields%d.u1',k),inputNames{k});
    end
end
reply=reorg.edit(model,scope,operations);
result.InputFields={};
operations={};
for k=1:4
    if k<4,result.InputFields{k}=reorg.created(reply,['fields' num2str(k)]);end
    for j=1:numel(inputIndexes{k})
        oldPort=inputIndexes{k}(j);
        if k<4,source=sprintf('%s.y%d',result.InputFields{k},j);else,source=[inports{k} '.y1'];end
        e=innerLinks(strcmp({innerLinks.Src},inports{oldPort}));
        for n=1:numel(e)
            operations{end+1}=reorg.wire(source,sprintf('%s.u%d',e(n).Dst,e(n).DstPort),fieldNames{k}{j});
        end
    end
end
for k=5:17,operations{end+1}=struct('op','delete','target',inports{k});end
outputSources=cell(1,8);
for k=1:8
    e=innerLinks(strcmp({innerLinks.Dst},outports{k}));assert(numel(e)==1);
    outputSources{k}=sprintf('%s.y%d',e.Src,e.SrcPort);
end
outFields={{'Duty','Counts'},{'Diagnostics','AltitudeEnabled','FlipPhase','Reset','RateReference','Mode'}};
outIndexes={1:2,3:8};outNames={'MotorCommand','ControlStatus'};
for k=1:2
    operations{end+1}=reorg.configure(outports{k},struct('Name',outNames{k},'Port',num2str(k)));
    operations{end+1}=reorg.add('BusCreator',[outNames{k} 'Bus'],['outBus' num2str(k)],struct('Inputs',num2str(numel(outIndexes{k}))));
    for j=1:numel(outIndexes{k})
        operations{end+1}=reorg.wire(outputSources{outIndexes{k}(j)},sprintf('#outBus%d.u%d',k,j),outFields{k}{j});
    end
    operations{end+1}=reorg.wire(sprintf('#outBus%d.y1',k),[outports{k} '.u1'],outNames{k});
end
for k=3:8,operations{end+1}=struct('op','delete','target',outports{k});end
reply=reorg.edit(model,scope,operations);
result.OutputBuses={reorg.created(reply,'outBus1'),reorg.created(reply,'outBus2')};
result.Inports=inports(1:4);result.Outports=outports(1:2);

operations={};result.InputBuses={};
for k=1:4
    if k<4
        operations{end+1}=reorg.add('BusCreator',['Takeoff' inputNames{k} 'Bus'],['inBus' num2str(k)], ...
            struct('Inputs',num2str(numel(inputIndexes{k}))));
        for j=1:numel(inputIndexes{k})
            operations{end+1}=reorg.wire(sources{inputIndexes{k}(j)},sprintf('#inBus%d.u%d',k,j),fieldNames{k}{j});
        end
        operations{end+1}=reorg.wire(sprintf('#inBus%d.y1',k),sprintf('%s.u%d',scope,k),inputNames{k});
    else,operations{end+1}=reorg.wire(sources{inputIndexes{k}},sprintf('%s.u%d',scope,k),'Dt');end
end
operations{end+1}=reorg.add('BusSelector','ControlStatusFields','statusFields',struct('OutputSignals',strjoin(outFields{2},',')));
operations{end+1}=reorg.wire([scope '.y2'],'#statusFields.u1','ControlStatus');
for k=3:8
    for j=1:numel(destinations{k})
        operations{end+1}=reorg.wire(sprintf('#statusFields.y%d',k-2),destinations{k}{j},outFields{2}{k-2});
    end
end
% MotorCommand is already a bus in the original order Duty, Counts.
assert(isequal(destinations{1},{'blk_2289.u1'}) && isequal(destinations{2},{'blk_2289.u2'}));
motorDests=outerLinks(strcmp({outerLinks.Src},'blk_2289'));
for k=1:numel(motorDests)
    operations{end+1}=reorg.wire([scope '.y1'],sprintf('%s.u%d',motorDests(k).Dst,motorDests(k).DstPort),'MotorCommand');
end
operations{end+1}=struct('op','delete','target','blk_2289');
reply=reorg.edit(model,parent,operations);
result.StatusFields=reorg.created(reply,'statusFields');
for k=1:3,result.InputBuses{k}=reorg.created(reply,['inBus' num2str(k)]);end
result.ParentMap=struct;
for k=3:8,result.ParentMap.(key(sprintf('%s.y%d',scope,k)))=sprintf('%s.y%d',result.StatusFields,k-2);end
end

function layoutInner(model,scope,r)
items={ ...
    r.Interface.Inports{1},[30 240 60 260];r.Interface.Inports{2},[30 500 60 520]; ...
    r.Interface.Inports{3},[30 760 60 780];r.Interface.Inports{4},[30 1040 60 1060]; ...
    r.Interface.InputFields{1},[180 160 190 330];r.Interface.InputFields{2},[180 420 190 590]; ...
    r.Interface.InputFields{3},[180 670 190 990]; ...
    'blk_2606',[530 170 770 400];'blk_2364',[530 540 770 750]; ...
    r.Gating.ID,[1020 800 1280 990];r.Altitude.ID,[1660 190 1950 400]; ...
    r.Attitude.ID,[1660 590 1950 800];r.Rate.ID,[2260 590 2550 800]; ...
    r.Motor.ID,[2860 300 3150 490];r.Diagnostics.ID,[2860 920 3150 1110]; ...
    r.Unused.ID,[500 1100 680 1160];'blk_2705',[900 1110 1020 1140]; ...
    r.Interface.OutputBuses{1},[3300 290 3310 390]; ...
    r.Interface.OutputBuses{2},[3300 760 3310 1050]; ...
    r.Interface.Outports{1},[3470 325 3500 345];r.Interface.Outports{2},[3470 900 3500 920]; ...
    'blk_3307',[30 20 3500 120]};
operations=placementOps(items);
operations{end+1}=reorg.configure('blk_3307',struct('MaskDisplay', ...
    japaneseText('離陸・ホバリング制御（400 Hz）','上段：高度 → 鉛直速度 → 共通推力。中段：姿勢角 → 角速度 → 3軸トルク → 4モーター。','下段：実行・リセット条件と診断。バスの名前をたどり、各サブシステム内で個別のPIDを編集できます。'), ...
    'MaskIconFrame','off','FontSize','12'));
operations{end+1}=struct('op','delete','target','blk_2367');
reorg.edit(model,scope,operations);
captions={r.Gating.ID,'制御の実行・リセット';r.Altitude.ID,'高度・鉛直速度の制御'; ...
    r.Attitude.ID,'姿勢角から角速度指令';r.Rate.ID,'3軸の角速度制御'; ...
    r.Motor.ID,'4モーター配分・制限';r.Diagnostics.ID,'記録用の制御診断'};
setCaptions(model,scope,captions);
positionAdjacentBuses(model,scope,r);
route(model,scope);
end

function layoutParent(model,r)
scope='blk_2274';
items={ ...
    'blk_2275',[30 310 60 330];'blk_2276',[30 500 60 520];'blk_2277',[30 750 60 770]; ...
    'blk_2281',[220 270 230 370];'blk_2714',[220 460 230 560];'blk_2284',[220 650 230 1020]; ...
    'blk_2294',[480 1040 560 1090];'blk_2292',[480 1140 560 1190]; ...
    'blk_2290',[610 190 880 460];'blk_2291',[610 650 880 970]; ...
    r.Interface.InputBuses{1},[1130 1000 1140 1180]; ...
    r.Interface.InputBuses{2},[1130 370 1140 550]; ...
    r.Interface.InputBuses{3},[1300 670 1310 1000]; ...
    'blk_2297',[1580 370 1910 690];r.Interface.StatusFields,[2090 710 2100 1000]; ...
    'blk_2285',[2540 610 2550 890];'blk_2715',[2740 450 2770 470]; ...
    'blk_2716',[2740 745 2770 765];'blk_2717',[2740 1210 2770 1230]; ...
    r.Memory.ID,[2180 1170 2460 1390];'blk_2287',[950 960 970 980]; ...
    'blk_3298',[30 20 2770 120]};
operations=placementOps(items);
operations{end+1}=reorg.configure('blk_3298',struct('MaskDisplay', ...
    japaneseText('飛行制御（400 Hz / 2.5 ms）','左：機体の推定値と操作入力。中央：Stateflowの飛行モード・Flip → 離陸とホバリング制御。','右下：前周期の状態を保持し、推定器へフィードバック。元のUnit Delayの位置と初期値を維持します。'), ...
    'MaskIconFrame','off','FontSize','12'));
reorg.edit(model,scope,operations);
setCaptions(model,scope,{'blk_2297','離陸・ホバリング制御';r.Memory.ID,'前周期の状態とリセット'});
positionGroupBuses(model,scope,r.Memory);
route(model,scope);
end

function arrangeGroup(model,scope,kind)
% Native layout changes positions and routes only; explicitly requested by user.
Simulink.BlockDiagram.arrangeSystem(reorg.path(model,scope),'FullLayout','true');
route(model,scope);
end

function positionAdjacentBuses(model,scope,r)
for name={'Altitude','Attitude','Rate','Motor','Diagnostics','Gating'}
    positionGroupBuses(model,scope,r.(name{1}));
end
end

function positionGroupBuses(model,scope,g)
operations={};ports=get_param(reorg.path(model,g.ID),'PortHandles');
for k=1:numel(ports.Inport)
    line=get_param(ports.Inport(k),'Line');if line<0,continue;end
    source=get_param(line,'SrcPortHandle');p=get_param(source,'Parent');
    if strcmp(get_param(p,'BlockType'),'BusCreator') && ismember(reorg.id(p),g.InputBuses)
        q=get_param(ports.Inport(k),'Position');count=str2double(get_param(p,'Inputs'));height=max(60,count*25);
        operations{end+1}=reorg.configure(reorg.id(p),struct('Position',[q(1)-170 q(2)-height/2 q(1)-160 q(2)+height/2], ...
            'ShowName','off','FontSize','10'));
    end
end
for k=1:numel(ports.Outport)
    line=get_param(ports.Outport(k),'Line');if line<0,continue;end
    destinations=get_param(line,'DstPortHandle');
    for j=1:numel(destinations)
        p=get_param(destinations(j),'Parent');
        if strcmp(get_param(p,'BlockType'),'BusSelector')
            q=get_param(ports.Outport(k),'Position');count=numel(strsplit(get_param(p,'OutputSignals'),','));height=max(60,count*25);
            operations{end+1}=reorg.configure(reorg.id(p),struct('Position',[q(1)+110 q(2)-height/2 q(1)+120 q(2)+height/2], ...
                'ShowName','off','FontSize','10'));
        end
    end
end
if ~isempty(operations),reorg.edit(model,scope,operations);end
end

function setCaptions(model,scope,items)
operations={};
for k=1:size(items,1)
    description=get_param(reorg.path(model,items{k,1}),'Description');
    operations{end+1}=reorg.configure(items{k,1},struct('Mask','on','MaskDisplay', ...
        japaneseText(items{k,2},'ダブルクリックで内部を編集'), ...
        'MaskIconOpaque','opaque','ShowPortLabels','FromPortBlockName','FontSize','11','Description',description));
end
reorg.edit(model,scope,operations);
end

function operations=placementOps(items)
operations={};
for k=1:size(items,1)
    operations{end+1}=reorg.configure(items{k,1},struct('Position',items{k,2},'FontSize','11'));
end
end
function route(model,scope)
lines=find_system(reorg.path(model,scope),'SearchDepth',1,'FindAll','on','Type','line');
if ~isempty(lines),Simulink.BlockDiagram.routeLine(lines);end
end
function text=japaneseText(varargin)
value=strjoin(varargin,newline);value=strrep(strrep(value,"'","''"),newline,'\n');
text=['disp(''' char(value) ''')'];
end
function description=groupDescription(name)
switch name
    case {'AltitudeControl400','Altitude'}
        description=sprintf('高度PID → 鉛直速度PID → 共通推力。\n元の台形積分、不完全微分、積分上限±30000、実測Dt、無効時の保持を維持。\nThrustStateは元のUnit Delayの出力なので、新しい遅延は加えていません。');
    case {'AttitudeControl400','Attitude'}
        description=sprintf('スティックから姿勢角指令を作り、Roll/Pitchの姿勢PIDで角速度指令へ変換。\nSport/Flipの指令選択、前回誤差のリセット、角速度の保持は従来と同じ。');
    case {'BodyRateControl400','Rate'}
        description='Roll/Pitch/Yawの角速度誤差を各PIDへ入力し、3軸のモーター差分指令へ変換します。Dt・実行条件・リセットはRateContextにまとめています。';
    case {'MotorAllocation400','Motor'}
        description='共通推力と3軸トルクを4モーターへ配分します。元のフィルター、Duty上限0.95、8 bit量子化、Flip完了時の保持を維持します。';
    case {'FlightDiagnostics400','Diagnostics'}
        description='制御計算で使った値を元の17要素の順番で記録します。制御経路には新しい演算や遅延を加えません。';
    case {'ControlGating400','Gating'}
        description='元のControlEnableReset MATLAB Functionをそのまま使用します。離陸・着陸・Flip・推力から、各PIDの実行条件とリセットを判断します。';
    case {'PreviousCycle400','Memory'}
        description='元のUnit Delayとuint8変換を保持する配線整理です。モード、高度フラグ、姿勢リセット、待機リセット、Flip位相を従来と同じ1周期遅延で推定器へ返します。';
    otherwise,description='元のブロックと接続を維持した表示用のサブシステムです。';
end
end
function result=ids(values)
result=arrayfun(@(x)['blk_' num2str(x)],values,'UniformOutput',false);
end
function result=eps(mapping,endpoints)
result=endpoints;
for k=1:numel(endpoints)
    field=key(endpoints{k});if isfield(mapping,field),result{k}=mapping.(field);end
end
end
function result=key(endpoint),result=strrep(endpoint,'.','_');end
function [g,j]=memberIndex(groups,endpoint)
g=[];j=[];
for k=1:numel(groups)
    found=find(strcmp({groups(k).Members.Endpoint},endpoint),1);
    if ~isempty(found),g=k;j=found;return;end
end
end
function links=readLinks(model,scope)
parent=reorg.path(model,scope);blocks=find_system(parent,'SearchDepth',1,'Type','Block');
links=struct('Src',{},'SrcPort',{},'Dst',{},'DstPort',{});
for k=1:numel(blocks)
    if strcmp(blocks{k},parent),continue;end
    ports=get_param(blocks{k},'PortHandles');
    for j=1:numel(ports.Inport)
        line=get_param(ports.Inport(j),'Line');if line<0,continue;end
        source=get_param(line,'SrcPortHandle');if source<0,continue;end
        links(end+1)=struct('Src',reorg.id(get_param(source,'Parent')), ...
            'SrcPort',get_param(source,'PortNumber'),'Dst',reorg.id(blocks{k}),'DstPort',j); %#ok<AGROW>
    end
end
end
