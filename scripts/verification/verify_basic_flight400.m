function report=verify_basic_flight400(reuseHarness)
%VERIFY_BASIC_FLIGHT400 Compare normal-flight outputs and ignore button pulses.
% Copies the actual saved root pipeline; no physical IO runs in the harness.
if nargin==0,reuseHarness=false;end
root=stampfly_project_root();addpath(fullfile(root,'tests'));init_basic();ensure_simulink_toolkit();
source='StampFly_PIDBlock_FlightTest400';model='StampFly_Basic400';
open_system(fullfile(root,'StampFly_Official_FlightTest400.slx'));
open_system(fullfile(root,[source '.slx']));open_system(fullfile(root,[model '.slx']));
folder=fullfile(root,'build','basic400','tests');if ~isfolder(folder),mkdir(folder);end
harness='BasicFlightComparison400';
labels={'Duty','Counts','Mode','Angles','AngularRate','Altitude','Velocity','Quaternion', ...
    'SensorFlags','ControlDiagnostics','SensorDiagnostics','PreviousMode','AltitudeEnabled','Connected'};
if ~reuseHarness
if bdIsLoaded(harness),close_system(harness,0);end
new_system(harness);open_system(harness);
selected={'blk_2721','blk_2231','blk_2274','blk_3131','blk_3213'};
inputs=[reorg.group('RawIMU',{'blk_3161.y1'},{'RawIMU'}), ...
    reorg.group('BottomRange',{'blk_3178.y1'},{'BottomRange'}), ...
    reorg.group('BatteryVoltage',{'blk_3171.y1'},{'BatteryVoltage'}), ...
    reorg.group('JoystickCommand',{'blk_3198.y1'},{'JoystickCommand'}), ...
    reorg.group('Dt',{'blk_4.y2'},{'Dt'})];
outputs=[reorg.group('MotorCommand',{'blk_2274.y1'},{'MotorCommand'}), ...
    reorg.group('FlightStatus',{'blk_2274.y2'},{'FlightStatus'}), ...
    reorg.group('Attitude',{'blk_2231.y1'},{'Attitude'}), ...
    reorg.group('VerticalMotion',{'blk_2231.y2'},{'VerticalMotion'}), ...
    reorg.group('SensorStatus',{'blk_2231.y3'},{'SensorStatus'})];
before=reorg.groupCopy(source,'root','root',selected,'OriginalPID',inputs,outputs,harness);
after=reorg.groupCopy(model,'root','root',selected,'BasicPID',inputs,outputs,harness);
isolateTags(harness,before.ID,'Original_');isolateTags(harness,after.ID,'Basic_');
names={'Acceleration','AngularRate','BottomDistanceMm','BottomFresh','BatteryVoltage', ...
    'Sticks','ArmButton','NewPacket','AHRSRequest','Dt','ReservedButton'};
types={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single','uint8'};
dims=[3 3 1 1 1 6 1 1 1 1 1];
ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
    'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    reorg.add('BusCreator','RawIMUBus','imu',struct('Inputs','2')), ...
    reorg.add('BusCreator','BottomRangeBus','bottom',struct('Inputs','2')), ...
    reorg.add('BusCreator','OriginalPilotBus','originalPilot',struct('Inputs','5')), ...
    reorg.add('BusCreator','BasicPilotBus','basicPilot',struct('Inputs','4'))};
for k=1:11
    ops{end+1}=reorg.add('Inport',names{k},['i' num2str(k)],struct('Port',num2str(k), ...
        'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025'));
end
ops=[ops,{reorg.wire('#i1.y1','#imu.u1','Acceleration'),reorg.wire('#i2.y1','#imu.u2','AngularRate'), ...
    reorg.wire('#i3.y1','#bottom.u1','DistanceMm'),reorg.wire('#i4.y1','#bottom.u2','Fresh'), ...
    reorg.wire('#i11.y1','#originalPilot.u5','FlipButton')}];
pilotFields={'Sticks','ArmButton','NewPacket','AHRSRequest'};
for pair={'originalPilot','basicPilot'}
    for k=1:4
        ops{end+1}=reorg.wire(sprintf('#i%d.y1',k+5),sprintf('#%s.u%d',pair{1},k), ...
            pilotFields{k});
    end
end
groups={before,after};
for pair=1:2
    pipeline=groups{pair};prefix=['Case' num2str(pair)];
    pilot={'#originalPilot.y1','#basicPilot.y1'};
    feeds={'#imu.y1','#bottom.y1','#i5.y1',pilot{pair},'#i10.y1'};
    for k=1:5,ops{end+1}=reorg.wire(feeds{k},sprintf('%s.u%d',pipeline.ID,k),inputs(k).Name);end
    refs=strcat({'motor','flight','attitude','vertical','sensor'},num2str(pair));
    fields={'Duty,Counts','Mode,PreviousMode,AltitudeEnabled,Connected,Diagnostics', ...
        'Angles,Quaternion,AngularRate','Altitude,Velocity','Flags,Diagnostics'};
    for k=1:5
        ops{end+1}=reorg.add('BusSelector',[prefix 'Results' num2str(k)],refs{k},struct('OutputSignals',fields{k}));
        ops{end+1}=reorg.wire(sprintf('%s.y%d',pipeline.ID,k),['#' refs{k} '.u1']);
    end
    endpoints={['#' refs{1} '.y1'],['#' refs{1} '.y2'],['#' refs{2} '.y1'],['#' refs{3} '.y1'], ...
        ['#' refs{3} '.y3'],['#' refs{4} '.y1'],['#' refs{4} '.y2'],['#' refs{3} '.y2'], ...
        ['#' refs{5} '.y1'],['#' refs{2} '.y5'],['#' refs{5} '.y2'],['#' refs{2} '.y2'], ...
        ['#' refs{2} '.y3'],['#' refs{2} '.y4']};
    for k=1:numel(labels)
        ref=[prefix 'Out' num2str(k)];
        ops{end+1}=reorg.add('Outport',[prefix labels{k}],ref,struct('Port',num2str(2*k-2+pair)));
        ops{end+1}=reorg.wire(endpoints{k},['#' ref '.u1']);
    end
