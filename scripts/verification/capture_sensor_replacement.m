function manifest = capture_sensor_replacement()
%CAPTURE_SENSOR_REPLACEMENT Snapshot the actual Chart code and port wiring.
model = 'StampFly_Official_FlightTest400';
manifest = {};
for sid = 117:125
    path = Simulink.ID.getFullName(sprintf('%s:%d',model,sid));
    chart = sfroot().find('-isa','Stateflow.Chart','Path',path);
    fn = chart.find('-isa','Stateflow.EMFunction');
    item = struct('SID',sid,'Name',get_param(path,'Name'), ...
        'Position',get_param(path,'Position'),'Description',get_param(path,'Description'), ...
        'Script',fn.Script,'Sources',{{}},'Destinations',{{}}, ...
        'InputTypes',{{}},'InputSizes',{{}},'OutputTypes',{{}},'OutputSizes',{{}});
    ports = get_param(path,'PortHandles');
    for k=1:numel(ports.Inport)
        line = get_param(ports.Inport(k),'Line');
        src = get_param(line,'SrcPortHandle');
        item.Sources{k} = endpoint(src,'y');
    end
    for k=1:numel(ports.Outport)
        line = get_param(ports.Outport(k),'Line');
        dst = get_param(line,'DstPortHandle');
        item.Destinations{k} = arrayfun(@(p)endpoint(p,'u'),dst,'UniformOutput',false);
    end
    children = chart.getChildren;
    inputs = children(arrayfun(@(d)isa(d,'Stateflow.Data') && strcmp(d.Scope,'Input'),children));
    outputs = children(arrayfun(@(d)isa(d,'Stateflow.Data') && strcmp(d.Scope,'Output'),children));
    [~,order]=sort([inputs.Port]); inputs=inputs(order);
    [~,order]=sort([outputs.Port]); outputs=outputs(order);
    for k=1:numel(inputs)
        item.InputTypes{k}=inputs(k).DataType;
        item.InputSizes{k}=inputs(k).Props.Array.Size;
    end
    for k=1:numel(outputs)
        item.OutputTypes{k}=outputs(k).DataType;
        item.OutputSizes{k}=outputs(k).Props.Array.Size;
    end
    manifest{end+1}=item; %#ok<AGROW>
    fprintf('%d %s inputs=%s outputs=%s\n',sid,item.Name, ...
        join(string(item.InputTypes),','),join(string(item.OutputTypes),','));
end
save('tests/sensor_processing_before.mat','manifest','-append');
end
function value=endpoint(port,kind)
sid=extractAfter(Simulink.ID.getSID(get_param(port,'Parent')),':');
value=sprintf('blk_%s.%s%d',sid,kind,get_param(port,'PortNumber'));
end
