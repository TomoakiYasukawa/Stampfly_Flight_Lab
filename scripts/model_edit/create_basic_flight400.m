function create_basic_flight400(stage)
%CREATE_BASIC_FLIGHT400 Copy the PID model and remove aerobatic mechanisms.
% The source SLX is never saved. Structural edits use the Simulink toolkit.
% Stages also permit resuming an interrupted construction without recopying.
if nargin==0,stage='all';end
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
model='StampFly_Basic400';
if strcmp(stage,'all')
    for part={'copy','supervisor','commands','controllers','sensors','interfaces','finish','cleanup'}
        create_basic_flight400(part{1});
    end
    return;
end
if strcmp(stage,'copy')
    assert(~isfile(fullfile(root,[model '.slx'])),'basic:AlreadyExists','The basic model already exists.');
    open_system(fullfile(root,'StampFly_Official_FlightTest400.slx'));
    source='StampFly_PIDBlock_FlightTest400';open_system(fullfile(root,[source '.slx']));
    save_system(source,fullfile(root,[model '.slx']));open_system(model);
    apply(model,'root',{reorg.configure(['config:' model],struct('InitFcn','init_basic;', ...
        'PostLoadFcn',sprintf("run(fullfile(fileparts(get_param('%s','FileName')),'config','startup.m'));",model), ...
        'Description','StampFly basic flight: 400 Hz, seven PID blocks, takeoff/hover/landing and sensor logging.'))});
    init_basic();save_system(model);fprintf('BASIC400_STAGE_DONE: copy\n');return;
