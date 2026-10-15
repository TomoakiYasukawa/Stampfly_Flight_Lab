function report=verify_logging_control400()
%VERIFY_LOGGING_CONTROL400 追加ログ版と、飛行成功したPID版の15出力を比較。
% 実際の最上位配線をコピーし、同じ入力を3ケース、36,000周期与える。
root=stampfly_project_root();init_official();ensure_simulink_toolkit();
model='StampFly_PIDBlock_FlightTest400';open_system(fullfile(root,[model '.slx']));
model_read(model,'root','0');
folder=fullfile(root,'build','tests','logging');
baseline='BeforeLoggingPID400';
copyfile(fullfile(root,'archive','logging_before_20261015',[model '.slx']), ...
    fullfile(folder,[baseline '.slx']));
open_system(fullfile(folder,[baseline '.slx']));
harness='LoggingEquivalence400';new_system(harness);open_system(harness);
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
before=reorg.groupCopy(baseline,'root','root',selected,'BeforeLogging',inputs,outputs,harness);
after=reorg.groupCopy(model,'root','root',selected,'AfterLogging',inputs,outputs,harness);
isolateTags(harness,before.ID,'Before_');isolateTags(harness,after.ID,'After_');
names={'Acceleration','AngularRate','BottomDistanceMm','BottomFresh','BatteryVoltage', ...
    'Sticks','ArmButton','NewPacket','AHRSRequest','Dt','FlipButton'};
types={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single','uint8'};
dims=[3 3 1 1 1 6 1 1 1 1 1];
ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
    'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    reorg.add('BusCreator','RawIMUBus','imu',struct('Inputs','2')), ...
    reorg.add('BusCreator','BottomRangeBus','bottom',struct('Inputs','2')), ...
    reorg.add('BusCreator','PilotBus','pilot',struct('Inputs','5'))};
for k=1:11
    ops{end+1}=reorg.add('Inport',names{k},['i' num2str(k)],struct('Port',num2str(k), ...
        'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025'));
end
ops=[ops,{reorg.wire('#i1.y1','#imu.u1','Acceleration'),reorg.wire('#i2.y1','#imu.u2','AngularRate'), ...
    reorg.wire('#i3.y1','#bottom.u1','DistanceMm'),reorg.wire('#i4.y1','#bottom.u2','Fresh'), ...
    reorg.wire('#i6.y1','#pilot.u1','Sticks'),reorg.wire('#i7.y1','#pilot.u2','ArmButton'), ...
    reorg.wire('#i8.y1','#pilot.u3','NewPacket'),reorg.wire('#i9.y1','#pilot.u4','AHRSRequest'), ...
    reorg.wire('#i11.y1','#pilot.u5','FlipButton')}];
labels={'Duty','Counts','Mode','Angles','AngularRate','Altitude','Velocity','Quaternion', ...
    'SensorFlags','ControlDiagnostics','SensorDiagnostics','PreviousMode','AltitudeEnabled','Connected','FlipPhase'};
groups={before,after};
for pair=1:2
    pipeline=groups{pair};prefix=['Case' num2str(pair)];
    feeds={'#imu.y1','#bottom.y1','#i5.y1','#pilot.y1','#i10.y1'};
    for k=1:5,ops{end+1}=reorg.wire(feeds{k},sprintf('%s.u%d',pipeline.ID,k),inputs(k).Name);end
    refs=strcat({'motor','flight','attitude','vertical','sensor'},num2str(pair));
    fields={'Duty,Counts','Mode,PreviousMode,AltitudeEnabled,Connected,FlipPhase,Diagnostics', ...
        'Angles,Quaternion,AngularRate','Altitude,Velocity','Flags,Diagnostics'};
    for k=1:5
        ops{end+1}=reorg.add('BusSelector',[prefix 'Results' num2str(k)],refs{k},struct('OutputSignals',fields{k}));
        ops{end+1}=reorg.wire(sprintf('%s.y%d',pipeline.ID,k),['#' refs{k} '.u1']);
    end
    endpoints={['#' refs{1} '.y1'],['#' refs{1} '.y2'],['#' refs{2} '.y1'],['#' refs{3} '.y1'], ...
        ['#' refs{3} '.y3'],['#' refs{4} '.y1'],['#' refs{4} '.y2'],['#' refs{3} '.y2'], ...
        ['#' refs{5} '.y1'],['#' refs{2} '.y6'],['#' refs{5} '.y2'],['#' refs{2} '.y2'], ...
        ['#' refs{2} '.y3'],['#' refs{2} '.y4'],['#' refs{2} '.y5']};
    for k=1:15
        ref=[prefix 'Out' num2str(k)];
        ops{end+1}=reorg.add('Outport',[prefix labels{k}],ref,struct('Port',num2str(2*k-2+pair)));
        ops{end+1}=reorg.wire(endpoints{k},['#' ref '.u1']);
    end
end
reorg.edit(harness,'root',ops,'full');disp(model_check(harness,'root','["all"]'));
save_system(harness,fullfile(folder,[harness '.slx']));
report=struct('Baseline','archive/logging_before_20261015/StampFly_PIDBlock_FlightTest400.slx', ...
    'CurrentModel',[model '.slx'],'Outputs',{labels},'Samples',0,'AbsoluteTolerance',0);
cases={'BootTakeoffHoverLanding','ModeAndFlip','SensorTimingAndInterruptions'};
for c=1:numel(cases)
    trace=load(fullfile(root,'tests',['reorganized_core_' cases{c} '.mat']),'values','t');
    dataset=Simulink.SimulationData.Dataset;
    for k=1:11
        ts=timeseries(trace.values{k},trace.t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
        dataset=dataset.addElement(ts);
    end
    in=Simulink.SimulationInput(harness);in=in.setExternalInput(dataset);
    in=in.setModelParameter('StopTime',num2str(trace.t(end),17));out=sim(in);
    result=struct('Samples',numel(trace.t),'MismatchCounts',zeros(1,15),'MaxErrors',zeros(1,15),'TypesMatch',true,'SizesMatch',true);
    for k=1:15
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        result.TypesMatch=result.TypesMatch&&strcmp(class(a),class(b));
        result.SizesMatch=result.SizesMatch&&isequal(size(a),size(b));assert(result.SizesMatch);
        result.MismatchCounts(k)=nnz(a~=b & ~(isnan(a)&isnan(b)));
        result.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
    end
    assert(result.TypesMatch&&all(result.MismatchCounts==0),'official:LoggingChangedControl','%s differs.',cases{c});
    report.(cases{c})=result;report.Samples=report.Samples+numel(trace.t);
    fprintf('LOGGING_CONTROL_EQUIVALENT: %s (%d ticks)\n',cases{c},numel(trace.t));
end
report.Passed=true;
fid=fopen(fullfile(root,'docs','logging_control_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);disp(report);
end

function isolateTags(model,group,prefix)
blocks=find_system(reorg.path(model,group),'LookUnderMasks','all','Type','Block');parents=struct;
for k=1:numel(blocks)
    if ~ismember(get_param(blocks{k},'BlockType'),{'Goto','From'}),continue;end
    parent=reorg.id(get_param(blocks{k},'Parent'));tag=get_param(blocks{k},'GotoTag');
    if ~isfield(parents,parent),parents.(parent)={};end
    parents.(parent){end+1}=reorg.configure(reorg.id(blocks{k}),struct('GotoTag',[prefix tag]));
end
scopes=fieldnames(parents);
for k=1:numel(scopes),reorg.edit(model,scopes{k},parents.(scopes{k}));end
end
