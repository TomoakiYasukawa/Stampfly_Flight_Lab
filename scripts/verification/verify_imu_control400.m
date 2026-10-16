function report=verify_imu_control400(reuseHarness)
%VERIFY_IMU_CONTROL400 Compare actual pipelines with identical estimator inputs.
% Replays the existing three sensor/pilot traces. Estimator outputs are supplied
% identically, so differences in attitude algorithms cannot mask control edits.
if nargin==0,reuseHarness=false;end
root=stampfly_project_root();init_imu_flight();ensure_simulink_toolkit();
models={'StampFly_Basic400','StampFly_IMU400'};
for k=1:2,open_system(fullfile(root,[models{k} '.slx']));end
folder=fullfile(root,'build','imu400','tests');if ~isfolder(folder),mkdir(folder);end
harness='IMUControlComparison400';
labels={'Duty','Counts','Mode','ControlDiagnostics','PreviousMode','AltitudeEnabled','Connected', ...
    'FilteredAcceleration','FilteredGyro','VerticalDelta','VerticalAcceleration','FilteredRange', ...
    'RawRange','Offsets','CalibrationSamples'};
names={'Acceleration','AngularRate','BottomDistanceMm','BottomFresh','BatteryVoltage', ...
    'Sticks','ArmButton','NewPacket','AHRSRequest','Dt','Angles','EstimatedRate','Quaternion', ...
    'Altitude','Velocity','SensorFlags','SensorDiagnostics'};
types={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single', ...
    'single','single','single','single','single','uint8','single'};
dims=[3 3 1 1 1 6 1 1 1 1 3 3 4 1 1 3 8];
if ~reuseHarness
    if bdIsLoaded(harness),close_system(harness,0);end
    new_system(harness);open_system(harness);
    selected={'blk_2721','blk_2274','blk_3131','blk_3213'};
    inputs=[reorg.group('RawIMU',{'blk_3161.y1'},{'RawIMU'}), ...
        reorg.group('BottomRange',{'blk_3178.y1'},{'BottomRange'}), ...
        reorg.group('BatteryVoltage',{'blk_3171.y1'},{'BatteryVoltage'}), ...
        reorg.group('JoystickCommand',{'blk_3198.y1'},{'JoystickCommand'}), ...
        reorg.group('Dt',{'blk_4.y2'},{'Dt'}), ...
        reorg.group('Attitude',{'blk_2231.y1'},{'Attitude'}), ...
        reorg.group('VerticalMotion',{'blk_2231.y2'},{'VerticalMotion'}), ...
        reorg.group('SensorStatus',{'blk_2231.y3'},{'SensorStatus'})];
    outputs=[reorg.group('MotorCommand',{'blk_2274.y1'},{'MotorCommand'}), ...
        reorg.group('FlightStatus',{'blk_2274.y2'},{'FlightStatus'}), ...
        reorg.group('FilteredIMU',{'blk_2721.y1'},{'FilteredIMU'}), ...
        reorg.group('HeightInputs',{'blk_2721.y2'},{'HeightInputs'}), ...
        reorg.group('Calibration',{'blk_2721.y3'},{'Calibration'})];
    groups=cell(1,2);
    for k=1:2
        groups{k}=reorg.groupCopy(models{k},'root','root',selected,['Pipeline' num2str(k)],inputs,outputs,harness);
        isolateTags(harness,groups{k}.ID,['Case' num2str(k) '_']);
    end
    ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
        'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset'))};
    for k=1:numel(names)
        ops{end+1}=reorg.add('Inport',names{k},['i' num2str(k)],struct('Port',num2str(k), ...
            'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025'));
    end
    buses={'RawIMU','Bottom','Pilot','Attitude','Vertical','Sensors'};
    fields={{'Acceleration','AngularRate'},{'DistanceMm','Fresh'},{'Sticks','ArmButton','NewPacket','AHRSRequest'}, ...
        {'Angles','Quaternion','AngularRate'},{'Altitude','Velocity'},{'Flags','Diagnostics'}};
    indices={[1 2],[3 4],[6 7 8 9],[11 13 12],[14 15],[16 17]};
    for k=1:numel(buses)
        ops{end+1}=reorg.add('BusCreator',[buses{k} 'Bus'],buses{k},struct('Inputs',num2str(numel(indices{k}))));
        for j=1:numel(indices{k})
            ops{end+1}=reorg.wire(sprintf('#i%d.y1',indices{k}(j)),sprintf('#%s.u%d',buses{k},j),fields{k}{j});
        end
    end
    feeds={'#RawIMU.y1','#Bottom.y1','#i5.y1','#Pilot.y1','#i10.y1','#Attitude.y1','#Vertical.y1','#Sensors.y1'};
    selectors={'Duty,Counts','Mode,Diagnostics,PreviousMode,AltitudeEnabled,Connected', ...
        'Acceleration,AngularRate,VerticalDelta','VerticalAcceleration,FilteredRange,RawRange','Offsets,Samples'};
    for pair=1:2
        for k=1:numel(feeds),ops{end+1}=reorg.wire(feeds{k},sprintf('%s.u%d',groups{pair}.ID,k));end
        refs=cell(1,5);
        for k=1:5
            refs{k}=sprintf('case%dbus%d',pair,k);
            ops{end+1}=reorg.add('BusSelector',refs{k},refs{k},struct('OutputSignals',selectors{k}));
            ops{end+1}=reorg.wire(sprintf('%s.y%d',groups{pair}.ID,k),['#' refs{k} '.u1']);
        end
        ports={[1 1],[1 2],[2 1],[2 2],[2 3],[2 4],[2 5],[3 1],[3 2],[3 3],[4 1],[4 2],[4 3],[5 1],[5 2]};
        for k=1:numel(labels)
            ref=sprintf('case%dout%d',pair,k);
            ops{end+1}=reorg.add('Outport',sprintf('Case%d%s',pair,labels{k}),ref,struct('Port',num2str(2*k-2+pair)));
            ops{end+1}=reorg.wire(sprintf('#%s.y%d',refs{ports{k}(1)},ports{k}(2)),['#' ref '.u1']);
        end
    end
    reorg.edit(harness,'root',ops,'full');check=char(model_check(harness,'root','["all"]'));disp(check);
    assert(~contains(check,'severity: error'));save_system(harness,fullfile(folder,[harness '.slx']));
