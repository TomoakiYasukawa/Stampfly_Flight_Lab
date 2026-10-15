function tf=isChartScope(model,scope)
tf=false;
if ~startsWith(scope,'blk_'),return;end
path=reorg.path(model,scope);
tf=~isempty(sfroot().find('-isa','Stateflow.Chart','Path',path));
end
