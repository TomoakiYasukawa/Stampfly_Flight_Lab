function report=verify_imu_flight400(reuseHarness)
%VERIFY_IMU_FLIGHT400 Exercise the actual saved IMU Filter subsystem offline.
% No hardware input, motor output, deployment or model logic reimplementation.
if nargin==0,reuseHarness=false;end
root=stampfly_project_root();init_imu_flight();ensure_simulink_toolkit();
model='StampFly_IMU400';source='StampFly_Basic400';
open_system(fullfile(root,[source '.slx']));open_system(stampfly_model_file(model));
structure=jsondecode(fileread(fullfile(root,'docs','history','imu_flight_structure.json')));
folder=fullfile(root,'build','imu400','tests');if ~isfolder(folder),mkdir(folder);end
harness='IMUAttitudeVerification400';
if ~reuseHarness
    if bdIsLoaded(harness),close_system(harness,0);end
    new_system(harness);open_system(harness);
    ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
        'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
        reorg.add(reorg.path(model,structure.AttitudeBlock),'ActualIMUAttitude','imu'), ...
        reorg.add(reorg.path(source,'blk_2243'),'OriginalMadgwick','old')};
    names={'Rates','AccelerationG','PreviousMode','AttitudeReset'};
    types={'single','single','uint8','boolean'};dims=[3 3 1 1];
    for k=1:4
        ops{end+1}=reorg.add('Inport',names{k},['i' num2str(k)], ...
            struct('Port',num2str(k),'OutDataTypeStr',types{k},'PortDimensions',num2str(dims(k)), ...
            'SampleTime','.0025'));
        ops{end+1}=reorg.wire(sprintf('#i%d.y1',k),sprintf('#imu.u%d',k));
        ops{end+1}=reorg.wire(sprintf('#i%d.y1',k),sprintf('#old.u%d',k));
    end
    for k=1:5
        ops{end+1}=reorg.add('Outport',['Result' num2str(k)],['o' num2str(k)],struct('Port',num2str(k)));
        if k<=3,src=sprintf('#imu.y%d',k);else,src=sprintf('#old.y%d',k-3);end
        ops{end+1}=reorg.wire(src,sprintf('#o%d.u1',k));
    end
    reorg.edit(harness,'root',ops,'full');disp(model_read(harness,'root','0'));
    check=char(model_check(harness,'root','["all"]'));disp(check);assert(~contains(check,'severity: error'));
    save_system(harness,fullfile(folder,[harness '.slx']));
else
    open_system(fullfile(folder,[harness '.slx']));
end
report=struct('Model',[model '.slx'],'SourceModel',[source '.slx'], ...
    'SampleRate',400,'SinglePrecision',true,'CorrectedGyroToPID',true, ...
    'Flashed',false,'PhysicalFlightTested',false,'Passed',false);
% Startup: angles are zero and the gyro remains live before calibration ends.
t=(0:.0025:1)';n=numel(t);rates=repmat(single([.02 -.03 .01]),n,1);
data={rates,repmat(single([0 0 -1]),n,1),uint8(mod(floor(t/.1),2)),false(n,1)};
out=runCase(harness,t,data);
assert(all(values(out,1)==0,'all'));assert(all(values(out,2)==single([1 0 0 0]),'all'));
assert(isequal(values(out,3),rates));assert(isequal(values(out,1),values(out,4)));
assert(isequal(values(out,2),values(out,5)));report.StartupHold=true;
fprintf('IMU400_STARTUP_HOLD_PASSED\n');
% Static level and known signed tilts independently expose swapped axes/signs.
report.StaticTilt=struct('BodyAxis',{},'Radians',{},'FinalAngle',{},'ErrorRadians',{});
for axis=0:2
    signs=1;if axis>0,signs=[-1 1];end
    for direction=signs
        tilt=.25*direction;truth=zeros(1,3);
        if axis>0,truth(3-axis)=tilt;end % body X -> filter Y, body Y -> filter X
        qTruth=quaternion(truth,'euler','XYZ','point');
        accel=single(rotateframe(qTruth,[0 0 9.80665]));bodyAccel=single([accel(2) accel(1) -accel(3)])/single(9.80665);
        t=(0:.0025:8)';n=numel(t);data={zeros(n,3,'single'),repmat(bodyAccel,n,1),repmat(uint8(3),n,1),false(n,1)};
        out=runCase(harness,t,data);angles=values(out,1);q=values(out,2);omega=values(out,3);
        assert(all(isfinite(angles),'all')&&all(isfinite(q),'all')&&all(isfinite(omega),'all'));
        assert(max(abs(sum(double(q).^2,2)-1))<2e-5);
        errorAngle=0;if axis>0,errorAngle=abs(double(angles(end,axis))-tilt);assert(errorAngle<.01);end
        if axis==0,assert(max(abs(double(angles(end,1:2))))<1e-4);end
        assert(abs(double(angles(end,3))+pi)<.01);
        assert(strcmp(class(angles),'single')&&strcmp(class(q),'single')&&strcmp(class(omega),'single'));
        report.StaticTilt(end+1)=struct('BodyAxis',axis,'Radians',tilt,'FinalAngle',double(angles(end,:)), ...
            'ErrorRadians',errorAngle);
    end
