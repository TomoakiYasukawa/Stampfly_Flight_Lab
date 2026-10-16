function report=reorganize_imu400(stage)
%REORGANIZE_IMU400 Integrate logging and expose the supervisor without changing control.
% Run individual stages to resume a saved checkpoint. Original flight BIN is retained.
arguments
    stage (1,1) string {mustBeMember(stage,["merge","supervisor","timing","logging","labels","layout","save"])}
end
root=stampfly_project_root();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
model='StampFly_IMU400';open_system(fullfile(root,[model '.slx']));init_imu_flight();
folder=fullfile(root,'build','imu400','readability');if ~isfolder(folder),mkdir(folder);end
checkpoint=fullfile(folder,'readability_checkpoint.mat');
if isfile(checkpoint)
    report=load(checkpoint,'report').report;
else
    report=struct('Model',[model '.slx'],'CompletedStages',{{}},'BlockMap',struct);
end
beforeFile=fullfile(root,'backups','imu400_before_readability','IMU400BeforeReadability.slx');
assert(isfile(beforeFile),'imu400:MissingBaseline','The pre-edit model backup is required.');
[~,before]=fileparts(beforeFile);open_system(beforeFile);
report.BaselineFile=beforeFile;
assert(~ismember(char(stage),report.CompletedStages),'imu400:AlreadyDone','Stage already completed.');
switch stage
    case "merge"
        attitude=copyContents(before,'blk_3240',model,'blk_2231', ...
            {outputSource(model,'blk_2231',1),outputSource(model,'blk_2231',2)});
        status=copyContents(before,'blk_3252',model,'blk_2274',{outputSource(model,'blk_2274',2)});
        report.BlockMap=mergeMap(report.BlockMap,attitude);
        report.BlockMap=mergeMap(report.BlockMap,status);
        reply=reorg.edit(model,'root',{ ...
            reorg.add('BusSelector','FlightStateFields','stateFields',struct('OutputSignals','PreviousMode,Mode')), ...
            reorg.wire('blk_2274.y2','#stateFields.u1','FlightStatus'), ...
            reorg.wire('#stateFields.y2','blk_3178.u1','Mode'), ...
            struct('op','delete','target','blk_3240'),struct('op','delete','target','blk_3252')});
        report.FlightStateFields=reorg.created(reply,'stateFields');
    case "supervisor"
        oldLinks=reorg.links(model,'blk_2274');
        reply=reorg.edit(model,'blk_2274',{ ...
            reorg.add('Inport','Supervisor','supervisor',struct('Port','4')), ...
            reorg.add('BusSelector','SupervisorFields','fields', ...
                struct('OutputSignals','Branch,PreMode,AttitudeReset,ParkingReset,Connected')), ...
            reorg.wire('#supervisor.y1','#fields.u1','Supervisor')});
        fields=reorg.created(reply,'fields');ops={};
        for k=1:numel(oldLinks)
            link=oldLinks(k);if ~strcmp(link.Src,'blk_2290'),continue;end
            ops{end+1}=reorg.wire(sprintf('%s.y%d',fields,link.SrcPort), ...
                sprintf('%s.u%d',link.Dst,link.DstPort),link.Name); %#ok<AGROW>
        end
        ops{end+1}=struct('op','delete','target','blk_2290');
        reorg.edit(model,'blk_2274',ops);
        model_read(before,'blk_2290','0');
        ops={reorg.add(reorg.path(before,'blk_2290'),'OfficialFlightSupervisor','supervisor'), ...
            reorg.add('BusSelector','SupervisorPilotFields','pilot', ...
                struct('OutputSignals','ArmButton,NewPacket,Flags,AHRSRequest')), ...
            reorg.add('BusCreator','SupervisorCommandBus','bus',struct('Inputs','5')), ...
            reorg.wire('blk_3213.y1','#pilot.u1','FlightInputs'), ...
            reorg.wire([report.FlightStateFields '.y1'],'#supervisor.u1','PreviousMode'), ...
            reorg.wire('#pilot.y1','#supervisor.u2','ArmButton'), ...
            reorg.wire('#pilot.y2','#supervisor.u3','NewPacket'), ...
            reorg.wire('#pilot.y3','#supervisor.u4','Flags'), ...
            reorg.wire('#pilot.y4','#supervisor.u5','AHRSRequest')};
        labels={'Branch','PreMode','AttitudeReset','ParkingReset','Connected'};
        for k=1:5,ops{end+1}=reorg.wire(sprintf('#supervisor.y%d',k),sprintf('#bus.u%d',k),labels{k});end %#ok<AGROW>
        ops{end+1}=reorg.wire('#bus.y1','blk_2274.u4','Supervisor');
        reply=reorg.edit(model,'root',ops);
        report.Supervisor=reorg.created(reply,'supervisor');
        report.SupervisorPilotFields=reorg.created(reply,'pilot');
        report.SupervisorCommandBus=reorg.created(reply,'bus');
        report.SupervisorFields=fields;report.BlockMap.blk_2290=report.Supervisor;
        lint=char(model_check(model,report.Supervisor,'["stateflow_lint"]'));disp(lint);
        assert(~contains(lint,'severity: error'));
    case "timing"
        original=reorg.links(model,'root');
        reorg.edit(model,'root',{reorg.configure('blk_4',struct('Name','CycleClock400'))});
        reply=reorg.edit(model,'root',{struct('op','create_subsystem','name','TickStart400','ref','tick', ...
            'interface',struct('inputs',{{}},'outputs',{{'Dt'}}))});
        tick=reorg.created(reply,'tick');[~,outputs]=reorg.ports(model,tick);
        reply=reorg.edit(model,tick,{reorg.add(reorg.path(before,'blk_4'),'CycleClock400','clock'), ...
            reorg.wire('#clock.y2',[outputs{1} '.u1'],'Dt')},'full');
        clock=reorg.created(reply,'clock');
        timing=copyContents(before,'blk_3282',model,tick, ...
            {[clock '.y1'],[clock '.y2'],[clock '.y3']});
        reorg.edit(model,tick,{reorg.wire([clock '.y1'],[timing.blk_3288 '.u1'],'StartUs'), ...
            struct('op','delete','target',timing.blk_3289)});
        timing=rmfield(timing,'blk_3289');report.BlockMap=mergeMap(report.BlockMap,timing);
        ops={};
        for k=1:numel(original)
            link=original(k);
            if strcmp(link.Src,'blk_4')&&link.SrcPort==2&&~strcmp(link.Dst,'blk_3282')
                ops{end+1}=reorg.wire([tick '.y1'],sprintf('%s.u%d',link.Dst,link.DstPort),'Dt'); %#ok<AGROW>
            end
        end
        ops{end+1}=struct('op','delete','target','blk_4');
        ops{end+1}=struct('op','delete','target','blk_3282');
        reorg.edit(model,'root',ops);
        report.TickStart=tick;report.Clock=clock;report.BlockMap.blk_4=clock;
    case "logging"
        tags={'LogOpticalFlow400','LogMagneticField400','LogFlowDistance50'};
        sources={'blk_3979.y1','blk_3983.y1','blk_4038.y1'};
        ops={};
        for k=1:3
            ref=['publish' num2str(k)];
            ops{end+1}=reorg.add('Goto',['Publish' tags{k}],ref, ...
                struct('GotoTag',tags{k},'TagVisibility','global','ShowName','off')); %#ok<AGROW>
            ops{end+1}=reorg.wire(sources{k},['#' ref '.u1']); %#ok<AGROW>
        end
        reply=reorg.edit(model,'root',ops);
        report.SensorLogPublishers=cell(1,3);
        for k=1:3,report.SensorLogPublishers{k}=reorg.created(reply,['publish' num2str(k)]);end
        [ports,~]=reorg.ports(model,'blk_2963');links=reorg.links(model,'blk_2963');ops={};
        assert(numel(ports)==3);
        for k=1:3
            ref=['read' num2str(k)];
            ops{end+1}=reorg.add('From',['Read' tags{k}],ref,struct('GotoTag',tags{k},'ShowName','off')); %#ok<AGROW>
            outgoing=links(strcmp({links.Src},ports{k}));
            for j=1:numel(outgoing)
                ops{end+1}=reorg.wire(['#' ref '.y1'], ...
                    sprintf('%s.u%d',outgoing(j).Dst,outgoing(j).DstPort),outgoing(j).Name); %#ok<AGROW>
            end
        end
        for k=3:-1:1,ops{end+1}=struct('op','delete','target',ports{k});end %#ok<AGROW>
        reply=reorg.edit(model,'blk_2963',ops);
        report.SensorLogReaders=cell(1,3);
        for k=1:3,report.SensorLogReaders{k}=reorg.created(reply,['read' num2str(k)]);end
        report.SensorLogTags=tags;
    case "labels"
        oldLinks=reorg.links(model,'blk_2274');ops={};
        selected=[1 5 6 7];
        for k=1:numel(oldLinks)
            link=oldLinks(k);if ~strcmp(link.Src,'blk_2284'),continue;end
            ops{end+1}=struct('op','disconnect','target', ...
                sprintf('%s.y%d -> %s.u%d',link.Src,link.SrcPort,link.Dst,link.DstPort)); %#ok<AGROW>
        end
        ops{end+1}=reorg.configure('blk_2284',struct('OutputSignals','Sticks,BatteryVoltage,Dt,Flags'));
        for k=1:numel(oldLinks)
            link=oldLinks(k);if ~strcmp(link.Src,'blk_2284'),continue;end
            port=find(selected==link.SrcPort,1);assert(~isempty(port));
            ops{end+1}=reorg.wire(sprintf('blk_2284.y%d',port), ...
                sprintf('%s.u%d',link.Dst,link.DstPort),link.Name); %#ok<AGROW>
        end
        reorg.edit(model,'blk_2274',ops);
        report.PortLabelBlocks=applyPortLabels(model);
    case "layout"
        layout_imu400(model,report);
        report.LayoutComplete=true;
    case "save"
        assert(report.LayoutComplete);
        assert(isempty(find_system(model,'LookUnderMasks','all','Name','EstimateLogging400')));
        assert(isempty(find_system(model,'LookUnderMasks','all','Name','FlightStatus400')));
        assert(isempty(find_system(model,'LookUnderMasks','all','Name','TimeSignals400')));
        assert(strcmp(get_param(reorg.path(model,report.Supervisor),'Parent'),model));
        assert(numel(find_system(model,'LookUnderMasks','all','Name','DedicatedPID'))==7);
        assert(isempty(find_system(model,'LookUnderMasks','all','Name','OfficialFlipSequence')));
        disp(model_read(model,'root','0'));
