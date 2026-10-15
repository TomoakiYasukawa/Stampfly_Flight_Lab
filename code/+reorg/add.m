function result=add(type,name,ref,params)
if nargin<4,params=struct;end
result=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);
end
