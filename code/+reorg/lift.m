function result=lift(model,scope)
%LIFT Copy a subsystem's direct children into its parent, preserving timing.
path=reorg.path(model,scope);parent=get_param(path,'Parent');
if strcmp(parent,model),parentScope='root';else,parentScope=reorg.id(parent);end
model_read(model,scope,'0');model_read(model,parentScope,'0');
links=reorg.links(model,scope);parentLinks=reorg.links(model,parentScope);
% SATK resolves same-model types relative to the destination root. Use an
% independent saved copy to provide an unambiguous block source.
copyModel='ReorganizationCopySource';
copyFile=fullfile(stampfly_project_root(),'tests',[copyModel '.slx']);
if bdIsLoaded(copyModel),close_system(copyModel,0);end
save_system(model);copyfile(get_param(model,'FileName'),copyFile);open_system(copyFile);
copyCleanup=onCleanup(@()close_system(copyModel,0)); %#ok<NASGU>
[inputs,outputs]=reorg.ports(model,scope);
blocks=find_system(path,'SearchDepth',1,'Type','Block');selected={};
for k=1:numel(blocks)
    if strcmp(blocks{k},path),continue;end
    if ismember(get_param(blocks{k},'BlockType'),{'Inport','Outport'}) || ...
            ismember(get_param(blocks{k},'Name'),{'ModelExplanation','JapaneseExplanation'}),continue;end
    selected{end+1}=reorg.id(blocks{k}); %#ok<AGROW>
end
operations={};
for k=1:numel(selected)
    operations{end+1}=reorg.add(reorg.path(copyModel,selected{k}),get_param(reorg.path(model,selected{k}),'Name'),['copy' num2str(k)]);
end
for k=1:numel(links)
    link=links(k);dstIndex=find(strcmp(link.Dst,selected),1);if isempty(dstIndex),continue;end
    source=sourceEndpoint(link.Src,link.SrcPort);
    operations{end+1}=wire(source,sprintf('#copy%d.u%d',dstIndex,link.DstPort),link.Name);
end
for k=1:numel(outputs)
    inside=links(strcmp({links.Dst},outputs{k}));assert(numel(inside)==1);
    source=sourceEndpoint(inside.Src,inside.SrcPort);
    outside=parentLinks(strcmp({parentLinks.Src},scope)&[parentLinks.SrcPort]==k);
    for j=1:numel(outside)
        operations{end+1}=wire(source,sprintf('%s.u%d',outside(j).Dst,outside(j).DstPort),inside.Name);
    end
end
operations{end+1}=struct('op','delete','target',scope);
reply=reorg.edit(model,parentScope,operations);
result=struct('Sources',{selected},'Copies',{{}});
for k=1:numel(selected),result.Copies{k}=reorg.created(reply,['copy' num2str(k)]);end
    function endpoint=sourceEndpoint(source,port)
        index=find(strcmp(source,selected),1);
        if ~isempty(index),endpoint=sprintf('#copy%d.y%d',index,port);return;end
        inputIndex=find(strcmp(source,inputs),1);assert(~isempty(inputIndex));
        boundary=parentLinks(strcmp({parentLinks.Dst},scope)&[parentLinks.DstPort]==inputIndex);
        assert(numel(boundary)==1);endpoint=sprintf('%s.y%d',boundary.Src,boundary.SrcPort);
    end
end
function operation=wire(source,destination,name)
if isempty(name)||startsWith(name,'<'),operation=reorg.wire(source,destination);else,operation=reorg.wire(source,destination,name);end
end
