function mapping=replace_calculation_charts()
%REPLACE_CALCULATION_CHARTS Use MATLAB Function for non-mode calculations.
% 飛行状態を遷移させない計算処理を、機能別のMATLAB Functionへ置換。
root=stampfly_project_root();
snapshot=load(fullfile(root,'tests','model_reorganization_before.mat')).snapshot;
model=snapshot.Model;mapping=struct;
targets=[700 676 132 127 129 130 128 131];
for sid=targets
    item=snapshot.Charts([snapshot.Charts.SID]==sid);
    reply=reorg.edit(model,item.ParentSID,{reorg.add('MATLAB Function',[item.Name 'Replacement'],'replacement')});
    id=reorg.created(reply,'replacement');path=reorg.path(model,id);
    configuration=get_param(path,'MATLABFunctionConfiguration');
    % MATLAB Function本文を設定する公開API。構造作成・配線はmodel_edit。
    configuration.FunctionScript=item.Script;
    configuration.SupportVariableSizing=false;
    chart=sfroot().find('-isa','Stateflow.EMChart','Path',path);
    inputs=chart.Inputs;outputs=chart.Outputs;
    for k=1:numel(inputs),inputs(k).DataType=item.InputTypes{k};end
    for k=1:numel(outputs),outputs(k).DataType=item.OutputTypes{k};end
    operations={};
    for k=1:numel(item.Sources),operations{end+1}=reorg.wire(item.Sources{k},sprintf('%s.u%d',id,k));end
    for k=1:numel(item.Destinations)
        for j=1:numel(item.Destinations{k}),operations{end+1}=reorg.wire(sprintf('%s.y%d',id,k),item.Destinations{k}{j});end
    end
    operations{end+1}=struct('op','delete','target',['blk_' num2str(sid)]);
    operations{end+1}=reorg.configure(id,struct('Name',item.Name,'Position',item.Position, ...
        'Description',[item.Description newline '計算処理。飛行状態遷移はStateflowで管理。']));
    reorg.edit(model,item.ParentSID,operations);
    disp(model_check(model,item.ParentSID,'["all"]'));
    mapping.(item.Name)=id;
end
save(fullfile(root,'tests','calculation_replacement_ids.mat'),'mapping');save_system(model);
end
