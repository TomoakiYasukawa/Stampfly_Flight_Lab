function init_official_replay()
%INIT_OFFICIAL_REPLAY Deterministic input trace, no device/plant assumption.
init_official;
s=load(fullfile(stampfly_project_root(),'tests','controller_comparison.mat'),'u');
time=(0:size(s.u,1)-1)'*.0025;
assignin('base','OfficialReplayInput',[time double(s.u(:,1:19))]);
end
