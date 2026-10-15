function result=wrap(model,scope,selected,name,inputGroups,outputGroups)
%WRAP Copy a group, reconnect its consumers, then remove the originals.
links=reorg.links(model,scope);
result=reorg.groupCopy(model,scope,scope,selected,name,inputGroups,outputGroups);
fields=reorg.outputMap(model,scope,result.ID,outputGroups);operations={};
for k=1:numel(inputGroups)
    assert(numel(inputGroups(k).Members)==1,'This wrapper expects scalar or bus input groups.');
    operations{end+1}=reorg.wire(inputGroups(k).Members.Endpoint,sprintf('%s.u%d',result.ID,k),inputGroups(k).Name);
end
for g=1:numel(outputGroups)
    members=outputGroups(g).Members;
    for m=1:numel(members)
        token=regexp(members(m).Endpoint,'(blk_\d+)\.y(\d+)','tokens','once');
        outgoing=links(strcmp({links.Src},token{1})&[links.SrcPort]==str2double(token{2})&~ismember({links.Dst},selected));
        endpoint=fields.Groups.(outputGroups(g).Name).(members(m).Name);
        for j=1:numel(outgoing)
            operations{end+1}=reorg.wire(endpoint,sprintf('%s.u%d',outgoing(j).Dst,outgoing(j).DstPort),members(m).Name);
        end
    end
end
for k=1:numel(selected),operations{end+1}=struct('op','delete','target',selected{k});end
reorg.edit(model,scope,operations);result.Fields=fields;
end
