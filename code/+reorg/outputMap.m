function result=outputMap(model,scope,id,groups)
%OUTPUTMAP Expose named bus fields for direct connections or auxiliary taps.
operations={};result=struct;
for g=1:numel(groups)
    members=groups(g).Members;
    if numel(members)>1
        reference=['fields' num2str(g)];
        operations{end+1}=reorg.add('BusSelector',[groups(g).Name 'Fields'],reference, ...
            struct('OutputSignals',strjoin({members.Name},',')));
        operations{end+1}=reorg.wire(sprintf('%s.y%d',id,g),['#' reference '.u1'],groups(g).Name);
    end
end
if ~isempty(operations),reply=reorg.edit(model,scope,operations);else,reply='';end
for g=1:numel(groups)
    members=groups(g).Members;
    if numel(members)>1,selector=reorg.created(reply,['fields' num2str(g)]);end
    for m=1:numel(members)
        if numel(members)>1,endpoint=sprintf('%s.y%d',selector,m);
        else,endpoint=sprintf('%s.y%d',id,g);end
        result.(members(m).Name)=endpoint;
        result.Groups.(groups(g).Name).(members(m).Name)=endpoint;
    end
end
end
