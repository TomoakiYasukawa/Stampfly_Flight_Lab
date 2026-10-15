function result=created(reply,reference)
token=regexp(reply,[reference ': (blk_\d+|sf_[\d:]+)'],'tokens','once');
assert(~isempty(token),'official:MissingCreatedID','No created ID for %s.',reference);
result=token{1};
end
