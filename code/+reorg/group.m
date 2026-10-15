function result=group(name,endpoints,names)
result=struct('Name',name,'Members',reorg.members(endpoints,names));
end
