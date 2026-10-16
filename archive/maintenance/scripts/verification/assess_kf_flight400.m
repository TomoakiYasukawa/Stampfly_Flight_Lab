function report=assess_kf_flight400()
%ASSESS_KF_FLIGHT400 Record numerical/control acceptance with engineering units.
% Read actual comparison traces and mark passed only when every bound holds.
root=stampfly_project_root();folder=fullfile(root,'build','kf400','tests');
report=jsondecode(fileread(fullfile(root,'docs','history','kf_flight_verification.json')));
component=jsondecode(fileread(fullfile(root,'docs','history','kf_altitude_verification.json')));
numerics=jsondecode(fileread(fullfile(root,'docs','history','kf_altitude_numerics.json')));
assert(strcmp(report.ModelSHA256,sha256(fullfile(root,'archive','kf400','archive/kf400/StampFly_KF400.slx'))));
assert(strcmp(report.ModelSHA256,component.ModelSHA256));
assert(strcmp(report.BaselineModelSHA256,component.SourceModelSHA256));
assert(strcmp(report.ModelSHA256,numerics.ModelSHA256));
assert(strcmp(component.SourceModelSHA256,numerics.SourceModelSHA256));
limits=struct('HeightVsDouble',1e-5,'VelocityVsDouble',5e-4,'BiasVsDouble',.005, ...
    'IntegratedHeightVsBaseline',1e-4,'IntegratedDutyVsBaseline',.5/255, ...
    'IntegratedPWMCountsVsBaseline',1,'LandingBaseDutyVsBaseline',.5/255);
% Height 10 um is 1/400 of the configured 4 mm measurement standard deviation.
% Velocity .0005 is 1/300 of the retained .15 landing speed reference. The
% internal bias is not a direct PID input; its error must remain below .005.
referenceErrors=zeros(1,3);componentCases=fieldnames(component.Cases);
for k=1:numel(componentCases)
    name=componentCases{k};c=component.Cases.(name);
    assert(c.Finite&&c.TypesAndSizesMatch);
    referenceErrors=max(referenceErrors,numerics.Cases.(name).NewMaximumReferenceErrors(:)');
end
component.DoubleReferenceRecord='docs/history/kf_altitude_numerics.json';
component.MaximumErrorsVsDouble=referenceErrors;
component.NumericalAcceptanceBounds=[limits.HeightVsDouble limits.VelocityVsDouble limits.BiasVsDouble];
component.NumericalAccuracyPassed=all(referenceErrors<=component.NumericalAcceptanceBounds);
component.Passed=component.ModeHoldAndPublicReset&&component.NumericalAccuracyPassed;
writeJSON(fullfile(root,'docs','history','kf_altitude_verification.json'),component);
cases=fieldnames(report.Cases);peaks=struct;maxDuty=0;maxCounts=0;maxHeight=0;
for c=1:numel(cases)
    name=cases{c};f=load(fullfile(folder,[name '_pipeline.mat']),'out');
    mode=double(squeeze(f.out.yout{5}.Values.Data));
    t=f.out.yout{5}.Values.Time;
    result=struct;
    for item={'Altitude','Velocity','Duty'}
        label=item{1};index=find(strcmp(report.Outputs,label));
        a=double(f.out.yout{2*index-1}.Values.Data);b=double(f.out.yout{2*index}.Values.Data);
        delta=abs(a-b);
        if size(delta,1)==numel(t)
            perTick=max(reshape(delta,numel(t),[]),[],2);
        else
            perTick=max(reshape(delta,[],numel(t)),[],1)';
        end
        [value,j]=max(perTick);
        active=mode==2|mode==5;
        result.(label)=struct('MaximumDifference',value,'AtSeconds',t(j),'Mode',mode(j), ...
            'MaximumDuringFlightOrLanding',max(perTick(active)), ...
            'RMSPerTick',sqrt(mean(perTick.^2)));
    end
    % SensorDiagnostics8 changes only its second element (Kalman bias).
    a=squeeze(f.out.yout{21}.Values.Data);b=squeeze(f.out.yout{22}.Values.Data);
    if size(a,1)==numel(t),a=a';b=b';end
    assert(isequaln(a([1 3:8],:),b([1 3:8],:)));
    result.SensorDiagnosticsOnlyBiasChanged=true;
    % Altitude reference, counters and roll/pitch/yaw terms stay exact. The
    % landing descent updates base duty conditionally from estimated height,
    % so sub-mm height roundoff may affect that term during mode 5 only.
    a=squeeze(f.out.yout{19}.Values.Data);b=squeeze(f.out.yout{20}.Values.Data);
    if size(a,1)==numel(t),a=a';b=b';end
    assert(isequaln(a([1 3 6:13],:),b([1 3 6:13],:)));
    previousMode=double(squeeze(f.out.yout{23}.Values.Data));
    landingUsed=mode==5|previousMode==5;
    assert(isequaln(a(2,~landingUsed),b(2,~landingUsed)));
    result.MaximumLandingBaseDutyDifference=max(abs(double(a(2,:))-double(b(2,:))));
    assert(result.MaximumLandingBaseDutyDifference<=limits.LandingBaseDutyVsBaseline);
    result.ControlDiagnosticsOnlyVerticalControlAndMotorMixChanged=true;
    maxDuty=max(maxDuty,result.Duty.MaximumDifference);
    maxCounts=max(maxCounts,report.Cases.(name).MaximumPWMCountDifference);
    maxHeight=max(maxHeight,result.Altitude.MaximumDifference);
    assert(report.Cases.(name).UnchangedSignalsIdentical);
    peaks.(name)=result;
end
assessment=struct('Bounds',limits,'MaximumErrorsVsDouble',referenceErrors, ...
    'MaximumIntegratedHeightDifference',maxHeight,'MaximumIntegratedDutyDifference',maxDuty, ...
    'MaximumIntegratedPWMCountDifference',maxCounts,'CaseDetails',peaks, ...
    'ComponentStressDifferenceReason',['The direct unfiltered altitude step after PARKING ' ...
        'amplifies subtractive covariance roundoff in the original single implementation. ' ...
        'The standard block uses a Joseph covariance update and tracks the double equations.'], ...
    'AcceptanceRationale',['State timing, update gating and retained-state covariance resets ' ...
        'match the original equations. New estimates satisfy the stated double-reference bounds. ' ...
        'Integrated height error is below 0.1 mm; computed duty differs by less than half an ' ...
        '8-bit PWM count and quantized outputs by at most one count. Unchanged inputs, ' ...
        'attitude, mode transitions and horizontal control terms match exactly.'], ...
    'Scope','Offline estimator and actual saved controller/log blocks; physical flight not tested', ...
    'Passed',component.Passed&&maxHeight<=limits.IntegratedHeightVsBaseline&& ...
        maxDuty<=limits.IntegratedDutyVsBaseline&&maxCounts<=limits.IntegratedPWMCountsVsBaseline);
report.Component=component;report.NumericalAssessment=assessment;
report.Passed=report.AllComparisonsCompleted&&assessment.Passed&&report.Logging.Passed&&report.PIDCount==7;
writeJSON(fullfile(root,'docs','history','kf_flight_verification.json'),report);
disp(assessment);assert(report.Passed,'kf400:AssessmentFailed','Numerical/control acceptance failed.');
fprintf('KF400_NUMERICAL_AND_CONTROL_ASSESSMENT_PASSED\n');
end
function digest=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);digest=lower(strtrim(value));
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
