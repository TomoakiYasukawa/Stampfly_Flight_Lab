function report=verify_reorganized_core()
%VERIFY_REORGANIZED_CORE Compare all outputs to the first flown model.
% 初回飛行版の実ブロックと現在の実ブロックを同じ入力で実行する。
root=stampfly_project_root();
snapshot=load(fullfile(root,'tests','model_reorganization_before.mat')).snapshot;
[~,baseline]=fileparts(snapshot.InitialFile);open_system(snapshot.InitialFile);
model='StampFly_Official_FlightTest400';harness='ReorganizedCoreEquivalence400';
if bdIsLoaded(harness),close_system(harness,0);end
new_system(harness);open_system(harness);
names={'Acceleration','AngularRate','BottomDistanceMm','BottomFresh','BatteryVoltage', ...
    'Sticks','ArmButton','NewPacket','AHRSRequest','Dt','FlipButton'};
types={'single','single','int16','uint8','single','single','uint8','uint8','uint8','single','uint8'};
dims=[3 3 1 1 1 6 1 1 1 1 1];
outputs={'Duty','Counts','Mode','Angles','AngularRate','Altitude','Velocity','Quaternion', ...
    'SensorFlags','ControlDiagnostics','SensorDiagnostics','PreviousMode','AltitudeEnabled','Connected','FlipPhase'};
ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
    'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    reorg.add(reorg.path(baseline,'blk_38'),'InitialFlightAlgorithm','old'), ...
    reorg.add(reorg.path(model,'blk_38'),'CurrentFlightAlgorithm','new')};
for k=1:11
    ref=['i' num2str(k)];
    ops{end+1}=reorg.add('Inport',names{k},ref,struct('Port',num2str(k), ...
        'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)),'SampleTime','.0025'));
    ops=[ops,{reorg.wire(['#' ref '.y1'],sprintf('#old.u%d',k)),reorg.wire(['#' ref '.y1'],sprintf('#new.u%d',k))}];
end
for k=1:15
    a=['oldOut' num2str(k)];b=['newOut' num2str(k)];
    ops=[ops,{reorg.add('Outport',['Initial' outputs{k}],a,struct('Port',num2str(2*k-1))), ...
        reorg.add('Outport',['Current' outputs{k}],b,struct('Port',num2str(2*k))), ...
        reorg.wire(sprintf('#old.y%d',k),['#' a '.u1']),reorg.wire(sprintf('#new.y%d',k),['#' b '.u1'])}];
end
reorg.edit(harness,'root',ops,'full');save_system(harness,stampfly_model_file(harness));
cases={'BootTakeoffHoverLanding','ModeAndFlip','SensorTimingAndInterruptions'};
report=struct('Baseline',snapshot.InitialFile,'OutputNames',{outputs},'TotalSamples',0);
for c=1:numel(cases)
    [values,t]=inputs(c);dataset=Simulink.SimulationData.Dataset;
    for k=1:11
        ts=timeseries(values{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');dataset=dataset.addElement(ts,names{k});
    end
    in=Simulink.SimulationInput(harness);in=in.setVariable('inf',builtin('inf'));
    in=in.setExternalInput(dataset);in=in.setModelParameter('StopTime',num2str(t(end),17));out=sim(in);
    result=struct('Samples',numel(t),'MismatchCounts',zeros(1,15),'MaxErrors',zeros(1,15), ...
        'TypesMatch',true,'SizesMatch',true,'ModesCovered',[],'FlipPhasesCovered',[]);
    for k=1:15
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        result.TypesMatch=result.TypesMatch && strcmp(class(a),class(b));
        result.SizesMatch=result.SizesMatch && isequal(size(a),size(b));
        assert(result.SizesMatch,'official:CoreDimensions','Output dimensions differ.');
        result.MismatchCounts(k)=nnz(a~=b & ~(isnan(a)&isnan(b)));
        result.MaxErrors(k)=max(abs(double(a)-double(b)),[],'all');
    end
    result.ModesCovered=unique(out.yout{5}.Values.Data)';
    result.FlipPhasesCovered=unique(out.yout{29}.Values.Data)';
    report.(cases{c})=result;report.TotalSamples=report.TotalSamples+numel(t);
    save(fullfile(root,'tests',['reorganized_core_' cases{c} '.mat']),'result','out','values','t');
    disp(cases{c});disp(result);
    assert(result.TypesMatch && all(result.MismatchCounts==0),'official:CoreNotEquivalent','%s differs from initial model.',cases{c});
end
save(fullfile(root,'tests','reorganized_core_equivalence.mat'),'report');
end
function [values,t]=inputs(whichCase)
n=12000;t=(0:n-1)'*.0025;
a=single([.02*sin(t),.015*cos(t),9.80665+.04*sin(2*t)]);
g=single([.005*sin(t),.004*cos(2*t),.003*sin(3*t)]);
mm=int16(40*ones(n,1));fresh=uint8(mod((0:n-1)',16)==0);
voltage=single(4.05-.01*t);stick=zeros(n,6,'single');stick(:,6)=4;
button=zeros(n,1,'uint8');packet=ones(n,1,'uint8');ahrs=zeros(n,1,'uint8');
dt=repmat(single(.0025),n,1);flip=zeros(n,1,'uint8');
button(1000:1039)=1;mm(1050:2150)=int16(linspace(40,500,1101));mm(2151:8000)=500;
button(8001:8040)=1;mm(8100:8600)=int16(linspace(500,45,501));mm(8601:end)=45;
if whichCase==2
    stick(2500:2800,1)=.1;stick(3000:3300,2)=-.1;stick(3500:3800,3)=.08;
    stick(4000:4300,5)=1;stick(4500:4900,6)=5;stick(4500:4900,4)=.3;
    flip(5300:5311)=1;stick(6500:6700,4)=.3;stick(7000:7100,4)=-.3;
    button(9000:9039)=1;mm(9100:10000)=int16(linspace(45,500,901));mm(10001:end)=500;
elseif whichCase==3
    dt=single(.0025+.00025*sin(17*t));
    mm(2500:2520)=1900;mm(3000:3040)=0;mm(3500:3520)=-1;mm(4000:4020)=10;
    fresh(2500:2520)=1;fresh(3500:3520)=1;
    flip(4500:4511)=1;packet(4720:4820)=0;
    button(6000:6039)=1;mm(6100:7000)=int16(linspace(45,500,901));mm(7001:8500)=500;
    a(7300:7310,:)=single([25 0 9.80665])+zeros(11,3,'single');
    ahrs(8500:8505)=1;voltage(9000:end)=3.2;
    button(10000:10039)=1;mm(10100:11000)=int16(linspace(45,500,901));mm(11001:end)=500;
end
values={a,g,mm,fresh,voltage,stick,button,packet,ahrs,dt,flip};
end