end
for scope={'blk_2231','blk_2274','blk_2963','root'}
    check=char(model_check(model,scope{1},'["all"]'));disp(check);
    assert(~contains(check,'severity: error'),'imu400:IncompleteScope','Incomplete scope %s.',scope{1});
end
save_system(model);
report.CompletedStages{end+1}=char(stage);
save(checkpoint,'report');
if stage=="save"
    fid=fopen(fullfile(root,'docs','imu_readability_structure.json'),'w','n','UTF-8');assert(fid>=0);
    fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
fprintf('IMU400_READABILITY_STAGE_COMPLETE: %s\n',stage);
end

function mapping=copyContents(source,sourceScope,destination,destinationScope,feeds)
% Flatten only a virtual subsystem: no execution-control ports or state changes.
model_read(source,sourceScope,'0');model_read(destination,destinationScope,'0');
path=reorg.path(source,sourceScope);assert(strcmp(get_param(path,'TreatAsAtomicUnit'),'off'));
assert(isempty(find_system(path,'SearchDepth',1,'BlockType','EnablePort')));
assert(isempty(find_system(path,'SearchDepth',1,'BlockType','TriggerPort')));
[inputs,~]=reorg.ports(source,sourceScope);assert(numel(feeds)==numel(inputs));
blocks=find_system(path,'SearchDepth',1,'Type','Block');selected={};ops={};
for k=1:numel(blocks)
    block=blocks{k};if strcmp(block,path),continue;end
    if ismember(get_param(block,'BlockType'),{'Inport','Outport'})|| ...
            ismember(get_param(block,'Name'),{'JapaneseExplanation','ModelExplanation'}),continue;end
    selected{end+1}=reorg.id(block); %#ok<AGROW>
    ops{end+1}=reorg.add(block,get_param(block,'Name'),['copy' num2str(numel(selected))]); %#ok<AGROW>