end
reorg.edit(harness,'root',ops,'full');disp(model_check(harness,'root','["all"]'));
save_system(harness,fullfile(folder,[harness '.slx']));
else
    open_system(fullfile(folder,[harness '.slx']));
end
report=struct('SourceModel',[source '.slx'],'Model',[model '.slx'],'Outputs',{labels}, ...
    'Samples',0,'AbsoluteTolerance',0,'Flashed',false,'PhysicalFlightTested',false);
cases={'BootTakeoffHoverLanding','ModeAndFlip','SensorTimingAndInterruptions'};
for c=1:numel(cases)
    trace=load(fullfile(root,'tests',['reorganized_core_' cases{c} '.mat']),'values','t');
    trace.values{11}(:)=uint8(0);dataset=makeDataset(trace);
    in=Simulink.SimulationInput(harness);in=in.setExternalInput(dataset);
    in=in.setModelParameter('StopTime',num2str(trace.t(end),17));out=sim(in);
    result=struct('Samples',numel(trace.t),'MismatchCounts',zeros(1,numel(labels)), ...
        'MaxErrors',zeros(1,numel(labels)),'TypesMatch',true,'Modes',[],'ButtonIgnored',false);
    reference=cell(1,numel(labels));
    for k=1:numel(labels)
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        result.TypesMatch=result.TypesMatch&&strcmp(class(a),class(b));assert(isequal(size(a),size(b)));
        result.MismatchCounts(k)=nnz(a~=b & ~(isnan(a)&isnan(b)));
        result.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');reference{k}=b;
    end
    result.Modes=double(unique(reference{3}));assert(~any(result.Modes==6));
    report.(cases{c})=result;
    if ~(result.TypesMatch&&all(result.MismatchCounts==0))
        save(fullfile(folder,[cases{c} '_failure.mat']),'out','trace','report');
        writeReport(root,report);error('basic:NormalFlightChanged','%s differs: %s',cases{c},mat2str(result.MismatchCounts));
    end
    trace.values{11}=uint8(mod(floor(trace.t/.2),2));
    in=in.setExternalInput(makeDataset(trace));out=sim(in);
    for k=1:numel(labels)
        assert(isequaln(reference{k},out.yout{2*k}.Values.Data),'basic:ButtonChangesFlight','The reserved button changes %s.',labels{k});
    end
    result.ButtonIgnored=true;report.(cases{c})=result;report.Samples=report.Samples+numel(trace.t);
    fprintf('BASIC400_NORMAL_FLIGHT_EQUIVALENT: %s (%d ticks, button ignored)\n',cases{c},numel(trace.t));
end
writeReport(root,report);report.Logging=verifyBasicLogger();report.Passed=true;writeReport(root,report);disp(report);
end
function dataset=makeDataset(trace)
dataset=Simulink.SimulationData.Dataset;
for k=1:11
    ts=timeseries(trace.values{k},trace.t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');dataset=dataset.addElement(ts);
end
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
function result=verifyBasicLogger()
[raw,estimate,control,extra]=logging_fixture();
normal=official.ExtendedLogger50;basicLogger=basic.ExtendedLogger50;
cleanup=onCleanup(@()releaseBoth(normal,basicLogger));
controlBasic=rmfield(control,'FlipPhase');controlBasic.Pilot=rmfield(control.Pilot,'FlipButton');
for k=1:3
    raw.Time=single(k*.02);raw.ToFInfo(1)=uint32(k);extra.Flow.Totals=uint32([k*13;4294967296-k*9]);
    [a,b,c]=normal(raw,estimate,control,extra);[x,y,z]=basicLogger(raw,estimate,controlBasic,extra);
    assert(isequal(a,x));assert(y(150)==0&&y(154)==0);
    % Firmware revision and its CRC intentionally distinguish the basic image.
    b(15:18)=y(15:18);b(189:190)=y(189:190);assert(isequal(b,y));
    c(15:18)=z(15:18);c(245:246)=z(245:246);assert(isequal(c,z));
    imu.decodeFrame(x);imu.decodeExtensionFrame(y);imu.decodeExtensionFrame(z);
end
result=struct('Passed',true,'BuildID',1401,'Revision',1601,'PacketBytes',[190 190 246],'ReservedFieldsZero',true);
end
function releaseBoth(a,b),release(a);release(b);end
function writeReport(root,report)
fid=fopen(fullfile(root,'docs','basic_flight_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
