function report=verify_kf_flight400(reuseHarness)
%VERIFY_KF_FLIGHT400 Compare saved models before/after altitude filter replacement.
% Real block copies include Stateflow, PID control and both log publishers.
% No physical inputs, motor output or flight commands run in these harnesses.
if nargin==0,reuseHarness=false;end
root=stampfly_project_root();init_kf_flight();ensure_simulink_toolkit();
layoutListeners=layout.LayoutListeners();
layoutDisabler=layoutListeners.getScopedLayoutListenerDisabler('KFFlightComparison400'); %#ok<NASGU>
addpath(fullfile(root,'tests'));
models={'StampFly_IMU400','StampFly_KF400'};
files={fullfile(root,[models{1} '.slx']),fullfile(root,[models{2} '.slx'])};
for k=1:2,open_system(files{k});end
structure=jsondecode(fileread(fullfile(root,'docs','history','imu_readability_structure.json')));
folder=fullfile(root,'build','kf400','tests');if ~isfolder(folder),mkdir(folder);end
harness='KFFlightComparison400';
labels={'Duty','Counts','Mode','Angles','AngularRate','Altitude','Velocity','Quaternion', ...
    'SensorFlags','ControlDiagnostics','SensorDiagnostics','PreviousMode','AltitudeEnabled','Connected', ...
    'FeedbackMode','FeedbackAltitudeEnabled','FeedbackAttitudeReset','FeedbackParkingReset', ...
    'FilteredAcceleration','FilteredGyro','VerticalDelta','VerticalAcceleration','FilteredRange','RawRange', ...
    'Offsets','CalibrationSamples','PublishedAngles','PublishedQuaternion','PublishedRate', ...
    'PublishedAltitude','PublishedVelocity','PublishedMode','PublishedPreviousMode', ...
    'PublishedAltitudeEnabled','PublishedConnected','PublishedControlDiagnostics'};
names={'Acceleration','AngularRate','BottomDistanceMm','BottomFresh','BatteryVoltage', ...
    'Sticks','ArmButton','NewPacket','AHRSRequest','Dt'};