end
fprintf('IMU400_LEVEL_AND_SIGNED_TILT_PASSED\n');
% Constant-rate motion with physically consistent gravity in the sensor frame.
report.AxisRotation=struct('BodyAxis',{},'CorrectedRateError',{},'FinalAngleError',{});
for axis=1:3
    t=(0:.0025:3)';n=numel(t);rates=zeros(n,3,'single');rates(t>=1 & t<2,axis)=single(.3);
    angle=.3*min(max(t-1,0),1);truth=zeros(n,3);filterAxis=[2 1 3];filterSign=[1 1 -1];
    truth(:,filterAxis(axis))=filterSign(axis)*angle;
    qTruth=quaternion(truth,'euler','XYZ','point');accel=single(rotateframe(qTruth,repmat([0 0 9.80665],n,1)));
    bodyAccel=single([accel(:,2) accel(:,1) -accel(:,3)])/single(9.80665);
    out=runCase(harness,t,{rates,bodyAccel,repmat(uint8(3),n,1),false(n,1)});
    omega=values(out,3);angles=values(out,1);
    rateError=max(abs(double(omega)-double(rates)),[],'all');assert(rateError<.04);
    if axis==3,finalError=abs(double(angles(end,3))-(-pi+.3));else,finalError=abs(double(angles(end,axis))-.3);end
    assert(finalError<.03);
    report.AxisRotation(end+1)=struct('BodyAxis',axis,'CorrectedRateError',rateError,'FinalAngleError',finalError);
end
fprintf('IMU400_THREE_AXIS_ROTATION_PASSED\n');
% Residual roll/pitch bias is observable from gravity. Yaw bias is not.
t=(0:.0025:30)';n=numel(t);bias=single([.03 -.02 0]);
out=runCase(harness,t,{repmat(bias,n,1),repmat(single([0 0 -1]),n,1),repmat(uint8(3),n,1),false(n,1)});
omega=values(out,3);corrected=mean(double(omega(end-799:end,:)),1);
assert(norm(corrected(1:2))<.5*norm(double(bias(1:2))));
report.ResidualBias=struct('InputRadiansPerSecond',double(bias),'CorrectedRadiansPerSecond',corrected, ...
    'YawBiasObservable',false);fprintf('IMU400_RESIDUAL_BIAS_CORRECTION_PASSED\n');
