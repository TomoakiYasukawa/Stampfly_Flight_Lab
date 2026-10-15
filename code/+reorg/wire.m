function result=wire(source,destination,name)
result=struct('op','connect','target',[source ' -> ' destination]);
if nargin>2,result.params=struct('Name',name);end
end
