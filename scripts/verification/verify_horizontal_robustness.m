function report=verify_horizontal_robustness()
%VERIFY_HORIZONTAL_ROBUSTNESS 実PIDを含む閉ループで遅延・倍率・方位ずれを確認。
% 機体同定値ではない合成条件です。実飛行の精度・安定性は別途確認します。
root=stampfly_project_root();addpath(fullfile(root,'tests'));horizontaltest.init();
folder=fullfile(root,'build','horizontal_control','harnesses');addpath(folder);
m='HorizontalClosedLoop';plant=find_system(m,'SearchDepth',1,'BlockType','MATLABSystem','System','horizontaltest.Plant');
assert(isscalar(plant));plant=plant{1};
% [Flow倍率, ToF遅延s, gyro遅延s, 方位誤差deg/s, モーター遅延s]
conditions=[.8 .035 0 0 .04;1.2 .035 0 0 .04;1 .07 0 0 .04; ...
    1 .035 .005 0 .04;1 .035 .02 0 .04;1 .035 0 1 .04; ...
    1 .035 0 0 .08;.8 .07 .01 .5 .08;1.2 .07 .01 -.5 .08];
names={'ScaleMinus20','ScalePlus20','Range70ms','Gyro5ms','Gyro20ms', ...
    'Heading1Degps','Motor80ms','CombinedMinus','CombinedPlus'};
t=(0:.0025:25)';n=numel(t);cases=struct;
for c=1:size(conditions,1)
    stick=zeros(n,6,'single');stick(:,6)=single(4);
    stick(t>=8&t<11,2)=single(-.5);stick(t>=8&t<11,3)=single(.03);
    disturbance=zeros(n,2,'single');disturbance(t>=14,:)=repmat(single([.12 -.06]),nnz(t>=14),1);
    branch=repmat(uint8(2),n,1);branch(t<.2)=uint8(3);
    ds=Simulink.SimulationData.Dataset;
    values={stick,disturbance,repmat(uint16(100),n,1),branch};inputNames={'Sticks','Disturbance','FlowQuality','Branch'};
    for k=1:4
        ts=timeseries(values{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
        ds=ds.addElement(ts,inputNames{k});
    end
    in=Simulink.SimulationInput(m);in=in.setExternalInput(ds);in=in.setModelParameter('StopTime','25');
    properties={'FlowScale','RangeDelayS','GyroDelayS','HeadingDriftDegps','MotorLagS'};
    for k=1:5,in=in.setBlockParameter(plant,properties{k},num2str(conditions(c,k),17));end
    out=sim(in);truth=samples(out.yout{6});duty=samples(out.yout{1});diag=samples(out.yout{5});velocity=samples(out.yout{8});
    time=out.yout{1}.Values.Time;steady=time>=20;moving=time>=9&time<11;
    result=struct('Condition',conditions(c,:),'Finite',all(isfinite([truth duty diag velocity]),'all'), ...
        'MaximumDuty',max(duty,[],'all'),'MaximumIntegralMps2',max(vecnorm(diag(:,11:12),2,2)), ...
        'FinalSpeedMps',norm(truth(end,3:4)),'FinalHoldErrorM',norm(truth(end,1:2)-diag(end,7:8)), ...
        'MeanMoveSpeedMps',mean(vecnorm(truth(moving,3:4),2,2)), ...
        'FinalVelocityRMSErrorMps',sqrt(mean((truth(steady,3:4)-velocity(steady,:)).^2,'all')), ...
        'FinalState',diag(end,16),'SteadyAssistFraction',mean(diag(steady,17)));
    result.Passed=result.Finite&&result.MaximumDuty<=.950001&&result.MaximumIntegralMps2<=.250001 && ...
        result.FinalSpeedMps<.08&&result.FinalHoldErrorM<.2&&result.FinalVelocityRMSErrorMps<.08 && ...
        result.FinalState==2&&result.SteadyAssistFraction>.99&&result.MeanMoveSpeedMps>.10;
    cases.(names{c})=result;save(fullfile(root,'build','horizontal_control',[names{c} '_robustness.mat']),'out','result');
    disp(result);assert(result.Passed,'horizontal:Robustness','Synthetic robustness failed: %s',names{c});
end
report=struct('Passed',true,'CaseCount',size(conditions,1),'Cases',cases, ...
    'UsesTrueAltitude',true,'UncalibratedPlant',true,'PhysicalFlightTested',false);
fid=fopen(fullfile(root,'docs','horizontal_robustness_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_ROBUSTNESS_VERIFICATION_PASSED\n');
end
function data=samples(signal)
data=signal.Values.Data;n=numel(signal.Values.Time);
if size(data,1)==n,data=reshape(data,n,[]);else,data=reshape(permute(data,[ndims(data) 1:ndims(data)-1]),n,[]);end
data=double(data);
end
