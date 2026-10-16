function newId=encapsulate_blocks(model,sids,name,description)
%ENCAPSULATE_BLOCKS Copy and wire a group using the official model_edit API.
% Preserve all crossing signals and original block parameters.
model_read(model,'root','0');selected=arrayfun(@(s)Simulink.ID.getFullName([model ':' num2str(s)]),sids,'UniformOutput',false);
links=struct('src',{},'port',{},'dst',{},'input',{});
allBlocks=find_system(model,'SearchDepth',1,'Type','Block');
for k=1:numel(allBlocks)
 handles=get_param(allBlocks{k},'PortHandles');
 for j=1:numel(handles.Inport)
  line=get_param(handles.Inport(j),'Line');if line<0,continue;end
  source=get_param(line,'SrcPortHandle');if source<0,continue;end
  links(end+1)=struct('src',get_param(source,'Parent'),'port',get_param(source,'PortNumber'), ...
   'dst',allBlocks{k},'input',j); %#ok<AGROW>
 end
end
incoming=struct('src',{},'port',{});outgoing=incoming;
for k=1:numel(links)
 e=links(k);si=ismember(e.src,selected);di=ismember(e.dst,selected);
 if ~si && di,incoming=uniquePort(incoming,e.src,e.port);end
 if si && ~di,outgoing=uniquePort(outgoing,e.src,e.port);end
end
inNames=arrayfun(@(k)sprintf('Input%02d',k),1:numel(incoming),'UniformOutput',false);
outNames=arrayfun(@(k)sprintf('Output%02d',k),1:numel(outgoing),'UniformOutput',false);
reply=char(model_edit(model,'root',jsonencode({struct('op','create_subsystem','name',name,'ref','group', ...
 'interface',struct('inputs',{inNames},'outputs',{outNames}))}),'incremental'));
checkReply(reply);id=regexp(reply,'group: (blk_\d+)','tokens','once');newId=id{1};
model_read(model,newId,'0');group=Simulink.ID.getFullName([model ':' extractAfter(newId,'blk_')]);
ops={};
for k=1:numel(selected)
 ops{end+1}=struct('op','add_block','type',selected{k},'name',get_param(selected{k},'Name'),'ref',['copy' num2str(k)]);
end
reply=char(model_edit(model,newId,jsonencode(ops),'incremental'));checkReply(reply);
copied=cell(size(selected));for k=1:numel(selected),x=regexp(reply,['copy' num2str(k) ': (blk_\d+)'],'tokens','once');copied{k}=x{1};end
inports=find_system(group,'SearchDepth',1,'BlockType','Inport');outports=find_system(group,'SearchDepth',1,'BlockType','Outport');
inIds=cell(1,numel(incoming));outIds=cell(1,numel(outgoing));
for k=1:numel(inports),p=str2double(get_param(inports{k},'Port'));inIds{p}=blockId(inports{k});end
for k=1:numel(outports),p=str2double(get_param(outports{k},'Port'));outIds{p}=blockId(outports{k});end
ops={};
for k=1:numel(links)
 e=links(k);si=find(strcmp(e.src,selected),1);di=find(strcmp(e.dst,selected),1);
 if ~isempty(di)
  dst=sprintf('%s.u%d',copied{di},e.input);
  if ~isempty(si),src=sprintf('%s.y%d',copied{si},e.port);
  else,p=portIndex(incoming,e.src,e.port);src=[inIds{p} '.y1'];end
  ops{end+1}=wire(src,dst);
 end
end
for k=1:numel(outgoing)
 si=find(strcmp(outgoing(k).src,selected),1);ops{end+1}=wire(sprintf('%s.y%d',copied{si},outgoing(k).port),[outIds{k} '.u1']);
end
reply=char(model_edit(model,newId,jsonencode(ops),'incremental'));checkReply(reply);
model_read(model,newId,'0');model_check(model,newId,'["all"]');
ops={struct('op','configure','target',newId,'params',struct('Description',description,'AttributesFormatString',description))};
for k=1:numel(incoming),ops{end+1}=wire(sprintf('%s.y%d',blockId(incoming(k).src),incoming(k).port),sprintf('%s.u%d',newId,k));end
for k=1:numel(links)
 e=links(k);if ismember(e.src,selected) && ~ismember(e.dst,selected)
  p=portIndex(outgoing,e.src,e.port);ops{end+1}=wire(sprintf('%s.y%d',newId,p),sprintf('%s.u%d',blockId(e.dst),e.input));
 end
end
for k=1:numel(selected),ops{end+1}=struct('op','delete','target',blockId(selected{k}));end
reply=char(model_edit(model,'root',jsonencode(ops),'incremental'));checkReply(reply);
model_read(model,'root','0');model_check(model,'root','["all"]');save_system(model);
end
function result=uniquePort(result,src,port)
if isempty(portIndex(result,src,port)),result(end+1)=struct('src',src,'port',port);end
end
function k=portIndex(list,src,port)
k=find(arrayfun(@(x)strcmp(x.src,src)&&x.port==port,list),1);
end
function id=blockId(path),id=['blk_' extractAfter(Simulink.ID.getSID(path),':')];end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
function checkReply(reply)
assert(startsWith(strtrim(reply),'status: ok'),'official:EncapsulationFailed','%s',reply);
end
