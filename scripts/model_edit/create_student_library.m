function create_student_library()
%CREATE_STUDENT_LIBRARY Reusable blocks copied from the verified model.
root=stampfly_project_root();init_official;bench='StampFly_Official_Bench400';lib='StampFly_StudentBlocks';
if bdIsLoaded(lib),close_system(lib,0);end
new_system(lib,'Library');open_system(lib);model_read(lib,'root','0');
ops={};categories={'SensorInputs','Estimation','FlightSequence','Controllers','MotorOutputs','LoggingAndStatus'};
for k=1:numel(categories),ops{end+1}=struct('op','create_subsystem','name',categories{k},'ref',categories{k},'interface',struct('inputs',{{}},'outputs',{{}}));end
r=char(model_edit(lib,'root',jsonencode(ops),'full'));t=regexp(r,'(?m)^\s+(\w+): (blk_\d+)\s*$','tokens');ids=struct;for k=1:numel(t),ids.(t{k}{1})=t{k}{2};end
groups={ [633 634 635 636 677], [117 118 119 120 121 122 123 124 72], [530 531 126 553 38], [149 194 239 284 329 374 419 128 129 130 131 92],  [465 611 604], [663 664 665 699 676 678 700 640 681 666] };
for k=1:numel(categories)
 scope=ids.(categories{k});model_read(lib,scope,'0');ops={};
 for sid=groups{k}
  src=Simulink.ID.getFullName([bench ':' num2str(sid)]);name=get_param(src,'Name');
  ops{end+1}=struct('op','add_block','type',src,'name',name,'ref',['b' num2str(sid)],'params',struct('Description',get_param(src,'Description')));
 end
 r=char(model_edit(lib,scope,jsonencode(ops),'full'));if ~startsWith(strtrim(r),'status: ok'),model_read(lib,scope,'0');model_check(lib,scope,'["all"]');error('%s',r);end
end
% Category shelves intentionally contain unconnected reusable blocks.
labels={'センサー取得','姿勢・高度の推定','飛行状態と離着陸','PID と指令生成','PWM とモーター配分','記録・通信・LED'};
ops={};for k=1:numel(categories),ops{end+1}=struct('op','configure','target',ids.(categories{k}),'params',struct('Mask','on','MaskDisplay',['disp(''' labels{k} ''')'],'MaskIconOpaque','opaque','Position',[80+mod(k-1,3)*340 100+floor((k-1)/3)*190 340+mod(k-1,3)*340 210+floor((k-1)/3)*190]));end
model_edit(lib,'root',jsonencode(ops),'incremental');
save_system(lib,stampfly_model_file(lib));
end
