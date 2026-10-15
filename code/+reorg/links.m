function result=links(model,scope)
%LINKS Read direct connections at one level, retaining explicit signal names.
if strcmp(scope,'root'),parent=model;else,parent=reorg.path(model,scope);end
blocks=find_system(parent,'SearchDepth',1,'Type','Block');
result=struct('Src',{},'SrcPort',{},'Dst',{},'DstPort',{},'Name',{});
for k=1:numel(blocks)
    if strcmp(blocks{k},parent),continue;end
    ports=get_param(blocks{k},'PortHandles');
    for j=1:numel(ports.Inport)
        line=get_param(ports.Inport(j),'Line');if line<0,continue;end
        source=get_param(line,'SrcPortHandle');if source<0,continue;end
        result(end+1)=struct('Src',reorg.id(get_param(source,'Parent')), ...
            'SrcPort',get_param(source,'PortNumber'),'Dst',reorg.id(blocks{k}), ...
            'DstPort',j,'Name',get_param(line,'Name')); %#ok<AGROW>
    end
end
end