end
assert(bdIsLoaded(model),'Open the basic copy before editing.');
switch stage
    case 'supervisor'
        chart=chartOf(model,'blk_2290');model_read(model,'blk_2290','inf');
        cycle=chart.find('-isa','Stateflow.State','Name','CycleInputs');
        ops=deletions({'sf_2290:51','sf_2290:58','sf_2290:59','sf_2290:41'});
        ops{end+1}=reorg.configure(sfID('blk_2290',cycle),struct('LabelString',strrep(cycle.LabelString,'branch==2 || branch==6','branch==2')));
        apply(model,'blk_2290',ops);
        pruneOutputs(model,'blk_2284',{'Sticks','ArmButton','NewPacket','AHRSRequest','BatteryVoltage','Dt','Flags'});
        pruneInputs(model,'blk_3792',[1 2]);
        pruneOutputs(model,'blk_3793',{'Diagnostics','AltitudeEnabled','Mode'});
        pruneInputs(model,'blk_3815',[1 5]);
        pruneInputs(model,'blk_3816',[1 2]);
        pruneInputs(model,'blk_2285',[1 2 3 4 6]);
        apply(model,'blk_2274',deletions({'blk_2287','blk_2291'}));
        pruneOutputs(model,'blk_3812',{'AltitudeEnabled','Mode'});
        pruneOutputs(model,'blk_3813',{'AttitudeReset','ParkingReset'});
        pruneInputs(model,'blk_3806',1:4);
        apply(model,'blk_3794',[deletions({'blk_3805','blk_3807','blk_3810','blk_3811','blk_3814'}), ...
            {reorg.wire('blk_3813.y1','blk_3802.u1','AttitudeReset'), ...
             reorg.wire('blk_3808.y1','blk_3800.u1','PreviousMode'), ...
             reorg.configure('blk_3800',struct('Name','PreviousMode'))}]);
        apply(model,'blk_2274',[deletions({'blk_3817'}), ...
            {reorg.wire('blk_3794.y2','blk_2290.u1','PreviousMode'), ...
             reorg.wire('blk_3794.y2','blk_2285.u2','PreviousMode')}]);
        check(model,{'blk_3794','blk_2274'});
    case 'commands'
        model_read(model,'blk_3832','inf');chart=chartOf(model,'blk_3832');ops={};
        transitions=chart.find('-isa','Stateflow.Transition');
        for k=1:numel(transitions)
            old=transitions(k).LabelString;
            label=strrep(old,'(mode==2 || (mode==6 && phase==0 && ~flipDone))','mode==2');
            if ~strcmp(old,label),ops{end+1}=reorg.configure(sfID('blk_3832',transitions(k)),struct('LabelString',label));end
        end
        apply(model,'blk_3832',[ops,deletions({'sf_3832:26','sf_3832:27'})]);
        model_read(model,'blk_3833','inf');
        ops=deletions({'sf_3833:31','sf_3833:32','sf_3833:39','sf_3833:25','sf_3833:4','sf_3833:5'});
        ops{end+1}=reorg.configure('sf_3833:30',struct('LabelString','[(branch==2 || branch==5) && overG==1]'));
        apply(model,'blk_3833',ops);
        pruneOutputs(model,'blk_3849',{'Branch','PreMode'});
        apply(model,'blk_3822',{reorg.wire('blk_3848.y4','blk_3833.u4')});
        script=sourceScript(model,'blk_3840');
        lines={ ...
            'function [arg_arg_command,arg_arg_run,arg_arg_reset,arg_arg_altEnable,arg_arg_angleEnable,arg_arg_velEnable]=stepFn(arg_arg_raw,arg_arg_manual,arg_arg_auto,arg_branch,arg_arg_controlMode,arg_arg_dt,arg_arg_oldFilter,arg_arg_lastThrust,arg_arg_mode)', ...
            '% Normal-flight enable/reset decisions and thrust filtering.', ...
            '%#codegen', ...
            'arg_arg_command=arg_arg_raw;', ...
            'if arg_arg_manual,arg_arg_command=filterStep(arg_arg_raw,arg_arg_dt,single(.01),arg_arg_oldFilter);end', ...
            'if arg_branch==5 || arg_branch==3,arg_arg_command=arg_arg_lastThrust;end', ...
            'active=arg_branch==2 || arg_branch==5;', ...
            'arg_arg_reset=active && double(arg_arg_command)/3.7<double(single(.1));', ...
            'arg_arg_run=active && ~arg_arg_reset;', ...
            'arg_arg_altEnable=arg_arg_run && arg_arg_auto;', ...
            'arg_arg_angleEnable=arg_arg_run && uint8(arg_arg_controlMode)==0;', ...
            'arg_arg_velEnable=arg_arg_run && (arg_arg_auto || arg_arg_mode==5);', ...
            'end', ...
            'function s=filterStep(u,h,T,s),s=s*T/(T+h)+u*h/(T+h);end'};
        assert(contains(script,'heldFlip'));writeFunction(model,'blk_3840',strjoin(lines,newline));
        pruneOutputs(model,'blk_3841',{'FlightContext.Branch','Dt','Mode'});
        pruneInputs(model,'blk_3839',1:5);
        pruneOutputs(model,'blk_3850',{'Reset'});
        pruneInputs(model,'blk_3862',1:3);
        pruneOutputs(model,'blk_3863',{'AltitudeEnabled','Mode','Reset'});
        pruneInputs(model,'blk_3789',[1 2 6]);
        check(model,{'blk_3834','blk_3822','blk_2297'});
    case 'controllers'
        script=sourceScript(model,'blk_3365');
        script=strrep(strrep(script,',arg_flipFlag',''),'~(arg_auto && arg_flipFlag==0)','~arg_auto');
        writeFunction(model,'blk_3365',script);
        script=sourceScript(model,'blk_3410');
        script=strrep(strrep(script,',arg_arg_flipFlag',''),'arg_arg_auto && arg_arg_flipFlag==0','arg_arg_auto');
        script=regexprep(script,'% rate_control:[^\n]*','% Auto correction takes priority over landing correction.');
        writeFunction(model,'blk_3410',script);
        pruneOutputs(model,'blk_3415',{'ThrustRequest','ControlContext.VelocityEnabled','ControlContext.AltitudeEnabled', ...
            'ControlContext.Reset','FlightContext.Branch','Mode','Dt','PreviousError'});
        script=sourceScript(model,'blk_3429');
        script=strrep(script,',arg_arg_phase,arg_arg_flipRate','');
        script=strrep(script,',arg_arg_flipDone','');script=strrep(script,',arg_arg_angleReset','');
        script=strrep(script,'arg_branch==2 || arg_branch==5 || (arg_branch==6 && arg_arg_phase==0 && ~arg_arg_flipDone)','arg_branch==2 || arg_branch==5');
        script=strrep(script,['elseif arg_branch==6 && arg_arg_phase==1,AngleCmd(:)=single(0);' newline],'');
        script=strrep(script,'if arg_arg_angleReset,Centers(1:2)=AngleCmd;end','if arg_arg_reset,Centers(1:2)=AngleCmd;end');
        script=strrep(script,'arg_arg_run && (arg_arg_phase==0 || arg_arg_phase==1) &&','arg_arg_run &&');
        script=strrep(script,['if arg_branch==6 && arg_arg_phase>=2,arg_arg_directRate(1)=arg_arg_flipRate;arg_arg_directRate(2)=single(0);end' newline],'');
        writeFunction(model,'blk_3429',script);
        pruneOutputs(model,'blk_3525',{'PilotInput.Sticks','SharedControlContext.FlightContext.Branch','SharedControlContext.ControlMode'});
        pruneOutputs(model,'blk_3526',{'ControlContext.Run','ControlContext.Reset','ControlContext.AngleEnabled','Dt'});
        apply(model,'blk_3421',[deletions({'blk_3433'}), ...
            {reorg.wire('blk_3526.y2','blk_3897.u4'),reorg.wire('blk_3526.y2','blk_3913.u4')}]);
        pruneOutputs(model,'blk_3739',{'ControlContext.Run','ControlContext.Reset','PilotInput.OverG','FlightContext.Branch','Dt'});
        apply(model,'blk_3681',[deletions({'blk_3691','blk_3696','blk_3708'}), ...
            {reorg.wire('blk_3733.y1','blk_3734.u3')}]);
        check(model,{'blk_3312','blk_3421','blk_3681','blk_3674'});
    case 'sensors'
        script=sourceScript(model,'blk_2253');
        script=strrep(strrep(script,',arg_flipFlag',''),' && arg_flipFlag==0','');writeFunction(model,'blk_2253',script);
        pruneOutputs(model,'blk_2240',{'PreviousMode','AltitudeEnabled','Dt','AttitudeReset','ParkingReset','BatteryVoltage'});
        pruneOutputs(model,'blk_3139',{'PreviousMode','AltitudeEnabled','AttitudeReset','ParkingReset'});
        pruneInputs(model,'blk_3141',[1 2 3 4 5 7]);
        check(model,{'blk_2231','blk_3131'});
    case 'interfaces'
        pruneOutputs(model,'blk_3228',{'Sticks','ArmButton','NewPacket','AHRSRequest'});
        pruneInputs(model,'blk_3227',[1 2 3 4 6 7 8]);
        changeJoystick(model);
        pruneOutputs(model,'blk_3258',{'Diagnostics'});
        apply(model,'blk_3252',deletions({'blk_3264'}));
        script=sourceScript(model,'blk_3063');script=strrep(script,',arg_flipFlag','');
        script=strrep(script,"elseif arg_flipFlag~=0,c=uint32(hex2dec('FF9933'));",'');writeFunction(model,'blk_3063',script);
        links=reorg.links(model,'blk_3049');links=links(strcmp({links.Dst},'blk_3052'));
        disconnectLinks(model,'blk_3049',links);
        apply(model,'blk_3052',[deletions({'blk_3057'}), ...
            {reorg.configure('blk_3058',struct('Port','5')),reorg.configure('blk_3059',struct('Port','6'))}]);
        ops=deletions({'blk_3070'});
        for k=1:numel(links)
            p=links(k).DstPort;if p==5,continue;elseif p>5,p=p-1;end
            ops{end+1}=reorg.wire(ep(links(k).Src,'y',links(k).SrcPort),ep('blk_3052','u',p),links(k).Name);
        end
        apply(model,'blk_3049',ops);
        pruneInputs(model,'blk_4019',[1 2 3 4 5 6 8 9 10 11 12 13 14]);
        apply(model,'blk_2963',[deletions({'blk_4026'}), ...
            {reorg.configure('blk_4019',struct('OutDataTypeStr','Bus: BasicLogCommandBus')), ...
             reorg.configure('blk_3995',struct('System','basic.ExtendedLogger50'))}]);
        check(model,{'blk_3202','blk_3221','blk_3252','blk_3052','blk_3049','blk_2963'});
    case 'finish'
        cleanExplanations(model);
        model_read(model,'root','0');check(model,{'root'});
    case 'cleanup'
        pruneOutputs(model,'blk_3863',{'AltitudeEnabled','Mode'});
        pruneInputs(model,'blk_3862',[1 2]);
        if ~isempty(find_system(reorg.path(model,'blk_3822'),'SearchDepth',1,'Name','StatusContextFields'))
            apply(model,'blk_3822',deletions({'blk_3850'}));
        end
        % Removing unused chart inputs can leave fully orphaned line segments.
        % SATK represents these connections as "? -> ?".
        floating=patch.ConnectionResolver.findFloating(model);
        if strcmp(floating.status,'found')
            apply(model,'blk_3822',{struct('op','disconnect','target',patch.ConnectionIdBuilder.floating())});
        end
        model_read(model,'blk_3822','0');
        apply(model,'blk_3822',{reorg.configure('blk_3832',caption('離陸・高度目標・着陸', ...
            {'スティック','高度','電池電圧','距離フラグ','飛行分岐'}, ...
            {'目標高度','基準推力','立上げ数','推力指令','自動高度','手動高度','姿勢モード'})), ...
            reorg.configure('blk_3833',caption('飛行モードの確定', ...
            {'飛行分岐','仮モード','高度','過加速度'},{'確定モード'}))});
        check(model,{'blk_3822','blk_2297'});
    otherwise,error('basic:UnknownStage','Unknown stage %s.',stage);
