function report=verify_control_layout400()
%VERIFY_CONTROL_LAYOUT400 Compare actual root pipelines before/after layout.
% 同じ保存入力を使い、値・型・サイズを許容差ゼロで比較する。
root=stampfly_project_root();
ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_official();
current='StampFly_Official_FlightTest400';
beforeFile=fullfile(root,'archive','snapshots','FlightTest_before_control_layout_20261015_145343.slx');
[~,before]=fileparts(beforeFile);open_system(beforeFile);open_system(fullfile(root,[current '.slx']));
harness='ControlLayoutEquivalence400';
assert(~bdIsLoaded(harness),'official:FreshHarness','Use a fresh verification session.');
new_system(harness);open_system(harness);
selected={'blk_2721','blk_2231','blk_2274','blk_3131','blk_3213'};
inputGroups=[reorg.group('RawIMU',{'blk_3161.y1'},{'RawIMU'}), ...
    reorg.group('BottomRange',{'blk_3178.y1'},{'BottomRange'}), ...
    reorg.group('BatteryVoltage',{'blk_3171.y1'},{'BatteryVoltage'}), ...
    reorg.group('JoystickCommand',{'blk_3198.y1'},{'JoystickCommand'}), ...
    reorg.group('Dt',{'blk_4.y2'},{'Dt'})];
outputGroups=[reorg.group('MotorCommand',{'blk_2274.y1'},{'MotorCommand'}), ...
    reorg.group('FlightStatus',{'blk_2274.y2'},{'FlightStatus'}), ...
    reorg.group('Attitude',{'blk_2231.y1'},{'Attitude'}), ...
    reorg.group('VerticalMotion',{'blk_2231.y2'},{'VerticalMotion'}), ...
    reorg.group('SensorStatus',{'blk_2231.y3'},{'SensorStatus'})];
old=reorg.groupCopy(before,'root','root',selected,'BeforeLayout',inputGroups,outputGroups,harness);
now=reorg.groupCopy(current,'root','root',selected,'AfterLayout',inputGroups,outputGroups,harness);
isolateTags(harness,old.ID,'Before_');
isolateTags(harness,now.ID,'After_');
inputNames={'Acceleration','AngularRate','BottomDistanceMm','BottomFresh','BatteryVoltage', ...
    'Sticks','ArmButton','NewPacket','AHRSRequest','Dt','FlipButton'};
types={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single','uint8'};
dims=[3 3 1 1 1 6 1 1 1 1 1];
ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
    'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    reorg.add('BusCreator','RawIMUBus','imu',struct('Inputs','2')), ...
    reorg.add('BusCreator','BottomRangeBus','bottom',struct('Inputs','2')), ...
    reorg.add('BusCreator','JoystickCommandBus','joystick',struct('Inputs','5'))};
for k=1:11
    ops{end+1}=reorg.add('Inport',inputNames{k},['i' num2str(k)],struct('Port',num2str(k), ...
        'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025')); %#ok<AGROW>
end
ops=[ops,{reorg.wire('#i1.y1','#imu.u1','Acceleration'),reorg.wire('#i2.y1','#imu.u2','AngularRate'), ...
    reorg.wire('#i3.y1','#bottom.u1','DistanceMm'),reorg.wire('#i4.y1','#bottom.u2','Fresh'), ...
    reorg.wire('#i6.y1','#joystick.u1','Sticks'),reorg.wire('#i7.y1','#joystick.u2','ArmButton'), ...
    reorg.wire('#i8.y1','#joystick.u3','NewPacket'),reorg.wire('#i9.y1','#joystick.u4','AHRSRequest'), ...
    reorg.wire('#i11.y1','#joystick.u5','FlipButton')}];
names={'Duty','Counts','Mode','Angles','AngularRate','Altitude','Velocity','Quaternion','SensorFlags', ...
    'ControlDiagnostics','SensorDiagnostics','PreviousMode','AltitudeEnabled','Connected','FlipPhase'};