types={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single'};
dims=[3 3 1 1 1 6 1 1 1 1];
if ~reuseHarness
    if bdIsLoaded(harness),close_system(harness,0);end
    new_system(harness);open_system(harness);
    common={'blk_2721','blk_2231','blk_2274','blk_3131','blk_3213'};
    selection=[common {structure.FlightStateFields,structure.Supervisor, ...
        structure.SupervisorPilotFields,structure.SupervisorCommandBus}];
    selected={selection,selection};
    dt={[structure.TickStart '.y1'],[structure.TickStart '.y1']};groups=cell(1,2);
    outputGroups=[reorg.group('MotorCommand',{'blk_2274.y1'},{'MotorCommand'}), ...
        reorg.group('FlightStatus',{'blk_2274.y2'},{'FlightStatus'}), ...
        reorg.group('Attitude',{'blk_2231.y1'},{'Attitude'}), ...
        reorg.group('VerticalMotion',{'blk_2231.y2'},{'VerticalMotion'}), ...
        reorg.group('SensorStatus',{'blk_2231.y3'},{'SensorStatus'}), ...
        reorg.group('EstimatorFeedback',{'blk_2274.y3'},{'EstimatorFeedback'}), ...
        reorg.group('FilteredIMU',{'blk_2721.y1'},{'FilteredIMU'}), ...
        reorg.group('HeightInputs',{'blk_2721.y2'},{'HeightInputs'}), ...
        reorg.group('Calibration',{'blk_2721.y3'},{'Calibration'})];
    for pair=1:2
        inputs=[reorg.group('RawIMU',{'blk_3161.y1'},{'RawIMU'}), ...
            reorg.group('BottomRange',{'blk_3178.y1'},{'BottomRange'}), ...
            reorg.group('BatteryVoltage',{'blk_3171.y1'},{'BatteryVoltage'}), ...
            reorg.group('JoystickCommand',{'blk_3198.y1'},{'JoystickCommand'}), ...
            reorg.group('Dt',{dt{pair}},{'Dt'})];
        groups{pair}=reorg.groupCopy(models{pair},'root','root',selected{pair}, ...
            ['Pipeline' num2str(pair)],inputs,outputGroups,harness);
        isolateTags(harness,groups{pair}.ID,['Case' num2str(pair) '_']);
    end
    ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
        'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset'))};
    for k=1:numel(names)
        ops{end+1}=reorg.add('Inport',names{k},['i' num2str(k)],struct('Port',num2str(k), ...
            'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025')); %#ok<AGROW>
    end
    buses={'RawIMU','Bottom','Pilot'};
    fields={{'Acceleration','AngularRate'},{'DistanceMm','Fresh'}, ...
        {'Sticks','ArmButton','NewPacket','AHRSRequest'}};
    indices={[1 2],[3 4],[6 7 8 9]};
    for k=1:numel(buses)
        ops{end+1}=reorg.add('BusCreator',[buses{k} 'Bus'],buses{k}, ...
            struct('Inputs',num2str(numel(indices{k})))); %#ok<AGROW>
        for j=1:numel(indices{k})
            ops{end+1}=reorg.wire(sprintf('#i%d.y1',indices{k}(j)), ...
                sprintf('#%s.u%d',buses{k},j),fields{k}{j}); %#ok<AGROW>
        end
    end
    feeds={'#RawIMU.y1','#Bottom.y1','#i5.y1','#Pilot.y1','#i10.y1'};
    selectors={'Duty,Counts','Mode,PreviousMode,AltitudeEnabled,Connected,Diagnostics', ...
        'Angles,Quaternion,AngularRate','Altitude,Velocity','Flags,Diagnostics', ...
        'PreviousMode,AltitudeEnabled,AttitudeReset,ParkingReset', ...
        'Acceleration,AngularRate,VerticalDelta','VerticalAcceleration,FilteredRange,RawRange','Offsets,Samples'};
    endpoints={[1 1],[1 2],[2 1],[3 1],[3 3],[4 1],[4 2],[3 2], ...
        [5 1],[2 5],[5 2],[2 2],[2 3],[2 4],[6 1],[6 2],[6 3],[6 4], ...
        [7 1],[7 2],[7 3],[8 1],[8 2],[8 3],[9 1],[9 2]};
    tags={'AttitudeAngles','AttitudeQuaternion','FilteredAngularRate','EstimatedAltitude', ...
        'VerticalVelocity','FlightMode','PreviousMode','AltitudeEnabled','JoystickConnected','ControlDiagnostics'};
    for pair=1:2
        for k=1:numel(feeds)
            ops{end+1}=reorg.wire(feeds{k},sprintf('%s.u%d',groups{pair}.ID,k)); %#ok<AGROW>
        end
        refs=cell(1,numel(selectors));
        for k=1:numel(selectors)
            refs{k}=sprintf('case%dbus%d',pair,k);
            ops{end+1}=reorg.add('BusSelector',refs{k},refs{k},struct('OutputSignals',selectors{k})); %#ok<AGROW>
            ops{end+1}=reorg.wire(sprintf('%s.y%d',groups{pair}.ID,k),['#' refs{k} '.u1']); %#ok<AGROW>
        end
        for k=1:numel(labels)
            ref=sprintf('case%dout%d',pair,k);
            ops{end+1}=reorg.add('Outport',sprintf('Case%d%s',pair,labels{k}),ref, ...
                struct('Port',num2str(2*k-2+pair))); %#ok<AGROW>
            if k<=numel(endpoints)
                src=sprintf('#%s.y%d',refs{endpoints{k}(1)},endpoints{k}(2));
            else
                tag=tags{k-numel(endpoints)};reader=sprintf('case%dtag%d',pair,k);
                ops{end+1}=reorg.add('From',reader,reader, ...
                    struct('GotoTag',sprintf('Case%d_%s',pair,tag))); %#ok<AGROW>
                src=['#' reader '.y1'];
            end
            ops{end+1}=reorg.wire(src,['#' ref '.u1']); %#ok<AGROW>
        end
    end
    reorg.edit(harness,'root',ops,'full');
    save_system(harness,fullfile(folder,[harness '.slx']));
else
    open_system(fullfile(folder,[harness '.slx']));
end
report=struct('Model','archive/kf400/StampFly_KF400.slx','ModelSHA256',sha256(files{2}), ...
    'BaselineModelSHA256',sha256(files{1}),'Outputs',{labels},'Samples',0,'ExactEquivalenceRequired',false, ...
    'PhysicalFlightTested',false,'Flashed',false,'Passed',false,'Cases',struct);
cases={'BootTakeoffHoverLanding','ModeAndFlip','SensorTimingAndInterruptions'};
replayCheckpoint=fullfile(folder,'replay_report.mat');
if reuseHarness&&isfile(replayCheckpoint)
    previous=load(replayCheckpoint,'report').report;
    if strcmp(previous.ModelSHA256,report.ModelSHA256)&& ...
            strcmp(previous.BaselineModelSHA256,report.BaselineModelSHA256)
        report=previous;
    end
