function specify_sensor_signals()
%SPECIFY_SENSOR_SIGNALS Break circular dimension inference with explicit sizes.
init_official;m='StampFly_Official_Bench400';scope='blk_72';model_read(m,scope,'0');
specs={117,[3 3],{'single','single'};118,[4 1],{'single','uint16'};119,[3 3 1],{'single','single','single'};120,[3 4],{'single','single'};121,1,{'single'};122,[1 1],{'single','int16'};123,[1 1 1],{'single','single','single'};124,3,{'uint8'};125,8,{'single'}};
ops={};
for k=1:size(specs,1)
 sid=specs{k,1};p=Simulink.ID.getFullName([m ':' num2str(sid)]);ph=get_param(p,'PortHandles');
 for j=1:numel(specs{k,2})
  ref=['spec' num2str(sid) '_' num2str(j)];dims=specs{k,2};types=specs{k,3};
  line=get_param(ph.Outport(j),'Line');dest=get_param(line,'DstPortHandle');
  ops{end+1}=struct('op','add_block','type','SignalSpecification','name',ref,'ref',ref,'params',struct('Dimensions',num2str(dims(j)),'OutDataTypeStr',types{j}));
  ops{end+1}=wire(['blk_' num2str(sid) '.y' num2str(j)],['#' ref '.u1']);
  for port=dest(:)'
   dp=get_param(port,'Parent');dsid=Simulink.ID.getSID(dp);dsid=extractAfter(dsid,':');number=get_param(port,'PortNumber');
   ops{end+1}=wire(['#' ref '.y1'],['blk_' dsid '.u' num2str(number)]);
  end
 end
end
disp(model_edit(m,scope,jsonencode(ops),'incremental'));model_check(m,scope,'["all"]');save_system(m);
end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
