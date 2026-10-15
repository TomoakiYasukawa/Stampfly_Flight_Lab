function chart=chartInterface(model,id,description)
%CHARTINTERFACE Remove the function wrapper while retaining chart I/O.
model_read(model,id,'0');
chart=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(model,id));
children=chart.getChildren;
operations={};
% Delete transitions first: deleting a state also removes its attached arrows.
children=[children(arrayfun(@(x)isa(x,'Stateflow.Transition'),children)); ...
    children(~arrayfun(@(x)isa(x,'Stateflow.Transition'),children))];
for k=1:numel(children)
    child=children(k);
    if isa(child,'Stateflow.Data') && ismember(child.Scope,{'Input','Output'}),continue;end
    operations{end+1}=struct('op','delete','target',sprintf('sf_%s:%d',extractAfter(id,'blk_'),child.SSIdNumber)); %#ok<AGROW>
end
operations{end+1}=reorg.configure(['chart:' model],struct('ActionLanguage','MATLAB', ...
    'Decomposition','PARALLEL_AND','Description',description,'ExecuteAtInitialization',false));
reorg.edit(model,id,operations,'full');
chart=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(model,id));
end