end
save_system(model);fprintf('BASIC400_STAGE_DONE: %s\n',stage);
end

function apply(model,scope,ops)
if isempty(ops),return;end
reorg.edit(model,scope,ops,'incremental');model_read(model,scope,'0');
end
function ops=deletions(ids)
ops=cellfun(@(id)struct('op','delete','target',id),ids,'UniformOutput',false);
end
function scope=parentScope(model,id)
parent=get_param(reorg.path(model,id),'Parent');
if strcmp(parent,model),scope='root';else,scope=reorg.id(parent);end
end
function pruneOutputs(model,id,keep)
scope=parentScope(model,id);model_read(model,scope,'0');
fields=strsplit(get_param(reorg.path(model,id),'OutputSignals'),',');
[found,index]=ismember(keep,fields);assert(all(found),'basic:FieldMissing','Selector %s differs.',id);
links=reorg.links(model,scope);links=links(strcmp({links.Src},id));ops=disconnectOps(links);
ops{end+1}=reorg.configure(id,struct('OutputSignals',strjoin(keep,',')));
for k=1:numel(links)
    p=find(index==links(k).SrcPort,1);if isempty(p),continue;end
    ops{end+1}=reorg.wire(ep(id,'y',p),ep(links(k).Dst,'u',links(k).DstPort),links(k).Name);
