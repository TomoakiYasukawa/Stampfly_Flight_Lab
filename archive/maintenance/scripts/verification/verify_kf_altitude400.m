function report=verify_kf_altitude400(reuseHarness)
%VERIFY_KF_ALTITUDE400 Compare actual old/new altitude blocks without hardware.
% These cases exercise mode hold, covariance reset and current-input timing.
if nargin==0,reuseHarness=false;end
root=stampfly_project_root();init_kf_flight();ensure_simulink_toolkit();
layoutListeners=layout.LayoutListeners();
layoutDisabler=layoutListeners.getScopedLayoutListenerDisabler('KFAltitudeComparison400'); %#ok<NASGU>
models={'StampFly_IMU400','StampFly_KF400'};
for k=1:2,open_system(fullfile(root,[models{k} '.slx']));end
s=jsondecode(fileread(fullfile(root,'docs','history','kf_flight_structure.json')));
folder=fullfile(root,'build','kf400','tests');if ~isfolder(folder),mkdir(folder);end
harness='KFAltitudeComparison400';
names={'AltitudeM','AccelerationG','PreviousMode','Dt','ParkingReset'};
types={'single','single','uint8','single','boolean'};
if ~reuseHarness
    if bdIsLoaded(harness),close_system(harness,0);end
    new_system(harness);open_system(harness);
    ops={reorg.configure(['config:' harness],struct('Solver','FixedStepDiscrete','FixedStep','.0025', ...
        'StopTime','1','SaveOutput','on','OutputSaveName','yout','SaveFormat','Dataset')), ...
        reorg.add(reorg.path(models{1},'blk_2236'),'OriginalAltitudeKalman','old'), ...
        reorg.add(reorg.path(models{2},s.AltitudeBlock),'StandardAltitudeKalman','new')};
    for k=1:5
        ops{end+1}=reorg.add('Inport',names{k},['i' num2str(k)],struct('Port',num2str(k), ...
            'OutDataTypeStr',types{k},'PortDimensions','1','SampleTime','.0025')); %#ok<AGROW>
        ops{end+1}=reorg.wire(sprintf('#i%d.y1',k),sprintf('#old.u%d',k)); %#ok<AGROW>
        ops{end+1}=reorg.wire(sprintf('#i%d.y1',k),sprintf('#new.u%d',k)); %#ok<AGROW>
    end
    for k=1:3
        for pair=1:2
            ref=sprintf('out%d_%d',k,pair);source='#old';if pair==2,source='#new';end
            ops{end+1}=reorg.add('Outport',ref,ref,struct('Port',num2str(2*k-2+pair))); %#ok<AGROW>
            ops{end+1}=reorg.wire(sprintf('%s.y%d',source,k),['#' ref '.u1']); %#ok<AGROW>
        end
    end
    reorg.edit(harness,'root',ops,'full');
    check=char(model_check(harness,'root','["all"]'));disp(check);assert(~contains(check,'severity: error'));
    save_system(harness,fullfile(folder,[harness '.slx']));
else
    open_system(fullfile(folder,[harness '.slx']));
end
report=struct('Model',models{2},'ModelSHA256',sha256(fullfile(root,[models{2} '.slx'])), ...
    'SourceModel',models{1},'SourceModelSHA256',sha256(fullfile(root,[models{1} '.slx'])), ...
    'ActualSavedBlocksCompared',true,'SampleTime',.0025,'Outputs',{{'Height','Velocity','Bias'}}, ...
    'Samples',0,'Cases',struct,'Passed',false,'PhysicalFlightTested',false,'Flashed',false);
