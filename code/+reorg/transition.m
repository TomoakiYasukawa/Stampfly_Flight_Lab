function result=transition(source,destination,label,order,reference)
if nargin<4,order=1;end
result=struct('op','connect','target',[source ' -> ' destination], ...
    'params',struct('LabelString',label,'ExecutionOrder',order));
if nargin>4,result.ref=reference;end
end