end
apply(model,scope,ops);
end
function pruneInputs(model,id,keep)
scope=parentScope(model,id);model_read(model,scope,'0');
links=reorg.links(model,scope);links=links(strcmp({links.Dst},id));ops=disconnectOps(links);
ops{end+1}=reorg.configure(id,struct('Inputs',num2str(numel(keep))));
for k=1:numel(links)
    p=find(keep==links(k).DstPort,1);if isempty(p),continue;end
    ops{end+1}=reorg.wire(ep(links(k).Src,'y',links(k).SrcPort),ep(id,'u',p),links(k).Name);
end
apply(model,scope,ops);
end
function disconnectLinks(model,scope,links),apply(model,scope,disconnectOps(links));end
function ops=disconnectOps(links)
ops={};
for k=1:numel(links)
    ops{end+1}=struct('op','disconnect','target',[ep(links(k).Src,'y',links(k).SrcPort) ' -> ' ep(links(k).Dst,'u',links(k).DstPort)]);
end
end
function value=ep(id,kind,p),value=sprintf('%s.%s%d',id,kind,p);end
function chart=chartOf(model,id),chart=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(model,id));end
function id=sfID(block,obj),id=sprintf('sf_%s:%d',extractAfter(block,'blk_'),obj.SSIdNumber);end
function script=sourceScript(model,id)
model_read(model,id,'0');chart=sfroot().find('-isa','Stateflow.EMChart','Path',reorg.path(model,id));script=chart.Script;
end
function writeFunction(model,id,script)
% EMChart bodies are exposed as MATLABFunctionConfiguration, not SF elements
% in this toolkit release. Use that public API for the body; SATK owns wiring.
scope=parentScope(model,id);model_read(model,scope,'0');model_read(model,id,'0');
chart=sfroot().find('-isa','Stateflow.EMChart','Path',reorg.path(model,id));
oldInputs={chart.Inputs.Name};oldOutputs={chart.Outputs.Name};
links=reorg.links(model,scope);incoming=links(strcmp({links.Dst},id));outgoing=links(strcmp({links.Src},id));
disconnectLinks(model,scope,[incoming outgoing]);
configuration=get_param(reorg.path(model,id),'MATLABFunctionConfiguration');configuration.FunctionScript=script;
chart=sfroot().find('-isa','Stateflow.EMChart','Path',reorg.path(model,id));
newInputs={chart.Inputs.Name};newOutputs={chart.Outputs.Name};ops={};
for k=1:numel(incoming)
    p=find(strcmp(newInputs,oldInputs{incoming(k).DstPort}),1);if isempty(p),continue;end
    ops{end+1}=reorg.wire(ep(incoming(k).Src,'y',incoming(k).SrcPort),ep(id,'u',p),incoming(k).Name);
