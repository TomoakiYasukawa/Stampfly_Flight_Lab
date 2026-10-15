function result=path(model,id)
%PATH Resolve a real block path from its SID; never rebuild paths from names.
result=Simulink.ID.getFullName([model ':' extractAfter(id,'blk_')]);
end
