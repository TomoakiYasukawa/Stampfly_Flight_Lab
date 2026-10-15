function sync_official_examples()
%SYNC_OFFICIAL_EXAMPLES Keep the synthetic sensor sequence on current blocks.
init_official;m='StampFly_Official_FlightSim400';model_read(m,'root','0');
target=find_system(m,'SearchDepth',1,'BlockType','SubSystem','Name','OfficialTakeoffHover400');
id=['blk_' extractAfter(Simulink.ID.getSID(target{1}),':')];
if numel(get_param(target{1},'PortHandles').Inport)==10
 r=char(model_edit(m,'root',jsonencode({struct('op','replace_block','target',id,'type',Simulink.ID.getFullName('StampFly_Official_Bench400:38'))}),'incremental'));
 assert(startsWith(strtrim(r),'status: ok'),'%s',r);model_read(m,'root','0');
 target=find_system(m,'SearchDepth',1,'BlockType','SubSystem','Name','OfficialTakeoffHover400');id=['blk_' extractAfter(Simulink.ID.getSID(target{1}),':')];
end
if isempty(find_system(m,'SearchDepth',1,'Name','NoFlipButton'))
ops={ ...
 struct('op','add_block','type','Constant','name','NoFlipButton','ref','zero','params',struct('Value','uint8(0)')), ...
 struct('op','connect','target',['#zero.y1 -> ' id '.u11'])};
for k=13:15,ops{end+1}=struct('op','add_block','type','Outport','name',sprintf('OfficialFlag%d',k),'ref',['o' num2str(k)],'params',struct('Port',num2str(k)));ops{end+1}=struct('op','connect','target',sprintf('%s.y%d -> #o%d.u1',id,k,k));end
r=char(model_edit(m,'root',jsonencode(ops),'incremental'));assert(startsWith(strtrim(r),'status: ok'),'%s',r);
end
model_check(m,'root','["all"]');save_system(m);
out=sim(m);result=struct('FinalMode',out.yout{2}.Values.Data(end),'FinalHeightTarget',out.yout{8}.Values.Data(end,1),'FinalTakeoffCounter',out.yout{8}.Values.Data(end,3));
assert(result.FinalMode==2 && result.FinalTakeoffCounter==1000 && abs(result.FinalHeightTarget-.5)<1e-6);
save(fullfile(stampfly_project_root(),'tests','flight_sequence_verification.mat'),'result');disp(result);
% Early PID-only replay predates the complete interface. Retain as archive.
old='StampFly_Official_Replay400';if bdIsLoaded(old),close_system(old,0);end
root=stampfly_project_root();source=stampfly_model_file(old);
if isfile(source),movefile(source,fullfile(root,'archive',[old '.slx']));end
end
