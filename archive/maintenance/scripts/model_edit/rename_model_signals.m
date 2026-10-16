function report=rename_model_signals()
%RENAME_MODEL_SIGNALS Remove generated IDs from visible signal and tag names.
root=stampfly_project_root();model='StampFly_Official_FlightTest400';
gotos=find_system(model,'BlockType','Goto');tagMap=struct('Old',{},'New',{});scoped=struct;
canonical=struct('UsToSeconds','TimeSeconds','TimingEnd400','CycleTiming', ...
    'Duty4','MotorDuty','ModeBeforeTick','PreviousMode','AltFlag','AltitudeEnabled', ...
    'StartUs','CycleStartUs','Dt','SamplePeriod','Scheduler','SchedulerStatus', ...
    'AppliedCounts4','AppliedPWMCounts','PWMInfo4','PWMStatus','Stick6','JoystickSticks', ...
    'ToFInfo4','BottomToFDiagnostics','FrontMm','UnusedFrontRangeMm','AHRSFlag','AttitudeResetRequest', ...
    'PacketError','JoystickPacketError','Temperature','IMUTemperature', ...
    'Accel3','RawAcceleration','Gyro3','RawAngularRate','IMUFresh','IMUSampleFresh', ...
    'BottomMm','BottomDistanceMm','ToFNew','BottomRangeFresh','ToFStatus','BottomRangeStatus', ...
    'BatteryV','BatteryVoltage','BatteryValid','BatteryReadValid','USBDrops','USBFrameDrops', ...
    'RadioQueued','LoggerRadioQueued','LEDMode','LoggerLEDMode','Sent','JoystickTelemetrySent', ...
    'SensorDiag8','SensorDiagnostics','Attitude3','AttitudeAngles','LinkConnected','JoystickConnected', ...
    'ControlDiag17','ControlDiagnostics','Flags3','SensorFlags','FlipFlag','FlipPhase', ...
    'Rates3','FilteredAngularRate','Height','EstimatedAltitude','Mode','FlightMode', ...
    'Quaternion4','AttitudeQuaternion','Velocity','VerticalVelocity');
newNames={};
for k=1:numel(gotos)
    old=get_param(gotos{k},'GotoTag');key=regexprep(old,'_S\d+(?:P\d+)?$','');
    assert(isfield(canonical,key),'official:SignalName','Unmapped tag %s.',old);name=canonical.(key);
    assert(~ismember(name,newNames),'official:SignalCollision','Duplicate readable tag %s.',name);newNames{end+1}=name;
    tagMap(end+1)=struct('Old',old,'New',name); %#ok<AGROW>
    matching=[gotos(k);find_system(model,'BlockType','From','GotoTag',old)];
    for j=1:numel(matching)
        parent=get_param(matching{j},'Parent');scope=scopeID(model,parent);
        if strcmp(get_param(matching{j},'BlockType'),'Goto'),blockName=['Publish' name];else,blockName=['Read' name];end
        existing=find_system(parent,'SearchDepth',1,'Type','Block');existing=setdiff(existing,matching(j));
        existingNames=get_param(existing,'Name');
        blockName=matlab.lang.makeUniqueStrings(blockName,existingNames);
        scoped=append(scoped,scope,reorg.configure(reorg.id(matching{j}),struct('Name',blockName,'GotoTag',name,'ShowName','off')));
    end
end
% Remaining auto-generated specifications get names derived from their data.
blocks=find_system(model,'Type','Block');
for k=2:numel(blocks)
    name=get_param(blocks{k},'Name');
    if isempty(regexp(name,'^spec\d+_\d+$','once')),continue;end
    ph=get_param(blocks{k},'PortHandles');source=get_param(get_param(ph.Inport,'Line'),'SrcPortHandle');
    upstream=get_param(source,'Parent');port=get_param(source,'PortNumber');label=outputLabel(upstream,port);
    newName=[matlab.lang.makeValidName(label) 'Signal'];
    scope=scopeID(model,get_param(blocks{k},'Parent'));
    scoped=append(scoped,scope,reorg.configure(reorg.id(blocks{k}),struct('Name',newName)));
end
scopes=fieldnames(scoped);for k=1:numel(scopes),reorg.edit(model,scopes{k},scoped.(scopes{k}));end
% Give unnamed main outputs explicit unit-aware names without changing buses.
report=struct('TagMap',tagMap,'RenamedTags',numel(tagMap));
save(fullfile(root,'tests','readable_signal_names.mat'),'report');save_system(model);
end
function value=append(value,scope,operation)
if ~isfield(value,scope),value.(scope)={};end
value.(scope){end+1}=operation;
end
function scope=scopeID(model,parent)
if strcmp(parent,model),scope='root';else,scope=reorg.id(parent);end
end
function label=outputLabel(path,port)
if strcmp(get_param(path,'BlockType'),'SubSystem') && isempty(sfroot().find('-isa','Stateflow.EMChart','Path',path))
    [~,out]=reorg.ports(bdroot(path),reorg.id(path));label=get_param(reorg.path(bdroot(path),out{port}),'Name');
elseif strcmp(get_param(path,'BlockType'),'MATLABFcn'),label=get_param(path,'Name');
else
    names=get_param(path,'OutputSignalNames');label=names{port};
    if isempty(label)
        fn=sfroot().find('-isa','Stateflow.EMChart','Path',path);
        if ~isempty(fn),data=fn.find('-isa','Stateflow.Data','Scope','Output');[~,order]=sort([data.Port]);label=data(order(port)).Name;
        else,label=[get_param(path,'Name') 'Output' num2str(port)];end
    end
end
label=regexprep(label,'^arg_','');
end
