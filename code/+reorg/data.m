function result=data(name,type,initialValue,sizeValue)
if nargin<4,sizeValue='1';end
% Shape/initial values are assigned on the chart's default transition. The
% installed SATK supports DataType but does not forward nested Props keys.
result=reorg.add('Data',name,name,struct('Name',name,'Scope','Local','DataType',type));
end
