function result=compare_official_estimators()
%COMPARE_OFFICIAL_ESTIMATORS Compare exact Madgwick and Kalman implementations.
root=fileparts(fileparts(mfilename('fullpath')));ref=fullfile(root,'tests','reference');addpath(root,ref);
folder=reference_mex_folder();
if ~isfile(fullfile(folder,['official_estimator_reference.' mexext]))
    source=fullfile(root,'official_sources','M5StampFly');
    mex('-R2018a','COMPFLAGS=$COMPFLAGS /utf-8 /wd4305 /wd4244',['-I' ref], ...
        ['-I' fullfile(source,'src')],['-I' fullfile(source,'lib','MdgwickAHRS')], ...
        fullfile(ref,'official_estimator_reference.cpp'),fullfile(source,'src','alt_kalman.cpp'), ...
        fullfile(source,'lib','MdgwickAHRS','MadgwickAHRS.cpp'), ...
        '-outdir',folder,'-output','official_estimator_reference');
end
n=2400;t=single((0:n-1)'*.0025);u=zeros(n,12,'single');
u(:,1)=.2*sin(t*3);u(:,2)=.1*cos(t*2);u(:,3)=.15*sin(t);
u(:,4)=.12*sin(t*2);u(:,5)=.1*cos(t*3);u(:,6)=-1;
u(:,7)=.5+.1*sin(t);u(:,8)=.2*sin(t*2);u(:,9)=.0025;
u(800,11)=1;u(1200:1205,12)=1;
u(1400:1410,4:6)=0; % gyro-only branch
expected=official_estimator_reference(u);actual=zeros(n,6,'single');q=single([1;0;0;0]);s=official.kalmanInitial();
for k=1:n
    [a,q]=official.madgwickStep(u(k,1:3)',u(k,4:6)',q,u(k,11)~=0);
    [v,s]=official.kalmanStep(u(k,7),u(k,8),u(k,9),u(k,12)~=0,s);
    actual(k,:)=[a;v]';
end
result=struct('Samples',n,'MaxAttitudeErrorRad',max(abs(actual(:,1:3)-expected(:,1:3)),[],'all'), ...
    'MaxKalmanError',max(abs(actual(:,4:6)-expected(:,4:6)),[],'all'));
save(fullfile(folder,'estimator_comparison.mat'),'u','expected','actual','result');disp(result);
assert(result.MaxAttitudeErrorRad<single(3e-6),'Madgwick port differs from official.');
assert(result.MaxKalmanError<single(3e-6),'Kalman port differs from official.');
end
