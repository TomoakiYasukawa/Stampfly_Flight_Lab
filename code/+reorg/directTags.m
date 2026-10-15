function count=directTags(model,scope,recursive)
%DIRECTTAGS Replace local Goto/From pairs with real signal connections.
if nargin<3,recursive=false;end
if strcmp(scope,'root'),parent=model;else,parent=reorg.path(model,scope);end
model_read(model,scope,'0');
gotos=find_system(parent,'SearchDepth',1,'BlockType','Goto');
froms=find_system(parent,'SearchDepth',1,'BlockType','From');
operations={};count=0;
for k=1:numel(gotos)
    tag=get_param(gotos{k},'GotoTag');
    indices=find(cellfun(@(p)strcmp(get_param(p,'GotoTag'),tag),froms));
    gp=get_param(gotos{k},'PortHandles');gl=get_param(gp.Inport,'Line');
    assert(gl>0,'Dangling Goto input.');source=get_param(gl,'SrcPortHandle');
    src=sprintf('%s.y%d',reorg.id(get_param(source,'Parent')),get_param(source,'PortNumber'));
    for f=indices'
        fp=get_param(froms{f},'PortHandles');line=get_param(fp.Outport,'Line');
        if line>0
            destinations=get_param(line,'DstPortHandle');
            for d=destinations'
                dst=sprintf('%s.u%d',reorg.id(get_param(d,'Parent')),get_param(d,'PortNumber'));
                operations{end+1}=reorg.wire(src,dst); %#ok<AGROW>
            end
        end
        operations{end+1}=struct('op','delete','target',reorg.id(froms{f}));
        count=count+1;
    end
    operations{end+1}=struct('op','delete','target',reorg.id(gotos{k}));count=count+1;
end
if ~isempty(operations),reorg.edit(model,scope,operations);end
if recursive
    blocks=find_system(parent,'SearchDepth',1,'BlockType','SubSystem');
    for k=1:numel(blocks)
        if strcmp(blocks{k},parent) || ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',blocks{k})) || ...
                ~isempty(sfroot().find('-isa','Stateflow.EMChart','Path',blocks{k})),continue;end
        count=count+reorg.directTags(model,reorg.id(blocks{k}),true);
    end
end
disp(model_check(model,scope,'["all"]'));
end
