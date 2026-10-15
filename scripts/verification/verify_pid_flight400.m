function report=verify_pid_flight400()
%VERIFY_PID_FLIGHT400 Compare the dedicated-PID pipeline with saved baseline.
% 機器へ接続せず同じ離陸・ホバリング入力で比較する。実飛行予測ではない。
root=stampfly_project_root();
model='StampFly_PIDBlock_FlightTest400';
open_system(fullfile(root,[model '.slx']));init_official();
assert(strcmp(get_param(model,'Solver'),'FixedStepDiscrete'));
assert(slResolve(get_param(model,'FixedStep'),model)==.0025);
sim(model,'StopTime','0');
source=fullfile(root,'tests','models','ControlLayoutEquivalence400.slx');
harness='PIDFlightComparison400';
file=fullfile(root,'tests','models',[harness '.slx']);
assert(~bdIsLoaded(harness));copyfile(source,file);open_system(file);
after=find_system(harness,'SearchDepth',1,'Name','AfterLayout');assert(numel(after)==1);
gains=load(fullfile(root,'tests','pid_comparison_metadata.mat'),'result').result.GainSets;
names=fieldnames(gains);
for k=1:numel(names)
    destination=find_system(after{1},'LookUnderMasks','all','Name',names{k});
    replacement=find_system(model,'LookUnderMasks','all','Name',names{k});
    assert(numel(destination)==1 && numel(replacement)==1);
    parent=reorg.id(get_param(destination{1},'Parent'));
    reorg.edit(harness,parent,{struct('op','replace_block','target',reorg.id(destination{1}), ...
        'type',replacement{1})});
end
disp(model_check(harness,'root','["all"]'));save_system(harness,file);
trace=load(fullfile(root,'tests','reorganized_core_BootTakeoffHoverLanding.mat'),'values','t');
dataset=Simulink.SimulationData.Dataset;
for k=1:11
    ts=timeseries(trace.values{k},trace.t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
    dataset=dataset.addElement(ts);
end
input=Simulink.SimulationInput(harness);input=input.setExternalInput(dataset);
input=input.setModelParameter('StopTime',num2str(trace.t(end),17));output=sim(input);
labels={'Duty','Counts','Mode','Angles','AngularRate','Altitude','Velocity','Quaternion', ...
    'SensorFlags','ControlDiagnostics','SensorDiagnostics','PreviousMode','AltitudeEnabled', ...
    'Connected','FlipPhase'};
report=struct('Model',model,'ModelCompilePassed',true,'PIDCount',7, ...
    'Scenario','BootTakeoffHoverLanding','Samples',numel(trace.t), ...
    'SameInputOpenLoopComparison',true,'PhysicalFlightVerified',false, ...
    'Outputs',{labels},'MismatchCounts',zeros(1,15),'MaxAbsoluteErrors',zeros(1,15), ...
    'AllFinite',true,'TypesMatch',true,'SizesMatch',true);
for k=1:15
    a=output.yout{2*k-1}.Values.Data;b=output.yout{2*k}.Values.Data;
    report.TypesMatch=report.TypesMatch&&strcmp(class(a),class(b));
    report.SizesMatch=report.SizesMatch&&isequal(size(a),size(b));
    report.AllFinite=report.AllFinite&&all(isfinite(b),'all');
    report.MismatchCounts(k)=nnz(a~=b);
    report.MaxAbsoluteErrors(k)=max(abs(double(a)-double(b)),[],'all');
end
duty=output.yout{2}.Values.Data;
report.DutyMin=min(double(duty),[],'all');report.DutyMax=max(double(duty),[],'all');
report.DutyLimitsPassed=report.DutyMin>=0 && report.DutyMax<=double(single(.95));
% 数値演算が変わるのはPIDとその後段。センサー推定・状態入力の一致を確認。
unchanged=[4 5 6 7 8 9 11 14];
report.UnchangedSignalsMatch=all(report.MismatchCounts(unchanged)==0);
report.Passed=report.TypesMatch && report.SizesMatch && report.AllFinite ...
    && report.DutyLimitsPassed && report.UnchangedSignalsMatch;
save(fullfile(root,'tests','pid_flight_verification.mat'),'report');
save(fullfile(root,'build','tests','pid_flight_nominal_trace.mat'),'output');
fid=fopen(fullfile(root,'docs','pid_flight_verification.json'),'w','n','UTF-8');assert(fid>=0);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
assert(report.Passed,'official:PIDFlightValidation','Dedicated PID validation failed.');
fprintf('PID_FLIGHT_MODEL_VALIDATED\n');disp(report);
end