% Hold, reset while disabled, repeated level resets, and reset/re-enable.
t=(0:.0025:8)';n=numel(t);modes=repmat(uint8(3),n,1);modes(t>=2 & t<4)=uint8(1);
rates=zeros(n,3,'single');rates(t<2,3)=single(.1);resets=false(n,1);
resets(t>=3 & t<3.01)=true;resets(t>=6 & t<6.01)=true;
out=runCase(harness,t,{rates,repmat(single([0 0 -1]),n,1),modes,resets});
angles=values(out,1);q=values(out,2);oldAngles=values(out,4);oldQ=values(out,5);
held=t>=2 & t<4;assert(all(angles(held,:)==angles(find(held,1),:),'all'));
assert(all(oldAngles(held,:)==oldAngles(find(held,1),:),'all'));
afterReset=t>=3 & t<4;assert(all(q(afterReset,:)==single([1 0 0 0]),'all'));
assert(all(oldQ(afterReset,:)==single([1 0 0 0]),'all'));
assert(max(abs(double(angles(t>=6.01,3))+pi))<.01);
assert(all(isfinite(angles),'all'));report.ModeHoldAndRepeatedReset=true;
fprintf('IMU400_MODE_HOLD_AND_RESETS_PASSED\n');
report.UnchangedSections=verifyUnchanged(root,source,model);
report.Passed=true;writeReport(root,report);disp(report);
end
function out=runCase(harness,t,data)
dataset=Simulink.SimulationData.Dataset;
for k=1:numel(data)
    ts=timeseries(data{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');dataset=dataset.addElement(ts);
end
in=Simulink.SimulationInput(harness);in=in.setExternalInput(dataset);
in=in.setModelParameter('StopTime',num2str(t(end),17));out=sim(in);
end
function data=values(out,k)
data=squeeze(out.yout{k}.Values.Data);
if size(data,1)~=numel(out.tout),data=data.';end
end
function report=verifyUnchanged(root,source,model)
% Compare saved algorithm source and operational parameters of each section.
ids={'blk_2721','blk_2274','blk_3131','blk_3213','blk_4038','blk_2236','blk_2253','blk_2244'};
count=0;
for k=1:numel(ids)
    a=reorg.path(source,ids{k});b=reorg.path(model,ids{k});
    aa=find_system(a,'LookUnderMasks','all','Type','Block');bb=find_system(b,'LookUnderMasks','all','Type','Block');
    assert(numel(aa)==numel(bb));
    for j=1:numel(aa)
        sid=Simulink.ID.getSID(aa{j});id=['blk_' extractAfter(sid,[source ':'])];
        other=reorg.path(model,id);assert(ismember(other,bb));
        assert(strcmp(get_param(aa{j},'BlockType'),get_param(other,'BlockType')));
        params=get_param(aa{j},'DialogParameters');
        if isstruct(params)
            for p=string(fieldnames(params))'
                assert(isequaln(get_param(aa{j},p),get_param(other,p)), ...
                    'imuflight:UnexpectedChange','%s / %s changed.',id,p);
            end
        end
        if strcmp(get_param(aa{j},'BlockType'),'SubSystem')&&strcmp(get_param(aa{j},'SFBlockType'),'MATLAB Function')
            assert(strcmp(get_param(aa{j},'MATLABFunctionConfiguration').FunctionScript, ...
                get_param(other,'MATLABFunctionConfiguration').FunctionScript));
        end
        if strcmp(get_param(aa{j},'BlockType'),'SubSystem')
            assert(isequal(reorg.links(source,id),reorg.links(model,id)), ...
                'imuflight:WiringChanged','Wiring in %s changed.',id);
            chartA=sfroot().find('-isa','Stateflow.Chart','Path',aa{j});
            chartB=sfroot().find('-isa','Stateflow.Chart','Path',other);
            if ~isempty(chartA)&&~isa(chartA,'Stateflow.EMChart')
                statesA=chartA.find('-isa','Stateflow.State');statesB=chartB.find('-isa','Stateflow.State');
                assert(isequal({statesA.LabelString},{statesB.LabelString}));
                transA=chartA.find('-isa','Stateflow.Transition');transB=chartB.find('-isa','Stateflow.Transition');
                assert(isequal({transA.LabelString},{transB.LabelString}));
            end
        end
        count=count+1;
    end
end
sourceFile=fullfile(root,[source '.slx']);info=dir(sourceFile);
report=struct('SectionIDs',{ids},'ComparedBlocks',count,'ParametersAndAlgorithmsIdentical',true, ...
    'SourceBytes',info.bytes,'PIDCount',numel(find_system(model,'LookUnderMasks','all','Name','DedicatedPID')));
assert(report.PIDCount==7);fprintf('IMU400_UNCHANGED_SECTIONS_PASSED: %d blocks\n',count);
end
function writeReport(root,report)
fid=fopen(fullfile(root,'docs','history','imu_flight_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
