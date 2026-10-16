function [inputs,outputs]=ports(model,id)
path=reorg.path(model,id);
inputs=find_system(path,'SearchDepth',1,'LookUnderMasks','all','BlockType','Inport');
outputs=find_system(path,'SearchDepth',1,'LookUnderMasks','all','BlockType','Outport');
[~,order]=sort(cellfun(@(p)str2double(get_param(p,'Port')),inputs));
inputs=cellfun(@reorg.id,inputs(order),'UniformOutput',false);
[~,order]=sort(cellfun(@(p)str2double(get_param(p,'Port')),outputs));
outputs=cellfun(@reorg.id,outputs(order),'UniformOutput',false);
end