cases={'BootWaitFlyLandRelaunch','StartActiveVariableDt','HeldToFAndAcceleration','ResetDuringHold'};
for c=1:numel(cases)
    [t,data]=fixture(cases{c});
    dataset=Simulink.SimulationData.Dataset;
    for k=1:5
        ts=timeseries(data{k},t);ts.DataInfo.Interpolation=tsdata.interpolation('zoh');
        dataset=dataset.addElement(ts,names{k});
    end
    in=Simulink.SimulationInput(harness);in=in.setExternalInput(dataset);
    in=in.setModelParameter('StopTime',num2str(t(end),17));out=sim(in);
    result=struct('Samples',numel(t),'MaxAbsoluteErrors',zeros(1,3), ...
        'RMSErrors',zeros(1,3),'ExactMismatchCounts',zeros(1,3), ...
        'Finite',true,'TypesAndSizesMatch',true);
    for k=1:3
        a=out.yout{2*k-1}.Values.Data;b=out.yout{2*k}.Values.Data;
        result.TypesAndSizesMatch=result.TypesAndSizesMatch&&isequal(size(a),size(b))&& ...
            strcmp(class(a),'single')&&strcmp(class(b),'single');
        result.Finite=result.Finite&&all(isfinite(a),'all')&&all(isfinite(b),'all');
        delta=double(a)-double(b);
        result.MaxAbsoluteErrors(k)=max(abs(delta),[],'all');
        result.RMSErrors(k)=sqrt(mean(delta.^2,'all'));
        result.ExactMismatchCounts(k)=nnz(a~=b);
    end
    report.Cases.(cases{c})=result;report.Samples=report.Samples+numel(t);
    save(fullfile(folder,[cases{c} '.mat']),'out','t','data','result');
    assert(result.Finite&&result.TypesAndSizesMatch,'kf400:InvalidEstimate','Invalid %s output.',cases{c});
    fprintf('KF400_ALTITUDE_CASE: %s error=%s\n',cases{c},mat2str(result.MaxAbsoluteErrors,9));
end
% Capture differences before assessing their influence on the complete PID path.
report.MaxAbsoluteErrors=max(vertcat(report.Cases.BootWaitFlyLandRelaunch.MaxAbsoluteErrors, ...
    report.Cases.StartActiveVariableDt.MaxAbsoluteErrors,report.Cases.HeldToFAndAcceleration.MaxAbsoluteErrors, ...
    report.Cases.ResetDuringHold.MaxAbsoluteErrors),[],1);
report.ModeHoldAndPublicReset=verifyHold(folder);
report.AllComparisonsCompleted=true;
report.Passed=false; % assess_kf_flight400 also checks the double-reference error
fid=fopen(fullfile(root,'docs','history','kf_altitude_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('KF400_ALTITUDE_COMPONENT_COMPARISON_COMPLETE\n');disp(report);
end
function [t,data]=fixture(name)
t=(0:.0025:30)';n=numel(t);h=single(.0025*(1+.15*sin(7*t)));
alt=single(.45+.12*sin(2*t));az=single(.05*cos(2*t));
mode=repmat(uint8(4),n,1);reset=false(n,1);
switch name
    case 'BootWaitFlyLandRelaunch'
        mode(t<.2)=uint8(0);mode(t>=.2&t<2.2)=uint8(1);
        wait=(t>=2.2&t<4)|(t>=12&t<14)|(t>=23&t<25);mode(wait)=uint8(3);reset(wait)=true;
        alt(t<4)=single(.03);alt(t>=12&t<14)=single(.03);
    case 'StartActiveVariableDt'
        h(t>=10&t<10.02)=single(.004);h(t>=20&t<20.02)=single(.001);
    case 'HeldToFAndAcceleration'
        h(:)=single(.0025);alt=single(.4+.15*sin(2*floor(t*25)/25));
        alt(t>=5&t<7)=alt(find(t>=5,1));alt(t>=14&t<14.04)=single(0);
        az(t>=10&t<10.25)=single(.3);az(t>=10.25&t<10.5)=single(-.3);
    case 'ResetDuringHold'
        mode(t>=4&t<7)=uint8(1);reset(t>=5&t<5.025)=true;
        mode(t>=12&t<14)=uint8(0);reset(t>=13&t<13.025)=true;
        mode(t>=20&t<21)=uint8(3);reset(t>=20&t<21)=true;
end
data={alt,az,mode,h,reset};
end
function passed=verifyHold(folder)
f=load(fullfile(folder,'ResetDuringHold.mat'),'out','t','data');passed=true;
for pair=1:2
    for k=1:3
        value=squeeze(f.out.yout{2*k-2+pair}.Values.Data);
        held=f.t>=4&f.t<5;passed=passed&&all(value(held)==value(find(held,1)));
        zero=f.t>=5&f.t<7;passed=passed&&all(value(zero)==0);
        zero=f.t>=13&f.t<14;passed=passed&&all(value(zero)==0);
    end
end
assert(passed,'kf400:HoldReset','Mode hold or public-output reset changed.');
end
function digest=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);digest=lower(strtrim(value));
end