end
for c=1:numel(cases)
    if isfield(report.Cases,cases{c}),continue;end
    trace=load(fullfile(root,'tests',['reorganized_core_' cases{c} '.mat']),'values','t');
    ds=Simulink.SimulationData.Dataset;
    for k=1:numel(names)
        ts=timeseries(trace.values{k},trace.t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
        ds=ds.addElement(ts,names{k});
    end
    in=Simulink.SimulationInput(harness);in=in.setExternalInput(ds);
    in=in.setModelParameter('StopTime',num2str(trace.t(end),17));out=sim(in);
    result=struct('Samples',numel(trace.t),'MismatchCounts',zeros(1,numel(labels)), ...
        'MaxErrors',zeros(1,numel(labels)),'TypesMatch',true,'SizesMatch',true,'Finite',true,'Modes',[]);
    for k=1:numel(labels)
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        result.TypesMatch=result.TypesMatch&&strcmp(class(a),class(b));
        result.SizesMatch=result.SizesMatch&&isequal(size(a),size(b));assert(result.SizesMatch);
        result.Finite=result.Finite&&all(isfinite(a),'all')&&all(isfinite(b),'all');
        result.MismatchCounts(k)=nnz(a~=b & ~(isnan(a)&isnan(b)));
        result.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
    end
    result.Modes=double(unique(out.yout{5}.Values.Data))';
    report.Cases.(cases{c})=result;report.Samples=report.Samples+numel(trace.t);
    save(fullfile(folder,[cases{c} '_pipeline.mat']),'out','report');
    assert(result.TypesMatch&&result.SizesMatch&&result.Finite);
    % Diagnostics include the altitude controller output and are assessed with
    % Duty/Counts. All other estimator/control inputs and mode flags must match.
    unchanged=[3 4 5 8 9 12:29 32:35];
    result.UnchangedSignalsIdentical=all(result.MismatchCounts(unchanged)==0);
    result.EstimatorErrors=result.MaxErrors([6 7]);
    result.MaximumPWMCountDifference=result.MaxErrors(2);
    result.MaximumDutyDifference=result.MaxErrors(1);
    report.Cases.(cases{c})=result;
    assert(result.UnchangedSignalsIdentical,'kf400:UnexpectedChange','Signals outside altitude estimation differ.');
    fprintf('KF400_FULL_PIPELINE_COMPARED: %s (%d ticks, %d outputs)\n',cases{c},numel(trace.t),numel(labels));
    save(replayCheckpoint,'report');
end
report.Structure=verifyUnchanged(models,structure);
report.Passed=false;
writeJSON(fullfile(root,'docs','history','kf_flight_verification.json'),report);
report.Logging=verifyLogging(root,models,structure,folder);
report.PIDCount=numel(find_system(models{2},'LookUnderMasks','all','Name','DedicatedPID'));
assert(report.PIDCount==7);
report.Component=jsondecode(fileread(fullfile(root,'docs','history','kf_altitude_verification.json')));
report.AllComparisonsCompleted=true;
report.Passed=false; % numerical differences require the recorded engineering assessment
writeJSON(fullfile(root,'docs','history','kf_flight_verification.json'),report);
fprintf('KF400_FLIGHT_COMPARISON_COMPLETE\n');
end

function result=verifySupervisor(models,s)
a=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(models{1},s.Supervisor));
b=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(models{2},s.Supervisor));
assert(isscalar(a)&&isscalar(b));assert(strcmp(b.Path,[models{2} '/OfficialFlightSupervisor']));
sa=a.find('-isa','Stateflow.State');sb=b.find('-isa','Stateflow.State');
assert(isequal(sort(string({sa.LabelString})),sort(string({sb.LabelString}))));
ta=transitionSignatures(a);tb=transitionSignatures(b);assert(isequal(ta,tb));
da=dataSignatures(a);db=dataSignatures(b);
if ~isequal(da,db)
    disp('SUPERVISOR_DATA_BEFORE_ONLY');disp(setdiff(da,db));
    disp('SUPERVISOR_DATA_AFTER_ONLY');disp(setdiff(db,da));
end
assert(isequal(da,db),'imu400:SupervisorDataChanged','Stateflow data signatures differ.');
result=struct('AtRoot',true,'StateCount',numel(sa),'TransitionCount',numel(ta), ...
    'StatesTransitionsDataAndPrioritiesIdentical',true);
