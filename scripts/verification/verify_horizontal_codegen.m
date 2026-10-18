function report=verify_horizontal_codegen()
%VERIFY_HORIZONTAL_CODEGEN 同じ入力でMATLAB実行と生成済みMEXの状態・数値を比較。
% 生成コードを実行します。ESP32本体の浮動小数点・実センサー・機体応答は
% この比較の対象外であり、書き込み後のUSB机上観測を別に記録します。
root=stampfly_project_root();folder=fullfile(root,'build','horizontal_control','host_codegen');
if ~isfolder(folder),mkdir(folder);end
addpath(folder);[flow,inertial,range,context,~,control]=horizontal.fixture();manual=zeros(2,1,'single');
cfg=coder.config('mex');cfg.GenerateReport=true;
codegen('-config',cfg,'horizontal_codegen_step','-args',{flow,inertial,range,context,manual,control,false}, ...
    '-d',folder,'-o',fullfile(folder,'horizontal_codegen_step_mex'));
clear horizontal_codegen_step horizontal_codegen_step_mex
duration=30;n=duration*400;reference=zeros(40,n,'single');generated=reference;
totals=int64([4294967000;4294967000]);
for k=1:n
    t=single(k)*single(.0025);
    flow.Delta=single([round(2*sin(double(t)));round(-2*cos(double(t)))]);
    totals=totals+int64(flow.Delta);flow.Totals=uint32(mod(totals,int64(4294967296)));
    flow.Info=uint32([k;300;400;mod(4294950000+k*2500,4294967296)]);
    inertial.RawAngularRate=single([.025*sin(t*2);.02*cos(t*3);0]);
    inertial.StaticOffsets=single([.002;-.001;0;0]);
    inertial.FilteredRate=single([inertial.RawAngularRate(2);inertial.RawAngularRate(1);0])-inertial.StaticOffsets(1:3);
    inertial.CorrectedRate=inertial.FilteredRate-single([.001;-.002;0]);
    q=official.eulerQuaternion(single([.05*sin(t);.04*cos(t);.08*t]));
    inertial.Quaternion=single([q(1);q(3);q(2);-q(4)]);
    range.DistanceMm=int16(500+round(30*sin(double(t))));range.Fresh=uint8(mod(k,14)==0);
    range.VerticalSpeed=single(.03*cos(t));
    flow.Raw(1)=uint16(100);if t>=12&&t<12.1,flow.Raw(1)=uint16(0);end
    context.Reset=t>=20&&t<20.005;control.ControlContext.Reset=context.Reset;
    control.ControlMode=uint8(t>=24&&t<25);
    manual(:)=single(0);if t>=5&&t<8,manual(2)=single(-.25);end
    motorSaturated=t>=9&&t<10;
    reference(:,k)=horizontal_codegen_step(flow,inertial,range,context,manual,control,motorSaturated);
    generated(:,k)=horizontal_codegen_step_mex(flow,inertial,range,context,manual,control,motorSaturated);
end
error=max(abs(double(reference)-double(generated)),[],2);
% 時間改善前の保存結果と比較し、400 Hzの数値と状態が変わらないことも確認します。
goldenFile=fullfile(root,'build','horizontal_control','timing_before','golden_codegen_comparison.mat');
if ~isfile(goldenFile)
    baseline=fullfile(root,'tests','reference','horizontal_timing_baseline.zip');
    if isfile(baseline)
        folder=fullfile(root,'build','history','timing_baseline');
        if ~isfolder(folder),mkdir(folder);end
        unzip(baseline,folder);
        goldenFile=fullfile(folder,'build','horizontal_control','timing_before','golden_codegen_comparison.mat');
    end
end
goldenCompared=false;goldenError=0;
if isfile(goldenFile)
    golden=load(goldenFile,'reference');
    assert(isequal(size(golden.reference),size(reference)));
    goldenError=max(abs(double(golden.reference)-double(reference)),[],'all');
    assert(isequal(golden.reference,reference),'horizontal:TimingRegression','Timing adjustment changed numerical outputs.');
    goldenCompared=true;
end
discrete=[16 17 18 21 24 25 26 30 31 32];
assert(isequal(reference(discrete,:),generated(discrete,:)),'horizontal:GeneratedState','Generated state differs.');
assert(all(isfinite(reference),'all')&&all(isfinite(generated),'all'));
assert(all(error(13:14)<1e-5)&&all(error<1e-4),'horizontal:GeneratedNumerics','Generated numerical mismatch.');
save(fullfile(folder,'comparison.mat'),'reference','generated','error');
report=struct('Passed',true,'Samples',n,'DurationS',duration,'ExactStateMatch',true, ...
    'MaximumError',max(error),'Errors40',error,'GeneratedMEXExecuted',true,'ESP32PILExecuted',false, ...
    'ComparedWithBeforeTimingAdjustment',goldenCompared,'MaximumBeforeAfterError',goldenError);
fid=fopen(stampfly_report_file('docs/horizontal_codegen_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_GENERATED_CODE_VERIFICATION_PASSED\n');
end
