function replace_motor_mixer()
%REPLACE_MOTOR_MIXER Expose mixer, filtering, limits and 8-bit conversion.
init_official;model='StampFly_Official_Bench400';scope='blk_92';
open_system(model);model_read(model,scope,'0');
ops={struct('op','delete','target','blk_464'),struct('op','create_subsystem','name','MotorMixerFilter8bit','ref','mix','interface',struct('inputs',{{'Thrust','RollTorque','PitchTorque','YawTorque','Run','Reset','OverG','Mode','Dt'}},'outputs',{{'Duty4','Counts4','BeforeLimit4'}}))};
r=char(model_edit(model,scope,jsonencode(ops),'incremental'));disp(r);
t=regexp(r,'mix: (blk_\d+)','tokens','once');id=t{1};
r=char(model_read(model,id,'0'));ins=regexp(r,'(?m)- id: (blk_\d+) #u\d+','tokens');outs=regexp(r,'(?m)- id: (blk_\d+) #y\d+','tokens');
u=cellfun(@(x)x{1},ins,'UniformOutput',false);y=cellfun(@(x)x{1},outs,'UniformOutput',false);
ops={add('Constant','Zero4','zero4',struct('Value','zeros(4,1,''single'')')),add('Constant','FilterTime','T',struct('Value','single(.003)')),add('Constant','ParkingMode','park',struct('Value','uint8(3)')),add('Constant','OverGZero','gzero',struct('Value','uint8(0)')), ...
add('UnitDelay','DutyFilterMemory','mem',struct('SampleTime','Official.Step','InitialCondition','zeros(4,1,''single'')')), ...
add('RelationalOperator','IsParking','ispark',struct('Operator','==')),add('Logic','ResetFilter','reset',struct('Operator','OR','Inputs','2')),add('Switch','PreviousFilter','prev',struct('Criteria','u2 ~= 0')), ...
add('Sum','FilterDenominator','den',struct('Inputs','++')),add('Product','PreviousTimesT','prevT',struct),add('Product','PreviousTerm','prevterm',struct('Inputs','*/')),add('Product','InputTimesDt','inputdt',struct),add('Product','InputTerm','inputterm',struct('Inputs','*/')),add('Sum','FilterRecurrence','calc',struct('Inputs','++')), ...
add('Switch','HoldWhenInactive','hold',struct('Criteria','u2 ~= 0')),add('Saturate','DutyLimit','limit',struct('LowerLimit','single(0)','UpperLimit','single(.95)')),add('Switch','ZeroWhenInactive','runout',struct('Criteria','u2 ~= 0')),add('RelationalOperator','NoOverG','nog',struct('Operator','==')),add('Switch','OverGStop','stop',struct('Criteria','u2 ~= 0')), ...
add('Gain','DutyTo8bit','scale',struct('Gain','single(255)')),add('Rounding','TruncateDuty','floor',struct('Operator','floor')),add('DataTypeConversion','UInt8Counts','counts',struct('OutDataTypeStr','uint8')), ...
add('Mux','MixVector4','before',struct('Inputs','4')),add('Switch','BeforeWhenActive','beforeout',struct('Criteria','u2 ~= 0'))};
signs={'-++','++-','---','+-+'};
for k=1:4
ref=['m' num2str(k)];q=['q' num2str(k)];th=['th' num2str(k)];d=['d' num2str(k)];
ops=[ops,{add('Sum',['AxisMix' num2str(k)],ref,struct('Inputs',signs{k})),add('Gain',['QuarterTorque' num2str(k)],q,struct('Gain','single(.25)')),add('Sum',['AddThrust' num2str(k)],th,struct('Inputs','++')),add('Gain',['NormalizeDuty' num2str(k)],d,struct('Gain','1/3.7','OutDataTypeStr','single')), ...
wire([u{2} '.y1'],['#' ref '.u1']),wire([u{3} '.y1'],['#' ref '.u2']),wire([u{4} '.y1'],['#' ref '.u3']),wire(['#' ref '.y1'],['#' q '.u1']),wire([u{1} '.y1'],['#' th '.u1']),wire(['#' q '.y1'],['#' th '.u2']),wire(['#' th '.y1'],['#' d '.u1']),wire(['#' d '.y1'],['#before.u' num2str(k)])}];
end
ops=[ops,{wire([u{8} '.y1'],'#ispark.u1'),wire('#park.y1','#ispark.u2'),wire('#ispark.y1','#reset.u1'),wire([u{6} '.y1'],'#reset.u2'),wire('#zero4.y1','#prev.u1'),wire('#reset.y1','#prev.u2'),wire('#mem.y1','#prev.u3'), ...
wire('#T.y1','#den.u1'),wire([u{9} '.y1'],'#den.u2'),wire('#prev.y1','#prevT.u1'),wire('#T.y1','#prevT.u2'),wire('#prevT.y1','#prevterm.u1'),wire('#den.y1','#prevterm.u2'),wire('#before.y1','#inputdt.u1'),wire([u{9} '.y1'],'#inputdt.u2'),wire('#inputdt.y1','#inputterm.u1'),wire('#den.y1','#inputterm.u2'),wire('#prevterm.y1','#calc.u1'),wire('#inputterm.y1','#calc.u2'), ...
wire('#calc.y1','#hold.u1'),wire([u{5} '.y1'],'#hold.u2'),wire('#prev.y1','#hold.u3'),wire('#hold.y1','#mem.u1'),wire('#calc.y1','#limit.u1'),wire('#limit.y1','#runout.u1'),wire([u{5} '.y1'],'#runout.u2'),wire('#zero4.y1','#runout.u3'),wire([u{7} '.y1'],'#nog.u1'),wire('#gzero.y1','#nog.u2'),wire('#runout.y1','#stop.u1'),wire('#nog.y1','#stop.u2'),wire('#zero4.y1','#stop.u3'), ...
wire('#stop.y1','#scale.u1'),wire('#scale.y1','#floor.u1'),wire('#floor.y1','#counts.u1'),wire('#stop.y1',[y{1} '.u1']),wire('#counts.y1',[y{2} '.u1']),wire('#before.y1','#beforeout.u1'),wire([u{5} '.y1'],'#beforeout.u2'),wire('#zero4.y1','#beforeout.u3'),wire('#beforeout.y1',[y{3} '.u1'])}];
disp(model_edit(model,id,jsonencode(ops),'full'));model_check(model,id,'["all"]');
src={'blk_131.y1','blk_329.y1','blk_374.y1','blk_419.y1','blk_127.y2','blk_127.y3','blk_102.y1','blk_103.y1','blk_104.y1'};
ops={};for k=1:9,ops{end+1}=wire(src{k},[id '.u' num2str(k)]);end
ops=[ops,{wire([id '.y1'],'blk_105.u1'),wire([id '.y2'],'blk_106.u1'),wire([id '.y3'],'blk_132.u11')}];
disp(model_edit(model,scope,jsonencode(ops),'incremental'));model_check(model,scope,'["all"]');save_system(model);
end
function op=add(type,name,ref,params),op=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