end

function signatures=transitionSignatures(chart)
t=chart.find('-isa','Stateflow.Transition');signatures=strings(numel(t),1);
for k=1:numel(t)
    source="default";destination="none";
    if ~isempty(t(k).Source),source=endpointSignature(t(k).Source);end
    if ~isempty(t(k).Destination),destination=endpointSignature(t(k).Destination);end
    signatures(k)=source+" | "+destination+" | "+string(t(k).LabelString)+" | "+string(t(k).ExecutionOrder);
end
signatures=sort(signatures);
end

function signature=endpointSignature(object)
signature=string(class(object))+":"+string(object.SSIdNumber);
if isa(object,'Stateflow.State'),signature=signature+":"+string(object.LabelString);end
end

function signatures=dataSignatures(chart)
data=chart.find('-isa','Stateflow.Data');signatures=strings(numel(data),1);
for k=1:numel(data)
    % Local data has Port=NaN. string(NaN) makes the entire signature missing,
    % hiding its other fields and making equal signatures compare unequal.
    signatures(k)=string(data(k).Name)+" | "+string(data(k).Scope)+" | "+string(mat2str(data(k).Port))+ ...
        " | "+string(data(k).DataType)+" | "+string(data(k).Props.Array.Size)+ ...
        " | "+string(data(k).Props.InitialValue);
end
signatures=sort(signatures);
end

function result=verifyTiming(models,s)
a=reorg.path(models{1},s.Clock);b=reorg.path(models{2},s.Clock);
assert(strcmp(get_param(a,'System'),get_param(b,'System')));
assert(strcmp(get_param(a,'SampleTime'),get_param(b,'SampleTime')));
assert(strcmp(get_param(a,'Priority'),get_param(b,'Priority')));
assert(strcmp(get_param(b,'Parent'),reorg.path(models{2},s.TickStart)));
for old={s.BlockMap.blk_3290,s.BlockMap.blk_3291,s.BlockMap.blk_3292,s.BlockMap.blk_3293,s.BlockMap.blk_3288}
    aa=reorg.path(models{1},old{1});bb=reorg.path(models{2},old{1});
    if strcmp(get_param(aa,'BlockType'),'Goto')
        assert(strcmp(get_param(aa,'GotoTag'),get_param(bb,'GotoTag')));
    else
        assert(strcmp(get_param(aa,'Gain'),get_param(bb,'Gain')));
        assert(strcmp(get_param(aa,'OutDataTypeStr'),get_param(bb,'OutDataTypeStr')));
    end
end
result=struct('ClockAndPriorityPreserved',true,'TimeConversionAndPublishedTagsPreserved',true);
end

function result=verifyLogging(root,models,s,folder)
% Copy each complete saved DataLogging subsystem and drive nonzero real buses.
harness='KFLoggingComparison400';if bdIsLoaded(harness),close_system(harness,0);end
new_system(harness);open_system(harness);
[raw,estimate,control,extra]=logging_fixture();
control=rmfield(control,'FlipPhase');control.Pilot=rmfield(control.Pilot,'FlipButton');
extra.Distance.PositionEN=single([.12;-.08]);extra.Distance.Used=uint8(1);
extra.Distance.DeltaEN=single([.01;-.015]);
tags={'RawAcceleration','RawAngularRate','IMUSampleFresh','TimeSeconds','BottomDistanceMm', ...
    'BottomRangeFresh','BottomRangeStatus','BatteryVoltage','BatteryReadValid','BottomToFDiagnostics', ...
    'IMUTemperature','AttitudeAngles','EstimatedAltitude','VerticalVelocity','ControlDiagnostics', ...
    'SensorDiagnostics','FilteredAcceleration','FilteredAngularRate','AttitudeQuaternion','SensorFlags', ...
    'MotorDuty','AppliedPWMCounts','PWMStatus','JoystickPacketError','JoystickConnected','AltitudeEnabled', ...
    'PreviousMode','FlightMode','SamplePeriod','CycleStartUs','JoystickSticks','JoystickPilot', ...
    'CycleTiming','SchedulerStatus','LogOpticalFlow400','LogMagneticField400','LogFlowDistance50'};
