function result=compare_full_model()
%COMPARE_FULL_MODEL Mode transitions and Flip against unchanged official C++.
root=fileparts(fileparts(mfilename('fullpath')));init_official;ref=fullfile(root,'tests','reference');addpath(ref);
m='StampFly_Official_FullReplay400';n=9000;u=zeros(n,23,'single');
u(:,6)=4;u(:,15)=3.8;u(:,19)=.0025;u(:,22)=1;
t=(0:n-1)'*.0025;
u(:,13)=single(.5)*min(max(single((t-2.5)/2.5),single(0)),single(1));
u(:,7)=single(.015*sin(t*3));u(:,8)=single(.01*cos(t*2));
u(:,10)=single(.045*cos(t*3));u(:,11)=single(-.02*sin(t*2));u(:,14)=single(.01*sin(t));
u(900:939,20)=1;u(2400:2500,1)=.3;u(2550:2650,3)=.05;
u(2800:3100,5)=1;u(2900:3000,6)=5;u(2900:3000,4)=.3;
u(3300:3311,21)=1;u(4100:4200,16)=20;
u(4500:4539,20)=1;u(4600:4850,13)=linspace(.5,.08,251);
u(4851:5199,13)=.08;u(5000:5039,20)=1;
u(5200:5699,13)=linspace(.08,.5,500);
u(5700:5799,22)=0;u(5750:5900,13)=linspace(.5,.08,151);u(5901:6399,13)=.08;
u(6100:6139,20)=1;u(6400:6599,13)=linspace(.08,.5,200);
u(6600,17)=1;u(6900:6939,20)=1;u(7200:end,15)=3.5;
% Clear oracle MEX so static official variables start from the firmware boot.
clear official_full_reference;expected=official_full_reference(u);
assignin('base','FullReplayTrace',struct('time',t,'signals',struct('values',u,'dimensions',23)));
assignin('base','FullReplayStop',(n-1)*.0025);
if ~isfile(stampfly_model_file(m)),assemble_full_replay;end
open_system(stampfly_model_file(m));
out=sim(m);actual=out.yout{1}.Values.Data;diag=out.yout{2}.Values.Data;
state=out.yout{3}.Values.Data;altFlag=out.yout{4}.Values.Data;phase=out.yout{5}.Values.Data;branch=out.yout{6}.Values.Data;
result=struct('Samples',n,'MaxDutyError',max(abs(actual-expected(:,1:4)),[],'all'), ...
 'MaxCoreError',max(abs(diag(:,1:5)-expected(:,5:9)),[],'all'), ...
 'StateMismatches',nnz(single(state)~=expected(:,18)),'AltFlagMismatches',nnz(single(altFlag)~=expected(:,19)), ...
 'FlipFlagMismatches',nnz(single(phase)~=expected(:,20)),'BranchMismatches',nnz(single(branch)~=expected(:,22)));
save(fullfile(root,'tests','full_model_comparison.mat'),'u','expected','actual','diag','state','altFlag','phase','branch','result');disp(result);
assert(result.MaxDutyError<single(3e-6),'official:FullDutyMismatch','Duty differs from official C++.');
assert(result.MaxCoreError<single(3e-5),'official:FullCoreMismatch','Controller state differs from official C++.');
assert(result.StateMismatches+result.AltFlagMismatches+result.FlipFlagMismatches+result.BranchMismatches==0, ...
 'official:FullModeMismatch','Mode/AltFlag/Flip/dispatch differs from official C++.');
end
