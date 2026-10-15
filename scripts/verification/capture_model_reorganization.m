function snapshot = capture_model_reorganization()
%CAPTURE_MODEL_REORGANIZATION Preserve the flight-tested implementations.
% 初回飛行版と今回の編集直前版を独立した比較基準として保持する。
root = stampfly_project_root();
ensure_simulink_toolkit();
gate = library.settingsLookup();
assert(gate.gatePass);
model = 'StampFly_Official_FlightTest400';
open_system(stampfly_model_file(model));
assert(strcmp(get_param(model,'SimulationStatus'),'stopped'));
snapshot = struct;
snapshot.Model = model;
snapshot.InitialFile = fullfile(root,'archive','FlightTest_disk_before_sensor_blocks_20261015_092114.slx');
snapshot.BeforeFile = fullfile(root,'archive','FlightTest_before_state_diagrams_20261015_104413.slx');
assert(isfile(snapshot.InitialFile) && isfile(snapshot.BeforeFile));
snapshot.CapturedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
snapshot.Configuration = get_param(model,'ObjectParameters');
snapshot.Charts = struct('SID',{},'Name',{},'ParentSID',{},'Position',{}, ...
    'Description',{},'Script',{},'InputNames',{},'OutputNames',{}, ...
    'InputTypes',{},'OutputTypes',{},'InputSizes',{},'OutputSizes',{}, ...
    'Sources',{},'Destinations',{});
machine = sfroot().find('-isa','Stateflow.Machine','Name',model);
charts = machine.find('-isa','Stateflow.Chart');
for k = 1:numel(charts)
    chart = charts(k);
    path = chart.Path;
    sid = str2double(extractAfter(Simulink.ID.getSID(path),':'));
    scope = bid(path);
    model_read(model,scope,'0');
    fn = chart.find('-isa','Stateflow.EMFunction');
    assert(numel(fn)==1,'Expected one original embedded function.');
    parent = get_param(path,'Parent');
    if strcmp(parent,model), parentSID='root'; else, parentSID=bid(parent); end
    item = struct('SID',sid,'Name',get_param(path,'Name'),'ParentSID',parentSID, ...
        'Position',get_param(path,'Position'),'Description',get_param(path,'Description'), ...
        'Script',fn.Script,'InputNames',{{}},'OutputNames',{{}}, ...
        'InputTypes',{{}},'OutputTypes',{{}},'InputSizes',{{}},'OutputSizes',{{}}, ...
        'Sources',{{}},'Destinations',{{}});
    children = chart.getChildren;
    inputs = children(arrayfun(@(x)isa(x,'Stateflow.Data') && strcmp(x.Scope,'Input'),children));
    outputs = children(arrayfun(@(x)isa(x,'Stateflow.Data') && strcmp(x.Scope,'Output'),children));
    [~,order] = sort([inputs.Port]); inputs=inputs(order);
    [~,order] = sort([outputs.Port]); outputs=outputs(order);
    ports = get_param(path,'PortHandles');
    for j = 1:numel(inputs)
        item.InputNames{j}=inputs(j).Name;
        item.InputTypes{j}=inputs(j).DataType;
        item.InputSizes{j}=inputs(j).Props.Array.Size;
        line=get_param(ports.Inport(j),'Line');
        item.Sources{j}=endpoint(get_param(line,'SrcPortHandle'),'y');
    end
    for j = 1:numel(outputs)
        item.OutputNames{j}=outputs(j).Name;
        item.OutputTypes{j}=outputs(j).DataType;
        item.OutputSizes{j}=outputs(j).Props.Array.Size;
        line=get_param(ports.Outport(j),'Line');
        destinations=get_param(line,'DstPortHandle');
        item.Destinations{j}=arrayfun(@(p)endpoint(p,'u'),destinations,'UniformOutput',false);
    end
    snapshot.Charts(end+1)=item; %#ok<AGROW>
    fprintf('%d %s (%d inputs / %d outputs)\n',sid,item.Name,numel(inputs),numel(outputs));
end
snapshot.OriginalChartCount = numel(charts);
save(fullfile(root,'tests','model_reorganization_before.mat'),'snapshot');
end
function id=bid(path), id=['blk_' extractAfter(Simulink.ID.getSID(path),':')]; end
function result=endpoint(port,kind)
result=sprintf('%s.%s%d',bid(get_param(port,'Parent')),kind,get_param(port,'PortNumber'));
end
