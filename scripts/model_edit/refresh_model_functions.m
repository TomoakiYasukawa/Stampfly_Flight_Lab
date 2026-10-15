function refresh_model_functions()
%REFRESH_MODEL_FUNCTIONS Update embedded algorithms and synchronize replay.
root=stampfly_project_root();m='StampFly_Official_Bench400';init_official;
items={128,'StickToAngleRate.m';127,'ControlEnableReset.m';126,'TakeoffLandingCommand.m';131,'ThrustCorrectionLimits.m';531,'FlipSequence.m'};
for k=1:size(items,1)
 sid=items{k,1};id=['blk_' num2str(sid)];r=char(model_read(m,id,'0'));
 fn=regexp(r,'MLFunction:.*?- id: "([^"]+)"','tokens','once');
 rt=sfroot;ch=rt.find('-isa','Stateflow.Chart','Path',Simulink.ID.getFullName([m ':' num2str(sid)]));
 d=ch.find('-isa','Stateflow.Data');names={d.Name};
 script=fileread(fullfile(root,'code','model_algorithms',items{k,2}));
 for j=1:numel(names),script=regexprep(script,['\<' names{j} '\>'],['arg_' names{j}]);end
 disp(model_edit(m,id,jsonencode({struct('op','configure','target',fn{1},'params',struct('Script',script))}),'incremental'));
 model_check(m,id,'["stateflow_lint"]');
end
replay='StampFly_Official_FullReplay400';model_read(replay,'root','0');
lm=layout.LayoutStateManager.instance();lm.reset();
paths={[replay '/FlipSequence'],[replay '/FlightControl']};source=[531 92];ops={};
for k=1:2
 target=['blk_' extractAfter(Simulink.ID.getSID(paths{k}),':')];
 ops{end+1}=struct('op','replace_block','target',target,'type',Simulink.ID.getFullName([m ':' num2str(source(k))]));
end
reply=char(model_edit(replay,'root',jsonencode(ops),'incremental'));disp(reply);
assert(startsWith(strtrim(reply),'status: ok') || contains(reply,'status: ok'),'official:ReplaySync','%s',reply);
model_check(replay,'root','["all"]');save_system(m);save_system(replay);
end
