function report=verify_vertical_boundary()
%VERIFY_VERTICAL_BOUNDARY 概要：保存モデルの実ブロックを用いて高度推定境界を検証。
% 機器I/Oを含まない比較モデル。ToF量子化、既知運動、繰返し飛行切替を確認。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
init_imu_flight();m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
settings=jsondecode(fileread(fullfile(root,'docs','vertical_boundary_repair.json')));
h='VerticalBoundaryTest';if bdIsLoaded(h),close_system(h,0);end
new_system(h);open_system(h);disp(model_read(h,'root','0'));
ops={reorg.configure(['config:' h],struct('Solver','FixedStepDiscrete','FixedStep','.0025','StopTime','10', ...
    'SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
    reorg.add(reorg.path(m,'blk_2236'),'LegacyCore','legacy'), ...
    reorg.add(reorg.path(m,'blk_2236'),'CorrectedCore','corrected'), ...
    reorg.add(reorg.path(m,settings.AccelerationGain),'VerticalAccelGToMps2','gain'), ...
    reorg.add(reorg.path(m,settings.ResetEdge),'ParkingResetEdge','edge'), ...
    reorg.add(reorg.path(m,'blk_4349'),'PreviousParkingReset','memory'), ...
    reorg.add(reorg.path(m,'blk_4350'),'NotPreviousParkingReset','not'), ...
    reorg.add(reorg.path(m,settings.BiasConversion),'KalmanBiasMps2ToG','bias'), ...
    reorg.add('Constant','Dt','dt',struct('Value','single(.0025)'))};
names={'RangeM','VerticalAccelG','Mode','ParkingReset'};types={'single','single','uint8','boolean'};
for k=1:4
    ops{end+1}=reorg.add('Inport',names{k},sprintf('input%d',k),struct('Port',num2str(k), ...
        'OutDataTypeStr',types{k},'SampleTime','.0025')); %#ok<AGROW>
end
ops=[ops {reorg.wire('#input1.y1','#legacy.u1'),reorg.wire('#input1.y1','#corrected.u1'), ...
    reorg.wire('#input2.y1','#legacy.u2'),reorg.wire('#input2.y1','#gain.u1'),reorg.wire('#gain.y1','#corrected.u2'), ...
    reorg.wire('#input3.y1','#legacy.u3'),reorg.wire('#input3.y1','#corrected.u3'), ...
    reorg.wire('#dt.y1','#legacy.u4'),reorg.wire('#dt.y1','#corrected.u4'), ...
    reorg.wire('#input4.y1','#legacy.u5'),reorg.wire('#input4.y1','#memory.u1'), ...
    reorg.wire('#memory.y1','#not.u1'),reorg.wire('#not.y1','#edge.u2'), ...
    reorg.wire('#input4.y1','#edge.u1'),reorg.wire('#edge.y1','#corrected.u5'),reorg.wire('#corrected.y3','#bias.u1')}];
names={'LegacyHeight','LegacyVelocity','LegacyBias','HeightM','VelocityMps','BiasG'};
feeds={'#legacy.y1','#legacy.y2','#legacy.y3','#corrected.y1','#corrected.y2','#bias.y1'};
for k=1:numel(names)
    ops{end+1}=reorg.add('Outport',names{k},sprintf('output%d',k),struct('Port',num2str(k))); %#ok<AGROW>
    ops{end+1}=reorg.wire(feeds{k},sprintf('#output%d.u1',k)); %#ok<AGROW>
end
reorg.edit(h,'root',ops,'full');check=char(model_check(h,'root','["all"]'));disp(check);
assert(~contains(check,'severity: error')&&~contains(check,'status: error'));
folder=fullfile(root,'build','horizontal_control','fall_investigation');save_system(h,fullfile(folder,[h '.slx']));
t=(0:.0025:10)';mode=uint8(3*ones(size(t)));mode(t>=3)=2;
range=single(.025+.002*round(sin(floor(t*25)*sqrt(2))));acc=zeros(size(t),'single');
data=runCase(h,t,range,acc,mode);selected=t>=3&t<3.5;
floorOld=max(abs(data(:,2)));floorNew=max(abs(data(selected,5)));
assert(floorNew<.03,'vertical:FloorSpike','静止時の速度変動が大きい。');
assert(max(abs(data(selected,6)))<.1,'vertical:BiasSpike','静止時のバイアスが大きい。');
assert(max(abs(data(selected,2)))>.15,'vertical:Counterexample','旧リセットの不具合が再現していない。');
floorData=data; %#ok<NASGU>
% 400 Hz加速度と40ms保持のToFで、静止→既知の滑らかな上昇→停止を比較。
phase=t-3;truthHeight=.025*ones(size(t));truthVelocity=zeros(size(t));truthAccel=zeros(size(t));
rise=phase>=0&phase<=2;
truthHeight(rise)=.025+.3*(1-cos(pi*phase(rise)/2));
truthVelocity(rise)=.3*pi/2*sin(pi*phase(rise)/2);
truthAccel(rise)=.3*(pi/2)^2*cos(pi*phase(rise)/2);
truthHeight(phase>2)=.625;
heldIndex=max(1,1+floor((0:numel(t)-1)'/16)*16);
range=single(round(truthHeight(heldIndex)*1000)/1000);
data=runCase(h,t,range,single(truthAccel/9.80665),mode);
motion=t>=3.2&t<=5;velocityRMSE=sqrt(mean((data(motion,5)-truthVelocity(motion)).^2));
assert(velocityRMSE<.12,'vertical:KnownMotion','既知の上昇速度との誤差が大きい。');
assert(max(abs(data(t>=7,5)))<.03,'vertical:SettledVelocity','停止後に速度が残る。');
assert(all(isfinite(data),'all'));
motionData=data; %#ok<NASGU>
% 2回目の待機・離陸でも推定の収束を保持します。
mode(t>=6&t<8)=3;
data=runCase(h,t,range,single(truthAccel/9.80665),mode);
assert(max(abs(data(t>=8&t<8.5,5)))<.04,'vertical:SecondTakeoff','再離陸時に速度が跳ねる。');
report=struct('Passed',true,'ActualSavedCoreUsed',true,'HardwareIO',false, ...
    'StaticModeTransitionLegacyPeakMps',max(abs(floorData(selected,2))), ...
    'StaticModeTransitionCorrectedPeakMps',floorNew,'StaticLegacyWholePeakMps',floorOld, ...
    'KnownMotionVelocityRMSEMps',velocityRMSE,'SecondTakeoffStable',true, ...
    'AccelerationUnits','m/s^2','TelemetryBiasUnits','g', ...
    'PIDParametersChanged',false,'FlightCauseProven',false,'FirmwareFlashed',false);
save(fullfile(folder,'vertical_boundary_tests.mat'),'report','t','floorData','motionData','data');
fig=figure('Visible','off','Position',[40 40 1000 700]);tiledlayout(fig,2,1);
nexttile;plot(t,floorData(:,2),t,floorData(:,5));xlim([2.8 3.6]);grid on;
legend('Legacy reset each tick','Rising-edge reset');ylabel('velocity (m/s)');title('Stationary, quantized ToF, Mode 3 to 2');
nexttile;plot(t,truthVelocity,t,motionData(:,5));grid on;legend('Known upward velocity','Corrected estimator');
ylabel('velocity (m/s)');xlabel('time (s)');
exportgraphics(fig,fullfile(folder,'vertical_boundary_tests.png'),'Resolution',140);close(fig);
fid=fopen(fullfile(root,'docs','vertical_boundary_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('VERTICAL_BOUNDARY_VERIFICATION_PASSED\n');
end
function values=runCase(model,t,range,acc,mode)
inputs=Simulink.SimulationData.Dataset;
inputs=inputs.addElement(timeseries(single(range),t),'RangeM');
inputs=inputs.addElement(timeseries(single(acc),t),'VerticalAccelG');
inputs=inputs.addElement(timeseries(uint8(mode),t),'Mode');
inputs=inputs.addElement(timeseries(logical(mode==3),t),'ParkingReset');
in=Simulink.SimulationInput(model);in=in.setExternalInput(inputs);
in=in.setModelParameter('StopTime',num2str(t(end)));
out=sim(in);values=zeros(numel(t),6);
for k=1:6,ts=out.yout.getElement(k).Values;values(:,k)=double(ts.Data(:));end
end
