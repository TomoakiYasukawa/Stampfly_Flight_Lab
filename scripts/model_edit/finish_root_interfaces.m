function result=finish_root_interfaces()
%FINISH_ROOT_INTERFACES Complete auxiliary grouping and compact direct buses.
root=stampfly_project_root();model='StampFly_Official_FlightTest400';
result=load(fullfile(root,'tests','root_reorganization_ids.mat')).result;
auxiliary={681,'JoystickFeedback40';666,'LEDAndBuzzer400';702,'Diagnostics400';17,'CycleTiming400'};
for k=1:size(auxiliary,1)
    if isfield(result.Auxiliary,auxiliary{k,2}),continue;end
    source=['blk_' num2str(auxiliary{k,1})];links=reorg.links(model,'root');
    incoming=links(strcmp({links.Dst},source));selected={source};
    for j=1:numel(incoming),selected{end+1}=incoming(j).Src;end
    selected=unique(selected,'stable');ports=get_param(reorg.path(model,source),'PortHandles');
    outputs=struct('Name',{},'Members',{});
    for j=1:numel(ports.Outport)
        if strcmp(get_param(reorg.path(model,source),'BlockType'),'SubSystem')
            [~,outputPorts]=reorg.ports(model,source);label=get_param(reorg.path(model,outputPorts{j}),'Name');
        else,label='Timing';end
        outputs(end+1)=reorg.group(label,{sprintf('%s.y%d',source,j)},{label}); %#ok<AGROW>
    end
    result.Auxiliary.(auxiliary{k,2})=reorg.wrap(model,'root',selected,auxiliary{k,2},struct('Name',{},'Members',{}),outputs);
    saveProgress();
end
% Connect matching stage buses directly; selectors remain only for logging.
operations={reorg.wire([result.Estimation '.y1'],[result.Control '.u1'],'Attitude'), ...
    reorg.wire([result.Estimation '.y2'],[result.Control '.u2'],'VerticalMotion'), ...
    reorg.wire([result.ToF.ID '.y1'],[result.Correction '.u2'],'BottomRange')};
rootBlocks=find_system(model,'SearchDepth',1,'Type','Block');rootIDs=cellfun(@reorg.id,rootBlocks(2:end),'UniformOutput',false);
for old={'blk_2228','blk_2229','blk_1776'}
    id=mapped(result.Core,old{1});
    if ismember(id,rootIDs),operations{end+1}=struct('op','delete','target',id);end
end
reorg.edit(model,'root',operations);
saveProgress();
% Group feedback conditioning: all original Unit Delays remain in control.
feedback=mapped(result.Core,'blk_2227');corr=mapped(result.Core,'blk_1777');context=mapped(result.Core,'blk_1778');
contextInputs=[reorg.group('EstimatorFeedback',{[result.Control '.y3']},{'EstimatorFeedback'}), ...
    reorg.group('BatteryVoltage',{[result.Battery '.y1']},{'BatteryVoltage'}), ...
    reorg.group('Dt',{'blk_4.y2'},{'Dt'})];
contextOutputs=[reorg.group('CorrectionContext',{[corr '.y1']},{'CorrectionContext'}), ...
    reorg.group('EstimatorContext',{[context '.y1']},{'EstimatorContext'})];
result.Context=reorg.wrap(model,'root',{feedback,corr,context},'EstimatorContext400',contextInputs,contextOutputs);saveProgress();
% Four input ports: joystick bus, battery, Dt and sensor-status bus.
joystickFields=result.Joystick.Fields.Groups.JoystickCommand;
joystickSelector=extractBefore(joystickFields.Sticks,'.y');
flightBus=mapped(result.Core,'blk_2230');sensorFields=mapped(result.Core,'blk_1774');
flightInputs=[reorg.group('JoystickCommand',{[result.Joystick.ID '.y1']},{'JoystickCommand'}), ...
    reorg.group('BatteryVoltage',{[result.Battery '.y1']},{'BatteryVoltage'}), ...
    reorg.group('Dt',{'blk_4.y2'},{'Dt'}), ...
    reorg.group('SensorStatus',{[result.Estimation '.y3']},{'SensorStatus'})];
flightOutputs=reorg.group('FlightInputs',{[flightBus '.y1']},{'FlightInputs'});
% Export command/status taps as buses to retain their auxiliary consumers.
flightOutputs(2)=reorg.group('CommandTap',{[joystickSelector '.y1'],[joystickSelector '.y4']},{'Sticks','AHRSRequest'});
flightOutputs(3)=reorg.group('SensorTap',{[sensorFields '.y1'],[sensorFields '.y2']},{'Flags','Diagnostics'});
result.FlightInputs=reorg.wrap(model,'root',{char(joystickSelector),flightBus,sensorFields},'FlightInputBus400',flightInputs,flightOutputs);
saveProgress();
reorg.edit(model,'root',{reorg.add('Terminator','RawRadioAgeUnused','ageEnd'),reorg.wire('blk_2962.y1','#ageEnd.u1')});
saveProgress();disp(model_check(model,'root','["all"]'));
    function saveProgress()
        save(fullfile(root,'tests','root_reorganization_ids.mat'),'result');save_system(model);
    end
end
function id=mapped(result,old)
id=result.Copies{find(strcmp(result.Sources,old),1)};
end