values={raw.Acceleration,raw.AngularRate,raw.IMUFresh,raw.Time,raw.BottomMm,raw.ToFFresh,raw.ToFStatus, ...
    raw.Voltage,raw.BatteryValid,raw.ToFInfo,raw.Temperature,estimate.Angles,estimate.Height,estimate.Velocity, ...
    estimate.ControlDiagnostics,estimate.SensorDiagnostics,estimate.FilteredAccel,estimate.FilteredGyro, ...
    estimate.Quaternion,estimate.Flags,control.Duty,control.AppliedCounts,control.PWMStatus,control.PacketError, ...
    control.Connected,control.AltitudeEnabled,control.PreviousMode,control.Mode,control.Dt,control.StartUs, ...
    control.UsedSticks,control.Pilot,extra.Timing,extra.Scheduler,extra.Flow,extra.Mag,extra.Distance};
ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
    'StopTime','.4','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    reorg.add(reorg.path(models{1},'blk_2963'),'BeforeLogging','before'), ...
    reorg.add(reorg.path(models{2},'blk_2963'),'AfterLogging','after')};
reply=reorg.edit(harness,'root',ops,'full');
groups={reorg.path(harness,reorg.created(reply,'before')), ...
    reorg.path(harness,reorg.created(reply,'after'))};
ops={};
for k=1:numel(tags)
    variable=['ReadabilityLogValue' num2str(k)];assignin('base',variable,values{k});
    [feed,fixtureOps]=fixtureFeed(variable,values{k},['fixture' num2str(k)],'.0025');
    ops=[ops fixtureOps]; %#ok<AGROW>
    for pair=1:2
        ref=sprintf('publish%d_%d',pair,k);
        ops{end+1}=reorg.add('Goto',ref,ref,struct('GotoTag',sprintf('Log%d_%s',pair,tags{k}), ...
            'TagVisibility','global')); %#ok<AGROW>
        ops{end+1}=reorg.wire([feed '.y1'],['#' ref '.u1']); %#ok<AGROW>
    end
end
reorg.edit(harness,'root',ops);
for pair=1:2
    group=groups{pair};isolateTags(harness,reorg.id(group),sprintf('Log%d_',pair));
    pack=find_system(group,'LookUnderMasks','all','BlockType','MATLABSystem','System','basic.ExtendedLogger50');
    assert(isscalar(pack));packID=reorg.id(pack{1});ops={};
    % Normalize only the logger revision in the comparison copies.
    ops{end+1}=reorg.configure(packID,struct('FirmwareRevision','uint32(1801)'));
    for k=1:3
        ref=['frame' num2str(k)];
        ops{end+1}=reorg.add('Outport',['Frame' num2str(k)],ref,struct('Port',num2str(3+k))); %#ok<AGROW>
        ops{end+1}=reorg.wire(sprintf('%s.y%d',packID,k),['#' ref '.u1']); %#ok<AGROW>
    end
    reorg.edit(harness,reorg.id(group),ops);
end
ops={};
for pair=1:2
    for k=1:6
        ref=sprintf('log%dout%d',pair,k);
        ops{end+1}=reorg.add('Outport',ref,ref,struct('Port',num2str(2*k-2+pair))); %#ok<AGROW>
        ops{end+1}=reorg.wire(sprintf('%s.y%d',reorg.id(groups{pair}),k),['#' ref '.u1']); %#ok<AGROW>
    end
end
reorg.edit(harness,'root',ops);
save_system(harness,fullfile(folder,[harness '.slx']));out=sim(harness);
for k=1:6
    assert(isequaln(out.yout{2*k-1}.Values.Data,out.yout{2*k}.Values.Data), ...
        'imu400:LoggingChanged','Saved logger output %d changed.',k);
end
% Decode all three actual packets, including their CRCs and reserved bytes.
for k=4:6
    packets=squeeze(out.yout{2*k}.Values.Data);lengths=[190 190 246];
    if size(packets,1)~=lengths(k-3),packets=packets.';end
    packet=packets(:,end);
    if k==4,imu.decodeFrame(packet);else,imu.decodeExtensionFrame(packet);end
end
command=squeeze(out.yout{10}.Values.Data);if size(command,1)~=190,command=command.';end
assert(all(command([150 154],:)==0,'all'));
sensor=squeeze(out.yout{12}.Values.Data);if size(sensor,1)~=246,sensor=sensor.';end
assert(isequal(typecast(sensor(91:98,end),'single'),extra.Flow.Delta));
assert(isequal(typecast(sensor(139:162,end),'uint32'),extra.Mag.Info));
assert(isequal(typecast(sensor(225:240,end),'uint32'),raw.ToFInfo));
for k=1:3
    publisher=reorg.path(models{2},s.SensorLogPublishers{k});reader=reorg.path(models{2},s.SensorLogReaders{k});
    assert(strcmp(get_param(publisher,'GotoTag'),get_param(reader,'GotoTag')));
    assert(strcmp(get_param(publisher,'TagVisibility'),'global'));
