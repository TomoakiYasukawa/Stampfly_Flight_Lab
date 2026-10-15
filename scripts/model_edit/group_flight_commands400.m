function report=group_flight_commands400()
%GROUP_FLIGHT_COMMANDS400 Expose a clean flight-command/control pipeline.
% モード遷移と離着陸指令をまとめ、各制御ループは独立ブロックとして残す。
m='StampFly_Official_FlightTest400';scope='blk_2297';
selected=arrayfun(@(x)sprintf('blk_%d',x),[2606 2364 3758 3418 3772 3818 3786 3820 3821 2705 3775], ...
    'UniformOutput',false);
inputGroups=[reorg.group('PilotInput',{'blk_2298.y1'},{'PilotInput'}), ...
    reorg.group('Height',{'blk_3819.y3'},{'Height'}), ...
    reorg.group('FlightContext',{'blk_2300.y1'},{'FlightContext'}), ...
    reorg.group('TimingAndThrust',{'blk_2301.y1','blk_3312.y3'},{'Dt','ThrustState'})];
outputGroups=[reorg.group('FlightCommand',{'blk_3418.y1'},{'FlightCommand'}), ...
    reorg.group('SharedControlContext',{'blk_3818.y1'},{'SharedControlContext'}), ...
    reorg.group('CommandStatus',{'blk_2606.y5','blk_2364.y1','blk_3821.y1','blk_3821.y2'}, ...
    {'AltitudeEnabled','Mode','Reset','FlipPhase'})];
links=reorg.links(m,scope);
report=reorg.groupCopy(m,scope,scope,selected,'FlightCommand400',inputGroups,outputGroups);
fields=reorg.outputMap(m,scope,report.ID,outputGroups);ops={};
for k=1:3
    ops{end+1}=reorg.wire(inputGroups(k).Members.Endpoint,sprintf('%s.u%d',report.ID,k),inputGroups(k).Name); %#ok<AGROW>
end
ops{end+1}=reorg.add('BusCreator','TimingAndThrustBus','timing',struct('Inputs','2'));
for k=1:2
    ops{end+1}=reorg.wire(inputGroups(4).Members(k).Endpoint,sprintf('#timing.u%d',k),inputGroups(4).Members(k).Name); %#ok<AGROW>
end
ops{end+1}=reorg.wire('#timing.y1',[report.ID '.u4'],'TimingAndThrust');
for g=1:numel(outputGroups)
    members=outputGroups(g).Members;
    for j=1:numel(members)
        token=regexp(members(j).Endpoint,'(blk_\d+)\.y(\d+)','tokens','once');
        outgoing=links(strcmp({links.Src},token{1}) & [links.SrcPort]==str2double(token{2}) & ~ismember({links.Dst},selected));
        source=fields.Groups.(outputGroups(g).Name).(members(j).Name);
        for k=1:numel(outgoing)
            ops{end+1}=reorg.wire(source,sprintf('%s.u%d',outgoing(k).Dst,outgoing(k).DstPort),members(j).Name); %#ok<AGROW>
        end
    end
end
for k=1:numel(selected),ops{end+1}=struct('op','delete','target',selected{k});end %#ok<AGROW>
reply=reorg.edit(m,scope,ops);
report.TimingBus=reorg.created(reply,'timing');report.OutputFields=fields;
disp(model_check(m,scope,'["all"]'));
save(fullfile(stampfly_project_root(),'build','tests','flight_commands_group.mat'),'report');
save_system(m,fullfile(stampfly_project_root(),[m '.slx']));
fprintf('FLIGHT_COMMAND_GROUP_COMPLETE\n');
end
