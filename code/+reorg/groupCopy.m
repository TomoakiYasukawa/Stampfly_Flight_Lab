function result=groupCopy(model,sourceScope,destinationScope,selected,groupName,inputGroups,outputGroups,destinationModel)
%GROUPCOPY Copy a functional group through SATK, bundling interfaces in buses.
% inputGroups/outputGroups contain .Name and .Members (.Endpoint,.Name).
if nargin<8,destinationModel=model;end
sourceParent=parentPath(model,sourceScope);model_read(model,sourceScope,'0');
links=readLinks(sourceParent);
inputNames={inputGroups.Name};outputNames={outputGroups.Name};
reply=reorg.edit(destinationModel,destinationScope,{struct('op','create_subsystem','name',groupName,'ref','group', ...
    'interface',struct('inputs',{inputNames},'outputs',{outputNames}))});
group=reorg.created(reply,'group');[inports,outports]=reorg.ports(destinationModel,group);
operations={};
for k=1:numel(selected)
    blockName=get_param(reorg.path(model,selected{k}),'Name');
    if ismember(blockName,[inputNames outputNames]),blockName=[blockName 'Internal'];end
    operations{end+1}=reorg.add(reorg.path(model,selected{k}),blockName,['block' num2str(k)]);
end
for k=1:numel(inputGroups)
    members=inputGroups(k).Members;
    if numel(members)>1
        operations{end+1}=reorg.add('BusSelector',[inputGroups(k).Name 'Fields'],['input' num2str(k)], ...
            struct('OutputSignals',strjoin({members.Name},',')));
        operations{end+1}=reorg.wire([inports{k} '.y1'],sprintf('#input%d.u1',k));
    end
end
for k=1:numel(outputGroups)
    members=outputGroups(k).Members;
    if numel(members)>1
        operations{end+1}=reorg.add('BusCreator',[outputGroups(k).Name 'Bus'],['output' num2str(k)], ...
            struct('Inputs',num2str(numel(members))));
        operations{end+1}=reorg.wire(sprintf('#output%d.y1',k),[outports{k} '.u1'],outputGroups(k).Name);
    end
end
for k=1:numel(links)
    link=links(k);dstIndex=find(strcmp(link.Dst,selected),1);
    if isempty(dstIndex),continue;end
    srcIndex=find(strcmp(link.Src,selected),1);
    if ~isempty(srcIndex),source=sprintf('#block%d.y%d',srcIndex,link.SrcPort);
    else
        endpoint=sprintf('%s.y%d',link.Src,link.SrcPort);
        [g,m]=memberIndex(inputGroups,endpoint);
        assert(~isempty(g),'official:UnmappedInput','Missing %s for %s.',endpoint,groupName);
        if numel(inputGroups(g).Members)>1,source=sprintf('#input%d.y%d',g,m);else,source=[inports{g} '.y1'];end
    end
    operations{end+1}=reorg.wire(source,sprintf('#block%d.u%d',dstIndex,link.DstPort),link.Name);
end
for g=1:numel(outputGroups)
    members=outputGroups(g).Members;
    for m=1:numel(members)
        token=regexp(members(m).Endpoint,'(blk_\d+)\.y(\d+)','tokens','once');
        srcIndex=find(strcmp(token{1},selected),1);assert(~isempty(srcIndex));
        source=sprintf('#block%d.y%s',srcIndex,token{2});
        if numel(members)>1,destination=sprintf('#output%d.u%d',g,m);else,destination=[outports{g} '.u1'];end
        operations{end+1}=reorg.wire(source,destination,members(m).Name);
    end
end
reply=reorg.edit(destinationModel,group,operations,'full');
result=struct('ID',group,'Sources',{selected},'Copies',{{}},'InputGroups',inputGroups,'OutputGroups',outputGroups);
for k=1:numel(selected),result.Copies{k}=reorg.created(reply,['block' num2str(k)]);end
disp(model_check(destinationModel,group,'["all"]'));
end
function p=parentPath(model,scope)
if strcmp(scope,'root'),p=model;else,p=reorg.path(model,scope);end
end
function links=readLinks(parent)
blocks=find_system(parent,'SearchDepth',1,'Type','Block');
links=struct('Src',{},'SrcPort',{},'Dst',{},'DstPort',{},'Name',{});
for k=1:numel(blocks)
    if strcmp(blocks{k},parent),continue;end
    ports=get_param(blocks{k},'PortHandles');
    for j=1:numel(ports.Inport)
        line=get_param(ports.Inport(j),'Line');if line<0,continue;end
        source=get_param(line,'SrcPortHandle');if source<0,continue;end
        links(end+1)=struct('Src',reorg.id(get_param(source,'Parent')), ...
            'SrcPort',get_param(source,'PortNumber'),'Dst',reorg.id(blocks{k}),'DstPort',j, ...
            'Name',get_param(line,'Name')); %#ok<AGROW>
    end
end
end
function [g,m]=memberIndex(groups,endpoint)
g=[];m=[];
for k=1:numel(groups)
    found=find(strcmp({groups(k).Members.Endpoint},endpoint),1);
    if ~isempty(found),g=k;m=found;return;end
end
end
