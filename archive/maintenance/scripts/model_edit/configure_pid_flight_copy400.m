function report=configure_pid_flight_copy400()
%CONFIGURE_PID_FLIGHT_COPY400 Apply the previously compared dedicated PIDs.
% コピー済みの飛行比較モデルだけを変更する。元モデルは保存・変更しない。
root=stampfly_project_root();
model='StampFly_PIDBlock_FlightTest400';
assert(bdIsLoaded(model));
gains=load(fullfile(root,'tests','pid_comparison_metadata.mat'),'result').result.GainSets;
names=fieldnames(gains);
report=struct('Model',model,'BaselineModel','StampFly_Official_FlightTest400', ...
    'CandidateSource','archive/aircraft/PIDBlockComparison400.slx','PIDCount',0, ...
    'GainSets',gains,'StrictEquivalenceExpected',false,'Flashed',false);
for k=1:numel(names)
    wrappers=find_system(model,'LookUnderMasks','all','Name',names{k});
    assert(numel(wrappers)==1,'Expected one replacement per PID.');
    wrapper=wrappers{1};
    dedicated=find_system(wrapper,'LookUnderMasks','all','Name','DedicatedPID');
    assert(numel(dedicated)==1,'Dedicated PID was not copied.');
    gain=gains.(names{k});
    params=struct('P',literal(gain.Kp),'I',['single(1)/' literal(gain.Ti)], ...
        'D',literal(gain.Td),'N',['single(1)/(' literal(gain.Eta) '*' literal(gain.Td) ')'], ...
        'Description','飛行比較用の専用PID。Ideal形式、台形積分・微分フィルター、実測Dt、単精度。');
    reorg.edit(model,reorg.id(get_param(dedicated{1},'Parent')), ...
        {reorg.configure(reorg.id(dedicated{1}),params)});
    parent=get_param(wrapper,'Parent');
    reorg.edit(model,reorg.id(parent),{reorg.configure(reorg.id(wrapper), ...
        struct('Description',sprintf(['専用PIDの飛行比較版：%s。Enable停止中は出力・状態を保持。' ...
        'Resetは実行中に反映。PreviousError入力は未使用。元PIDとは厳密等価ではない。'],names{k})))});
    report.PIDCount=report.PIDCount+1;
    report.PIDPaths.(names{k})=dedicated{1};
end
assert(report.PIDCount==7);
reorg.edit(model,'root',{reorg.configure(['config:' model],struct( ...
    'Description',['専用PIDブロックの実飛行比較用モデル。元モデルをコピーし7個のPIDだけ置換。' ...
    '制御400Hz・PWM150kHz指定/8bitを維持。元版との厳密等価性は要求しない。']))});
disp(model_check(model,'root','["all"]'));
save_system(model,stampfly_model_file(model));
save(fullfile(root,'tests','pid_flight_model_setup.mat'),'report');
fid=fopen(fullfile(root,'docs','history','pid_flight_model_setup.json'),'w','n','UTF-8');assert(fid>=0);
closer=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
fprintf('PID_FLIGHT_COPY_READY: %d dedicated PID blocks\n',report.PIDCount);
end
function value=literal(number)
value=sprintf('single(%.17g)',double(number));
end
