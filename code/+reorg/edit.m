function reply = edit(model,scope,operations,layoutMode)
%EDIT Apply scoped edits through the installed Simulink Agentic Toolkit.
if nargin<4,layoutMode='incremental';end
ensure_simulink_toolkit();
model_read(model,scope,'0');
reply=char(model_edit(model,scope,jsonencode(operations),layoutMode));
fprintf('%s\n',reply);
if ~startsWith(strtrim(reply),'status: ok')
    disp(model_read(model,scope,'0'));
    disp(model_check(model,scope,'["all"]'));
    error('official:ModelReorganization','%s',reply);
end
if startsWith(scope,'sf_') || reorg.isChartScope(model,scope)
    validationScope=scope;
    if startsWith(scope,'sf_'),token=regexp(scope,'sf_(\d+)','tokens','once');validationScope=['blk_' token{1}];end
    disp(model_check(model,validationScope,'["stateflow_lint"]'));
end
end
