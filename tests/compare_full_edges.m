function results=compare_full_edges()
%COMPARE_FULL_EDGES Exercise interruptions during each original Flip phase.
root=fileparts(fileparts(mfilename('fullpath')));init_official;addpath(fullfile(root,'tests','reference'));
folder=build_full_reference_mex();
model='StampFly_Official_FullReplay400';load_system(stampfly_model_file(model));
cases={'FlipLinkLoss','FlipOverG','FlipArmLanding','LowThrustFlip','AHRSAndModeChanges'};
results=struct;
for c=1:numel(cases)
 n=4500;t=(0:n-1)'*.0025;u=zeros(n,23,'single');
 u(:,6)=4;u(:,15)=3.8;u(:,19)=.0025;u(:,22)=1;
 u(900:939,20)=1;u(1000:end,13)=.5;u(2400:2411,21)=1;
 switch c
  case 1,u(2600:2749,22)=0;
  case 2,u(2630,17)=1;
  case 3,u(2600:2639,20)=1;
  case 4,u(2300:end,6)=5;u(2300:end,4)=-.99;
  case 5
   u(820:825,23)=1;u(2000:2299,5)=1;u(2800:2999,6)=5;u(2800:2999,4)=.3;
   u(3100:3200,4)=1;u(3300:3400,4)=-1;u(3500:3600,16)=20;
 end
 clear official_full_reference;expected=official_full_reference(u);
 assignin('base','FullReplayTrace',struct('time',t,'signals',struct('values',u,'dimensions',23)));
 assignin('base','FullReplayStop',t(end));out=sim(model);
 duty=out.yout{1}.Values.Data;diag=out.yout{2}.Values.Data;
 state=out.yout{3}.Values.Data;alt=out.yout{4}.Values.Data;
 phase=out.yout{5}.Values.Data;branch=out.yout{6}.Values.Data;
 r=struct('Samples',n,'MaxDutyError',max(abs(duty-expected(:,1:4)),[],'all'), ...
  'MaxCoreError',max(abs(diag(:,1:5)-expected(:,5:9)),[],'all'), ...
  'ModeMismatches',nnz(single(state)~=expected(:,18)), ...
  'AltMismatches',nnz(single(alt)~=expected(:,19)), ...
  'FlipMismatches',nnz(single(phase)~=expected(:,20)), ...
  'BranchMismatches',nnz(single(branch)~=expected(:,22)));
 results.(cases{c})=r;disp(cases{c});disp(r);
 save(fullfile(folder,[cases{c} '.mat']),'u','expected','duty','diag','state','alt','phase','branch','r');
 assert(r.MaxDutyError<single(3e-6) && r.MaxCoreError<single(3e-5), ...
  'official:EdgeNumericMismatch','%s numeric difference.',cases{c});
 assert(r.ModeMismatches+r.AltMismatches+r.FlipMismatches+r.BranchMismatches==0, ...
  'official:EdgeStateMismatch','%s state difference.',cases{c});
end
save(fullfile(folder,'full_edge_comparison.mat'),'results');
end