end
for pair=[3193 4002;3194 4003;3195 4004;3196 4007]'
    assert(strcmp(get_param(reorg.path(models{2},['blk_' num2str(pair(1))]),'GotoTag'), ...
        get_param(reorg.path(models{2},['blk_' num2str(pair(2))]),'GotoTag')));
end
result=struct('CompleteSavedLoggerCompared',true,'RevisionNormalizedInHarness',true,'NonzeroFlowMagneticAndToFVerified',true, ...
    'PacketBytes',[190 190 246],'CRCsValid',true,'ReservedFlipFieldsZero',true,'Passed',true);
fprintf('KF400_LOGGING_FORMAT_EQUIVALENT\n');
end

function [id,ops]=fixtureFeed(variable,value,name,sampleTime)
id=['#' name];
if ~isstruct(value)
    ops={reorg.add('Constant',name,name,struct('Value',variable,'SampleTime',sampleTime))};return;
end
fields=fieldnames(value);feeds=cell(1,numel(fields));ops={};
for k=1:numel(fields)
    [feeds{k},children]=fixtureFeed([variable '.' fields{k}],value.(fields{k}), ...
        [name '_' fields{k}],sampleTime);
    ops=[ops children]; %#ok<AGROW>
end
ops{end+1}=reorg.add('BusCreator',name,name,struct('Inputs',num2str(numel(fields))));
for k=1:numel(fields),ops{end+1}=reorg.wire([feeds{k} '.y1'],sprintf('%s.u%d',id,k),fields{k});end %#ok<AGROW>
end

function isolateTags(model,group,prefix)
blocks=find_system(reorg.path(model,group),'LookUnderMasks','all','Type','Block');parents=struct;
for k=1:numel(blocks)
    if ~ismember(get_param(blocks{k},'BlockType'),{'Goto','From'}),continue;end
    parent=reorg.id(get_param(blocks{k},'Parent'));tag=get_param(blocks{k},'GotoTag');
    if ~isfield(parents,parent),parents.(parent)={};end
    parents.(parent){end+1}=reorg.configure(reorg.id(blocks{k}),struct('GotoTag',[prefix tag]));
end
scopes=fieldnames(parents);for k=1:numel(scopes),reorg.edit(model,scopes{k},parents.(scopes{k}));end
end

function digest=sha256(file)
command=sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"', ...
    strrep(file,'''',''''''));
[status,value]=system(command);assert(status==0);digest=lower(strtrim(value));
assert(~isempty(regexp(digest,'^[0-9a-f]{64}$','once')));
end

function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end


function result=verifyUnchanged(models,structure)
sections={'blk_2721','blk_2274','blk_3131','blk_3213','blk_4038','blk_4119','blk_2253','blk_2244'};
count=0;
for k=1:numel(sections)
    a=reorg.path(models{1},sections{k});b=reorg.path(models{2},sections{k});
    aa=find_system(a,'LookUnderMasks','all','Type','Block');
    bb=find_system(b,'LookUnderMasks','all','Type','Block');assert(numel(aa)==numel(bb));
    for j=1:numel(aa)
        sid=Simulink.ID.getSID(aa{j});id=['blk_' extractAfter(sid,[models{1} ':'])];
        other=reorg.path(models{2},id);
        assert(strcmp(get_param(aa{j},'BlockType'),get_param(other,'BlockType')));
        params=get_param(aa{j},'DialogParameters');
        if isstruct(params)
            for parameter=string(fieldnames(params))'
                assert(isequaln(get_param(aa{j},parameter),get_param(other,parameter)), ...
                    'kf400:ParameterChanged','%s / %s changed.',id,parameter);
            end
        end
        if strcmp(get_param(aa{j},'BlockType'),'SubSystem')
            if strcmp(get_param(aa{j},'SFBlockType'),'MATLAB Function')
                assert(strcmp(get_param(aa{j},'MATLABFunctionConfiguration').FunctionScript, ...
                    get_param(other,'MATLABFunctionConfiguration').FunctionScript));
            else
                assert(isequal(reorg.links(models{1},id),reorg.links(models{2},id)));
            end
        end
        count=count+1;
    end
end
result=struct('ComparedBlocks',count,'ParametersAlgorithmsAndWiringIdentical',true, ...
    'Supervisor',verifySupervisor(models,structure),'Timing',verifyTiming(models,structure));
end