else
    open_system(fullfile(folder,[harness '.slx']));
end
report=struct('Models',{models},'IdenticalAttitudeAndRateInput',true,'Outputs',{labels}, ...
    'Samples',0,'Cases',struct,'Passed',false);
cases={'BootTakeoffHoverLanding','ModeAndFlip','SensorTimingAndInterruptions'};
for c=1:numel(cases)
    trace=load(fullfile(root,'tests',['reorganized_core_' cases{c} '.mat']),'values','t','out');
    data=trace.values(1:10);sources=[7 9 15 11 13 17 21];
    for k=1:numel(sources)
        value=squeeze(trace.out.yout{sources(k)}.Values.Data);
        if size(value,1)~=numel(trace.t),value=value.';end
        data{end+1}=value;
    end
    dataset=Simulink.SimulationData.Dataset;
    for k=1:numel(data)
        ts=timeseries(data{k},trace.t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');dataset=dataset.addElement(ts,names{k});
    end
    in=Simulink.SimulationInput(harness);in=in.setExternalInput(dataset);
    in=in.setModelParameter('StopTime',num2str(trace.t(end),17));out=sim(in);
    result=struct('Samples',numel(trace.t),'MismatchCounts',zeros(1,numel(labels)), ...
        'MaxErrors',zeros(1,numel(labels)),'TypesMatch',true);
    for k=1:numel(labels)
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        assert(isequal(size(a),size(b)));result.TypesMatch=result.TypesMatch&&strcmp(class(a),class(b));
        result.MismatchCounts(k)=nnz(a~=b & ~(isnan(a)&isnan(b)));
        result.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
    end
    report.Cases.(cases{c})=result;report.Samples=report.Samples+numel(trace.t);
    assert(result.TypesMatch&&all(result.MismatchCounts==0), ...
        'imuflight:ControlChanged','%s comparison differs: %s.',cases{c},mat2str(result.MismatchCounts));
    fprintf('IMU400_CONTROL_EQUIVALENT: %s (%d ticks)\n',cases{c},numel(trace.t));
end
report.Passed=true;
fid=fopen(fullfile(root,'docs','imu_control_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
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
