function fix_full_replay_edges()
%FIX_FULL_REPLAY_EDGES Official holds last outputs on the final Flip tick.
init_official;m='StampFly_Official_Bench400';
% PID globals stay unchanged if their update function is not called.
for sid=[194 239 284 329 374 419]
 id=['blk_' num2str(sid)];r=char(model_read(m,id,'0'));
 output=idByName(r,'Select_output');mem=idByName(r,'YMemory');
 disp(model_edit(m,id,jsonencode({wire([mem '.y1'],[output '.u3'])}),'incremental'));model_check(m,id,'["all"]');
end
r=char(model_read(m,'blk_92','0'));done=idByName(r,'FlipDone');
% Standard mixer retains applied duty only on the Flip completion cycle.
r=char(model_read(m,'blk_465','0'));runout=idByName(r,'ZeroWhenInactive');stop=idByName(r,'OverGStop');zero=idByName(r,'Zero4');
ops={add('Inport','HoldApplied','hold',struct('Port','10')), ...
 add('UnitDelay','AppliedDutyMemory','memory',struct('SampleTime','Official.Step','InitialCondition','zeros(4,1,''single'')')), ...
 add('Switch','HoldCompletionDuty','choose',struct('Criteria','u2 ~= 0')),wire([stop '.y1'],'#memory.u1'),wire('#memory.y1','#choose.u1'),wire('#hold.y1','#choose.u2'),wire([zero '.y1'],'#choose.u3'),wire('#choose.y1',[runout '.u3'])};
model_edit(m,'blk_465',jsonencode(ops),'incremental');model_check(m,'blk_465','["all"]');
model_read(m,'blk_92','0');model_edit(m,'blk_92',jsonencode({wire([done '.y1'],'blk_465.u10')}),'incremental');model_check(m,'blk_92','["all"]');
refresh_model_functions;
end
function id=idByName(r,name)
t=regexp(r,['- id: (blk_\d+)\s+(?:#\w+\s+)?Name: ' name '\s'],'tokens','once');assert(~isempty(t),name);id=t{1};
end
function op=add(type,name,ref,params),op=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