end
links=reorg.links(source,sourceScope);
for k=1:numel(links)
    link=links(k);d=find(strcmp(link.Dst,selected),1);if isempty(d),continue;end
    s=find(strcmp(link.Src,selected),1);
    if isempty(s)
        i=find(strcmp(link.Src,inputs),1);assert(~isempty(i));src=feeds{i};
    else
        src=sprintf('#copy%d.y%d',s,link.SrcPort);
    end
    ops{end+1}=reorg.wire(src,sprintf('#copy%d.u%d',d,link.DstPort),link.Name); %#ok<AGROW>
end
reply=reorg.edit(destination,destinationScope,ops);mapping=struct;
for k=1:numel(selected),mapping.(selected{k})=reorg.created(reply,['copy' num2str(k)]);end
end

function endpoint=outputSource(model,scope,port)
[~,outputs]=reorg.ports(model,scope);links=reorg.links(model,scope);
link=links(strcmp({links.Dst},outputs{port}));assert(isscalar(link));
endpoint=sprintf('%s.y%d',link.Src,link.SrcPort);
end

function result=mergeMap(result,other)
names=fieldnames(other);for k=1:numel(names),result.(names{k})=other.(names{k});end
end

function labelled=applyPortLabels(model)
% Explicit labels remain visible with an opaque custom mask icon.
blocks=find_system(model,'LookUnderMasks','all','BlockType','SubSystem');
parents=struct;labelled={};
for k=1:numel(blocks)
    block=blocks{k};id=reorg.id(block);
    if ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',block)),continue;end
    if ~isempty(get_param(block,'MaskType')),continue;end % Standard PID masks retain their native icon.
    [inports,outports]=reorg.ports(model,id);
    if isempty(inports)&&isempty(outports),continue;end
    params=struct('ShowPortLabels','FromPortBlockName');
    if strcmp(get_param(block,'Mask'),'on')||strcmp(get_param(block,'Name'),'TickStart400')
        display=char(sprintf("disp('%s');",strrep(get_param(block,'Name'),"'","''")));
        for j=1:numel(inports)
            name=get_param(reorg.path(model,inports{j}),'Name');
            display=[display char(sprintf("port_label('input',%d,'%s');",j,strrep(name,"'","''")))]; %#ok<AGROW>
        end
        for j=1:numel(outports)
            name=get_param(reorg.path(model,outports{j}),'Name');
            display=[display char(sprintf("port_label('output',%d,'%s');",j,strrep(name,"'","''")))]; %#ok<AGROW>
        end
        assert(ischar(display)&&isrow(display));
        params.Mask='on';params.MaskDisplay=display;params.MaskIconOpaque='opaque';
        labelled{end+1}=id; %#ok<AGROW>
    end
    parent=get_param(block,'Parent');if strcmp(parent,model),scope='root';else,scope=reorg.id(parent);end
    if ~isfield(parents,scope),parents.(scope)={};end
    parents.(scope){end+1}=reorg.configure(id,params);
end
scopes=fieldnames(parents);for k=1:numel(scopes),reorg.edit(model,scopes{k},parents.(scopes{k}));end
end
