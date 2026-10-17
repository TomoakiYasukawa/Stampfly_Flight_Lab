function report=verify_horizontal_closed_loop()
%VERIFY_HORIZONTAL_CLOSED_LOOP 実PID・水平推定を簡易剛体で有限時間検証する。
% 実機同定前のモデルです。数値安定性、符号、指令・欠測時の動作を確認し、
% 実飛行での精度と処理時間は別に確認します。
root=stampfly_project_root();addpath(fullfile(root,'tests'));horizontaltest.init();
folder=fullfile(root,'build','horizontal_control','harnesses');addpath(folder);
open_system(fullfile(folder,'HorizontalClosedLoop.slx'));
t=(0:.0025:25)';n=numel(t);cases=struct;
names={'HoldDisturbance','MoveBrakeHold','YawAndHold','LossAndRecovery'};
for c=1:numel(names)
    stick=zeros(n,6,'single');stick(:,6)=single(4);
    disturbance=zeros(n,2,'single');quality=repmat(uint16(100),n,1);
    branch=repmat(uint8(2),n,1);branch(t<.2)=uint8(3);
    if c==1,disturbance(t>=8,1)=single(.12);disturbance(t>=8,2)=single(-.06);end
    if c==2,stick(t>=8&t<11,2)=single(-.5);end
    if c==3,stick(t>=8&t<11,3)=single(.04);disturbance(t>=12,2)=single(.08);end
    if c==4,quality(t>=9&t<9.5)=uint16(0);disturbance(t>=8&t<10,1)=single(.1);end
    ds=Simulink.SimulationData.Dataset;
    values={stick,disturbance,quality,branch};inputNames={'Sticks','Disturbance','FlowQuality','Branch'};
    for k=1:4
        ts=timeseries(values{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
        ds=ds.addElement(ts,inputNames{k});
    end
    in=Simulink.SimulationInput('HorizontalClosedLoop');in=in.setExternalInput(ds);
    in=in.setModelParameter('StopTime','25');out=sim(in);
    duty=samples(out.yout{1});diagnostics=samples(out.yout{5});truth=samples(out.yout{6});
    position=samples(out.yout{7});velocity=samples(out.yout{8});status=samples(out.yout{11});
    time=out.yout{1}.Values.Time;steady=time>=20;moving=time>=9&time<11;
    result=struct('Finite',all(isfinite([duty diagnostics truth velocity position]),'all'), ...
        'MinimumDuty',min(duty,[],'all'),'MaximumDuty',max(duty,[],'all'), ...
        'LastHeightM',truth(end,5),'MaximumSpeedMps',max(vecnorm(truth(:,3:4),2,2)), ...
        'FinalSpeedMps',norm(truth(end,3:4)),'FinalPositionM',truth(end,1:2), ...
        'FinalHoldM',diagnostics(end,7:8),'FinalState',diagnostics(end,16), ...
        'MaximumIntegralMps2',max(vecnorm(diagnostics(:,11:12),2,2)), ...
        'FinalHoldErrorM',norm(truth(end,1:2)-diagnostics(end,7:8)), ...
        'FinalVelocityRMSErrorMps',sqrt(mean((truth(steady,3:4)-velocity(steady,:)).^2,'all')), ...
        'SteadyAssistFraction',mean(diagnostics(steady,17)), ...
        'MeanMoveVelocityMps',mean(truth(moving,3:4),1),'StopTimeS',NaN);
    if c==2
        after=find(time>=11&vecnorm(truth(:,3:4),2,2)<.08,1);
        if ~isempty(after),result.StopTimeS=time(after)-11;end
    end
    result.Passed=result.Finite&&result.MinimumDuty>=0&&result.MaximumDuty<=.950001 && ...
        result.LastHeightM>.2&&result.LastHeightM<1 && result.MaximumIntegralMps2<=.250001 && ...
        result.FinalState==2 && result.FinalSpeedMps<.08 && ...
        result.FinalHoldErrorM<.2&&result.FinalVelocityRMSErrorMps<.08 && result.SteadyAssistFraction>.99;
    if c==2,result.Passed=result.Passed&&result.MeanMoveVelocityMps(1)>.12&&result.FinalPositionM(1)>.35&&result.StopTimeS<2;end
    if c==4
        loss=time>=9.02&time<9.5;
        result.LossAssistZero=all(diagnostics(loss,17)==0);
        result.LossIntegralZero=all(diagnostics(loss,11:12)==0,'all');
        result.Passed=result.Passed&&result.LossAssistZero&&result.LossIntegralZero;
    end
    cases.(names{c})=result;
    save(fullfile(root,'build','horizontal_control',[names{c} '_closed_loop.mat']),'out','result');
    disp(result);
    if ~result.Passed
        writeJSON(fullfile(root,'build','horizontal_control','closed_loop_partial.json'),cases);
        error('horizontal:ClosedLoop','Closed-loop scenario failed: %s',names{c});
    end
end
report=struct('Passed',true,'RealPIDCount',7,'RangeDelayS',.035,'QuantizedFlow',true, ...
    'UsesTrueAttitudeAndAltitude',true,'PlantCoefficientsCalibrated',false,'Cases',cases,'PhysicalFlightTested',false);
writeJSON(fullfile(root,'docs','horizontal_closed_loop_verification.json'),report);
fprintf('HORIZONTAL_CLOSED_LOOP_VERIFICATION_PASSED\n');
end
function data=samples(signal)
data=signal.Values.Data;n=numel(signal.Values.Time);
if size(data,1)==n,data=reshape(data,n,[]);else,data=reshape(permute(data,[ndims(data) 1:ndims(data)-1]),n,[]);end
data=double(data);
end
function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
