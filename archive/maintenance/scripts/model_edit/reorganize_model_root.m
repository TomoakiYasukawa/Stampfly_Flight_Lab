function result=reorganize_model_root()
%REORGANIZE_MODEL_ROOT Expose the verified 400 Hz functional processing path.
root=stampfly_project_root();model='StampFly_Official_FlightTest400';
stages=load(fullfile(root,'tests','processing_stage_ids.mat')).stages;
save_system(model);copyfile(get_param(model,'FileName'),fullfile(root,'archive','snapshots','FlightTest_verified_before_root_reorganization.slx'));
result.Core=reorg.lift(model,'blk_38');saveProgress();
result.Acquisition=reorg.lift(model,'blk_612');saveProgress();
result.Correction=mapped(result.Core,stages.Correction.ID);
result.Estimation=mapped(result.Core,stages.Estimation.ID);
result.Control=mapped(result.Core,stages.Control.ID);
result.IMU=mapped(result.Acquisition,'blk_633');result.Battery=mapped(result.Acquisition,'blk_635');
tof=mapped(result.Acquisition,'blk_634');delay=mapped(result.Acquisition,'blk_637');
joystick=mapped(result.Acquisition,'blk_636');ageUnused=mapped(result.Acquisition,'blk_638');errorUnused=mapped(result.Acquisition,'blk_639');
rootLinks=reorg.links(model,'root');
incoming=rootLinks(strcmp({rootLinks.Dst},delay)&[rootLinks.DstPort]==1);
tofInputs=reorg.group('FinalMode',{sprintf('%s.y%d',incoming.Src,incoming.SrcPort)},{'FinalMode'});
tofOutputs=[reorg.group('BottomRange',{[tof '.y1'],[tof '.y2']},{'DistanceMm','Fresh'}), ...
    reorg.group('RangeDiagnostics',{[tof '.y3'],[tof '.y4'],[tof '.y5']},{'FrontDistanceMm','Status','Info'})];
result.ToF=reorg.wrap(model,'root',{tof,delay},'BottomToF400',tofInputs,tofOutputs);saveProgress();
joystickOutputs=[reorg.group('JoystickCommand',{[joystick '.y1'],[joystick '.y2'],[joystick '.y6'],[joystick '.y4'],[joystick '.y5']}, ...
    {'Sticks','ArmButton','NewPacket','AHRSRequest','FlipButton'}), ...
    reorg.group('RadioDiagnostics',{[joystick '.y3'],[joystick '.y7']},{'LinkAge','PacketError'})];
result.Joystick=reorg.wrap(model,'root',{joystick,ageUnused,errorUnused},'JoyStickInput400',struct('Name',{},'Members',{}),joystickOutputs);
saveProgress();
% Main cycle timing and flight-mode feedback are connected directly.
status=mapped(result.Core,'blk_2226');
flightBus=mapped(result.Core,'blk_2230');correctionContext=mapped(result.Core,'blk_1777');estimatorContext=mapped(result.Core,'blk_1778');
reorg.edit(model,'root',{reorg.wire([status '.y1'],[result.ToF.ID '.u1'],'Mode'), ...
    reorg.wire('blk_4.y2',[flightBus '.u7'],'Dt'),reorg.wire('blk_4.y2',[correctionContext '.u2'],'Dt'), ...
    reorg.wire('blk_4.y2',[estimatorContext '.u3'],'Dt'), ...
    struct('op','delete','target','blk_750'),struct('op','delete','target','blk_821')});
saveProgress();
% Auxiliary paths may use globally unique Goto/From tags across wrappers.
gotos=find_system(model,'SearchDepth',1,'BlockType','Goto');operations={};
for k=1:numel(gotos),operations{end+1}=reorg.configure(reorg.id(gotos{k}),struct('TagVisibility','global'));end
reorg.edit(model,'root',operations);
auxiliary={640,'DataLogging50';681,'JoystickFeedback40';666,'LEDAndBuzzer400';702,'Diagnostics400';17,'CycleTiming400'};
result.Auxiliary=struct;
for k=1:size(auxiliary,1)
    source=['blk_' num2str(auxiliary{k,1})];rootLinks=reorg.links(model,'root');
    incoming=rootLinks(strcmp({rootLinks.Dst},source));selected={source};
    for j=1:numel(incoming)
        assert(strcmp(get_param(reorg.path(model,incoming(j).Src),'BlockType'),'From'));
        selected{end+1}=incoming(j).Src;
    end
    selected=unique(selected,'stable');ports=get_param(reorg.path(model,source),'PortHandles');
    outputs=struct('Name',{},'Members',{});
    for j=1:numel(ports.Outport)
        label=outputLabel(source,j);
        outputs(end+1)=reorg.group(label,{sprintf('%s.y%d',source,j)},{label}); %#ok<AGROW>
    end
    result.Auxiliary.(auxiliary{k,2})=reorg.wrap(model,'root',selected,auxiliary{k,2},struct('Name',{},'Members',{}),outputs);
    saveProgress();
end
disp(model_check(model,'root','["all"]'));saveProgress();
    function saveProgress()
        save(fullfile(root,'tests','root_reorganization_ids.mat'),'result');save_system(model);
    end
    function label=outputLabel(id,port)
        path=reorg.path(model,id);
        if strcmp(get_param(path,'BlockType'),'SubSystem')
            [~,outputPorts]=reorg.ports(model,id);label=get_param(reorg.path(model,outputPorts{port}),'Name');
        else,label='Timing';end
    end
end
function id=mapped(result,oldID)
index=find(strcmp(result.Sources,oldID),1);assert(~isempty(index));id=result.Copies{index};
end
