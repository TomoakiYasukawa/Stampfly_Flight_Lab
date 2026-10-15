function result = compare_official_controller()
%COMPARE_OFFICIAL_CONTROLLER Compare the MATLAB port with active official C++.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
ref=fullfile(root,'tests','reference');addpath(ref);
if ~isfile(fullfile(ref,['official_controller_reference.' mexext]))
    mex('-R2018a','COMPFLAGS=$COMPFLAGS /utf-8 /wd4305 /wd4244',['-I' ref],['-I' fullfile(root,'official_sources','M5StampFly','src')], ...
        fullfile(ref,'official_controller_reference.cpp'),fullfile(ref,'pid_reference.cpp'), ...
        '-outdir',ref,'-output','official_controller_reference');
end
n=4000;u=zeros(n,21,'single');u(:,6)=4;u(:,15)=3.8;u(:,18)=2;u(:,19)=.0025;
u(1:20,18)=3; t=single((0:n-1)'*.0025);
u(:,13)=single(.5)*min(max((t-single(.5))/single(2.5),single(0)),single(1));
u(:,14)=single(.03)*sin(t*single(2));
u(:,7)=single(.025)*sin(t*single(3));u(:,8)=single(.02)*cos(t*single(2));
u(:,10)=single(.07)*cos(t*single(3));u(:,11)=-single(.04)*sin(t*single(2));
u(1400:1600,1)=.7;u(1601:1700,3)=.1;u(1701:2100,4)=.3;
u(2300:2350,16)=20;u(2500:2510,17)=1;u(2600:2610,18)=3;
u(2800:end,15)=3.5;u(3200:end,4)=-.5;
expected=official_controller_reference(u);actual=zeros(n,21,'single');s=official.controllerInitial();
for k=1:n
    [d,~,v,s]=official.controllerStep(u(k,1:6)',u(k,7:9)',u(k,10:12)', ...
        u(k,13),u(k,14),u(k,15),uint8(u(k,16)),uint8(u(k,17)),uint8(u(k,18)),u(k,19),s);
    actual(k,:)=[d;v]';
end
% Official command diagnostics remain stale on reset; compare commanded duty
% and live altitude/ramp/thrust values separately from those stale debug fields.
delta=abs(actual(:,1:9)-expected(:,1:9));
result=struct('Samples',n,'MaxDutyError',max(delta(:,1:4),[],'all'), ...
    'MaxCoreError',max(delta(:,5:9),[],'all'),'ComparedColumns',1:9);
save(fullfile(root,'tests','controller_comparison.mat'),'u','expected','actual','result');
disp(result);
assert(result.MaxDutyError<single(3e-6),'Controller duty differs from official C++.');
assert(result.MaxCoreError<single(3e-5),'Controller core state differs from official C++.');
end