end
for k=1:numel(outgoing)
    p=find(strcmp(newOutputs,oldOutputs{outgoing(k).SrcPort}),1);if isempty(p),continue;end
    ops{end+1}=reorg.wire(ep(id,'y',p),ep(outgoing(k).Dst,'u',outgoing(k).DstPort),outgoing(k).Name);
end
apply(model,scope,ops);model_read(model,id,'0');
assert(~contains(lower(chart.Script),'flip'),'basic:RemainingMechanism','Function %s still refers to aerobatics.',id);
end
function changeJoystick(model)
scope='blk_3202';model_read(model,scope,'0');
links=reorg.links(model,scope);links=links(strcmp({links.Src},'blk_3204'));ops=disconnectOps(links);
ops{end+1}=reorg.configure('blk_3204',struct('System','basic.Joystick400','Name','BasicJoystick400'));
apply(model,scope,ops);pruneInputs(model,'blk_3203',1:4);
ops={reorg.configure('blk_3203',struct('OutDataTypeStr','Bus: BasicLogPilotBus'))};
for k=1:numel(links)
    p=links(k).SrcPort;if p==5,continue;elseif p>5,p=p-1;end
    ops{end+1}=reorg.wire(ep('blk_3204','y',p),ep(links(k).Dst,'u',links(k).DstPort),links(k).Name);
end
apply(model,scope,ops);
end
function cleanExplanations(model)
blocks=find_system(model,'LookUnderMasks','all','Type','Block');scopes=struct;
for k=1:numel(blocks)
    if strcmp(blocks{k},model),continue;end
    p=get_param(blocks{k},'ObjectParameters');params=struct;
    for key={'Description','AttributesFormatString'}
        if ~isfield(p,key{1}),continue;end
        value=get_param(blocks{k},key{1});
        if ischar(value)&&contains(lower(value),'flip')
            value=regexprep(value,'(?i)\s*/\s*Flip','');
            value=regexprep(value,'(?i)・Flip位相','');value=regexprep(value,'(?i)・Flip','');
            value=regexprep(value,'(?i)Flip・','');value=regexprep(value,'(?i)Flip[^。\n]*','');
            params.(key{1})=value;
        end
    end
    if isempty(fieldnames(params)),continue;end
    id=reorg.id(blocks{k});if contains(id,'::'),continue;end
    scope=parentScope(model,id);if ~isfield(scopes,scope),scopes.(scope)={};end
    scopes.(scope){end+1}=reorg.configure(id,params);
end
names=fieldnames(scopes);for k=1:numel(names),apply(model,names{k},scopes.(names{k}));end
for id={'blk_2290','blk_3832','blk_3833'}
    model_read(model,id{1},'inf');chart=chartOf(model,id{1});annotations=chart.find('-isa','Stateflow.Annotation');ops={};
    if contains(lower(chart.Description),'flip')
        ops{end+1}=reorg.configure(['chart:' model],struct('Description', ...
            'Normal flight: takeoff, hover, landing and fault handling.'));
    end
    for k=1:numel(annotations)
        if contains(lower(annotations(k).Text),'flip')
            ops{end+1}=reorg.configure(sfID(id{1},annotations(k)),struct('Text','Basic flight: takeoff, hover, landing and normal fault handling.'));
        end
    end
    apply(model,id{1},ops);
end
end
function check(model,scopes)
for k=1:numel(scopes)
    result=char(model_check(model,scopes{k},'["all"]'));fprintf('%s\n',result);
    assert(~contains(result,'severity: error'),'basic:Connectivity','Scope %s has unconnected ports.',scopes{k});
end
end
function params=caption(title,inputs,outputs)
icon=['disp(''' title '\nダブルクリックで内部を編集'');'];
for k=1:numel(inputs),icon=[icon sprintf('port_label(''input'',%d,''%s'');',k,inputs{k})];end
for k=1:numel(outputs),icon=[icon sprintf('port_label(''output'',%d,''%s'');',k,outputs{k})];end
params=struct('Mask','on','MaskDisplay',icon,'MaskIconOpaque','opaque','MaskIconFrame','on', ...
    'ShowPortLabels','none','FontSize','12','ShowName','on','AttributesFormatString','');
end