for pair=1:2
    if pair==1,pipeline=old;prefix='Before';else,pipeline=now;prefix='After';end
    feeds={'#imu.y1','#bottom.y1','#i5.y1','#joystick.y1','#i10.y1'};
    for k=1:5,ops{end+1}=reorg.wire(feeds{k},sprintf('%s.u%d',pipeline.ID,k),inputGroups(k).Name);end %#ok<AGROW>
    refs={['motor' num2str(pair)],['flight' num2str(pair)],['attitude' num2str(pair)], ...
        ['vertical' num2str(pair)],['sensor' num2str(pair)]};
    fields={'Duty,Counts','Mode,PreviousMode,AltitudeEnabled,Connected,FlipPhase,Diagnostics', ...
        'Angles,Quaternion,AngularRate','Altitude,Velocity','Flags,Diagnostics'};
    for k=1:5
        ops{end+1}=reorg.add('BusSelector',[prefix 'Results' num2str(k)],refs{k},struct('OutputSignals',fields{k})); %#ok<AGROW>
        ops{end+1}=reorg.wire(sprintf('%s.y%d',pipeline.ID,k),['#' refs{k} '.u1']); %#ok<AGROW>
    end
    endpoints={['#' refs{1} '.y1'],['#' refs{1} '.y2'],['#' refs{2} '.y1'],['#' refs{3} '.y1'], ...
        ['#' refs{3} '.y3'],['#' refs{4} '.y1'],['#' refs{4} '.y2'],['#' refs{3} '.y2'], ...
        ['#' refs{5} '.y1'],['#' refs{2} '.y6'],['#' refs{5} '.y2'],['#' refs{2} '.y2'], ...
        ['#' refs{2} '.y3'],['#' refs{2} '.y4'],['#' refs{2} '.y5']};
    for k=1:15
        ref=[prefix 'Out' num2str(k)];
        ops{end+1}=reorg.add('Outport',[prefix names{k}],ref,struct('Port',num2str(2*k-2+pair))); %#ok<AGROW>
        ops{end+1}=reorg.wire(endpoints{k},['#' ref '.u1']); %#ok<AGROW>
    end
end
reorg.edit(harness,'root',ops,'full');
save_system(harness,stampfly_model_file(harness));
report=struct('Baseline',beforeFile,'CurrentModel',get_param(current,'FileName'), ...
    'Outputs',{names},'TotalSamples',0,'AbsoluteTolerance',0);
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
    report.(cases{c})=result;report.TotalSamples=report.TotalSamples+numel(trace.t);
    save(fullfile(root,'build','tests',['control_layout_' cases{c} '.mat']),'result','out');
    fprintf('CONTROL_LAYOUT_SCENARIO: %s\n',cases{c});disp(result);
    assert(result.TypesMatch && all(result.MismatchCounts==0),'official:ControlLayoutNotEquivalent','%s differs.',cases{c});
end
report.Passed=true;
save(fullfile(root,'tests','control_layout_equivalence.mat'),'report');
fid=fopen(fullfile(root,'docs','history','control_layout_verification.json'),'w','n','UTF-8');assert(fid>=0);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
end

function isolateTags(m,group,prefix)
% Only auxiliary Goto/From names are namespaced in the comparison harness.
% Production models keep their existing tags and logging behavior.
blocks=find_system(reorg.path(m,group),'LookUnderMasks','all','Type','Block');
parents=struct;
for k=1:numel(blocks)
    if ~ismember(get_param(blocks{k},'BlockType'),{'Goto','From'}),continue;end
    parent=get_param(blocks{k},'Parent');id=reorg.id(parent);tag=get_param(blocks{k},'GotoTag');
    op=reorg.configure(reorg.id(blocks{k}),struct('GotoTag',[prefix tag]));
    if ~isfield(parents,id),parents.(id)={};end
    parents.(id){end+1}=op;
end
scopes=fieldnames(parents);
for k=1:numel(scopes),reorg.edit(m,scopes{k},parents.(scopes{k}));end
end
