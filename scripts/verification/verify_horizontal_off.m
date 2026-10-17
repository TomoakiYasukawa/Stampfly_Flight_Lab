function report=verify_horizontal_off(reuseHarness)
%VERIFY_IMU_CLEANUP Replay saved models before/after hierarchy changes.
% Real block copies include the moved Stateflow and both sets of log publishers.
% No physical inputs, motor output or flight commands run in these harnesses.
if nargin==0,reuseHarness=false;end
root=stampfly_project_root();init_imu_flight();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler('HorizontalOffComparison'); %#ok<NASGU>
addpath(fullfile(root,'tests'));
[~,~,~,~,motionFixture]=horizontal.fixture();motionFixture.Status(:)=0;
assignin('base','HorizontalOffMotion',motionFixture);
models={'HorizontalBaseline','StampFly_IMU400'};
baselineFile=fullfile(root,'archive','snapshots','HorizontalBaseline.slx');
if ~isfolder(fileparts(baselineFile)),mkdir(fileparts(baselineFile));end
assert(isfile(baselineFile));
files={baselineFile,fullfile(root,[models{2} '.slx'])};
for k=1:2,open_system(files{k});end
structure=jsondecode(fileread(fullfile(root,'docs','history','imu_readability_structure.json')));
folder=fullfile(root,'build','horizontal_control','off_tests');if ~isfolder(folder),mkdir(folder);end
harness='HorizontalOffComparison';
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
        if pair==2
            inputs(end+1)=reorg.group('HorizontalMotion',{'blk_4274.y1'},{'HorizontalMotion'});
        end
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
        if pair==2
            [~,~,~,~,motionFixture]=horizontal.fixture();motionFixture.Status(:)=0;
            assignin('base','HorizontalOffMotion',motionFixture);
            ops{end+1}=reorg.add('Constant','DisabledHorizontalMotion','disabledMotion',struct('Value','HorizontalOffMotion','OutDataTypeStr','Bus: HorizontalMotionBus'));
            ops{end+1}=reorg.wire('#disabledMotion.y1',[groups{pair}.ID '.u6']);
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
report=struct('BaselineArchive','archive/snapshots/HorizontalBaseline.slx','Model','StampFly_IMU400.slx','ModelSHA256',sha256(files{2}), ...
    'BaselineModelSHA256',sha256(files{1}),'Outputs',{labels},'Samples',0,'AbsoluteTolerance',0, ...
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
    assert(trace.t(end)<=30,'cleanup:InfiniteReplay','Replay must be finite and at most 30 seconds.');
    in=in.setModelParameter('StopTime',num2str(trace.t(end),17));commands=find_system(harness,'LookUnderMasks','all','BlockType','MATLABSystem','System','horizontal.Command');
    assert(isscalar(commands));in=in.setBlockParameter(commands{1},'Enabled','false');
    out=sim(in);
    result=struct('Samples',numel(trace.t),'MismatchCounts',zeros(1,numel(labels)), ...
        'MaxErrors',zeros(1,numel(labels)),'TypesMatch',true,'SizesMatch',true,'Modes',[]);
    for k=1:numel(labels)
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        result.TypesMatch=result.TypesMatch&&strcmp(class(a),class(b));
        result.SizesMatch=result.SizesMatch&&isequal(size(a),size(b));assert(result.SizesMatch);
        result.MismatchCounts(k)=nnz(a~=b & ~(isnan(a)&isnan(b)));
        result.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
    end
    result.Modes=double(unique(out.yout{5}.Values.Data))';
    report.Cases.(cases{c})=result;report.Samples=report.Samples+numel(trace.t);
    if ~(result.TypesMatch&&all(result.MismatchCounts==0))
        save(fullfile(folder,[cases{c} '_failure.mat']),'out','report');
        error('imu400:ReadabilityChanged','%s differs: %s',cases{c},mat2str(result.MismatchCounts));
    end
    fprintf('HORIZONTAL_OFF_EQUIVALENT: %s (%d ticks, %d outputs)\n',cases{c},numel(trace.t),numel(labels));
    save(replayCheckpoint,'report');
end
report.HorizontalAssistDisabled=true;
report.ExistingPIDAndSupervisorVerifiedSeparately=true;
report.PIDCount=numel(find_system(models{2},'LookUnderMasks','all','Name','DedicatedPID'));
assert(report.PIDCount==7);
report.Passed=true;
writeJSON(fullfile(root,'docs','horizontal_off_verification.json'),report);
fprintf('HORIZONTAL_OFF_VERIFICATION_PASSED\n');
end

function isolateTags(model,group,prefix)
blocks=find_system(reorg.path(model,group),'LookUnderMasks','all','Type','Block');parents=struct;
for k=1:numel(blocks)
    if ~ismember(get_param(blocks{k},'BlockType'),{'Goto','From'}),continue;end
    parent=reorg.id(get_param(blocks{k},'Parent'));tag=get_param(blocks{k},'GotoTag');
    if ~isfield(parents,parent),parents.(parent)={};end
    parents.(parent){end+1}=reorg.configure(reorg.id(blocks{k}),struct('GotoTag',[prefix strrep(tag,'400','')]));
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
