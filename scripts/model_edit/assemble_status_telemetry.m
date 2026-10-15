function assemble_status_telemetry()
%ASSEMBLE_STATUS_TELEMETRY Keep display choices and telemetry mapping in model.
root=stampfly_project_root();init_official;m='StampFly_Official_Bench400';
ops={add('Chart','StatusIndicators400','status',struct),add('MATLABSystem','UserButton400','button',struct('System','official.UserButton400')), ...
 add('MATLABSystem','StatusWrite400','write',struct('System','official.StatusWrite400')),add('Chart','OfficialTelemetryValues','values',struct), ...
 add('Selector','LowVoltageCount','low',struct('NumberOfDimensions','1','IndexMode','One-based','IndexOptionArray',{{'Index vector (dialog)'}},'Indices','3','InputPortWidth','3')), ...
 add('Selector','ControlMode','control',struct('NumberOfDimensions','1','IndexMode','One-based','IndexOptionArray',{{'Index vector (dialog)'}},'InputPortWidth','6','Indices','5')), ...
 add('Constant','OfficialHeaderGains20','gains',struct('Value','single([.65;.7;.01;.125;.95;.7;.025;.125;3;.8;.01;.125;5;4;.04;.125;5;4;.04;.125])')), ...
 struct('op','configure','target','blk_35','params',struct('System','official.RadioTelemetryWrite40'))};
x=edit(m,'root',ops);
populate(m,x.status,{'mode','uint8';'controlMode','single';'altFlag','uint8';'flipFlag','uint8';'lowVoltage','uint8';'rcError','uint8';'ahrsFlag','uint8';'button','uint8'}, ...
 {'color1','uint32';'color2','uint32';'tone','uint32';'restart','boolean'},fullfile(root,'code','model_algorithms','StatusIndicators.m'));
populate(m,x.values,{'t','single';'dt','single';'a','single';'r','single';'cd','single';'accel','single';'voltage','single';'duty','single';'z','single';'sd','single';'v','single'},{'values','single'},fullfile(root,'code','model_algorithms','TelemetryValues.m'));
ops={wire('blk_38.y9',[x.low '.u1']),wire('blk_9.y1',[x.control '.u1']),wire('blk_38.y12',[x.status '.u1']),wire([x.control '.y1'],[x.status '.u2']), ...
 wire('blk_38.y13',[x.status '.u3']),wire('blk_38.y15',[x.status '.u4']),wire([x.low '.y1'],[x.status '.u5']),wire('blk_9.y7',[x.status '.u6']),wire('blk_9.y4',[x.status '.u7']),wire([x.button '.y1'],[x.status '.u8'])};
for k=1:4,ops{end+1}=wire([x.status '.y' num2str(k)],[x.write '.u' num2str(k)]);end
src={'blk_13.y1','blk_4.y2','blk_38.y4','blk_38.y5','blk_38.y10','blk_5.y1','blk_8.y1','blk_38.y1','blk_38.y6','blk_38.y11','blk_38.y7'};
for k=1:11,ops{end+1}=wire(src{k},[x.values '.u' num2str(k)]);end
ops=[ops,{wire([x.values '.y1'],'blk_35.u1'),wire([x.gains '.y1'],'blk_35.u2'),wire('blk_38.y13','blk_35.u3'),wire('blk_38.y3','blk_35.u4'),wire('blk_7.y3','blk_35.u5')}];
edit(m,'root',ops);model_check(m,'root','["all"]');save_system(m);save(fullfile(root,'tests','status_telemetry_ids.mat'),'x');
end
function populate(m,id,ins,outs,file)
ops={};for k=1:size(ins,1),ops{end+1}=add('Data',ins{k,1},['i' num2str(k)],struct('Scope','Input','DataType',ins{k,2}));end
for k=1:size(outs,1),ops{end+1}=add('Data',outs{k,1},['o' num2str(k)],struct('Scope','Output','DataType',outs{k,2}));end
script=fileread(file);names=[ins(:,1);outs(:,1)];for k=1:numel(names),script=regexprep(script,['\<' names{k} '\>'],['arg_' names{k}]);end
ops=[ops,{struct('op','add_block','type','EMFunction','ref','fn','params',struct('Script',script)),add('State','Calculate','run',struct('LabelString',['Calculate' newline 'en,du: [' strjoin(outs(:,1),',') ']=stepFn(' strjoin(ins(:,1),',') ');'])),struct('op','connect','target','? -> #run')}];
edit(m,id,ops);model_check(m,id,'["stateflow_lint"]');
end
function ids=edit(m,scope,ops)
model_read(m,scope,'0');r=char(model_edit(m,scope,jsonencode(ops),'incremental'));
if ~startsWith(strtrim(r),'status: ok'),model_read(m,scope,'0');model_check(m,scope,'["all"]');error('official:EditFailed','%s',r);end
t=regexp(r,'(?m)^\s+(\w+): (blk_\d+)\s*$','tokens');ids=struct;for k=1:numel(t),ids.(t{k}{1})=t{k}{2};end
end
function op=add(type,name,ref,params),op=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
