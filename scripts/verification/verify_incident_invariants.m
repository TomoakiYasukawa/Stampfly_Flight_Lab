function report=verify_incident_invariants()
%VERIFY_INCIDENT_INVARIANTS 概要：1801保存版と診断版の変更範囲を確認します。
% 高度修正は制御出力へ影響するため、旧版との全出力一致とは区別します。
root=stampfly_project_root();configure_stampfly_project();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);init_imu_flight();
old='Horizontal1801';m='StampFly_IMU400';
oldFile=fullfile(root,'archive','snapshots',[old '.slx']);file=fullfile(root,[m '.slx']);
open_system(oldFile);open_system(file);
set_param(m,'SimulationCommand','update');
a=reorg.semanticSnapshot(old);b=reorg.semanticSnapshot(m);
oldIDs={a.ID};newIDs={b.ID};added=setdiff(newIDs,oldIDs);
assert(isequal(sort(added),sort({'blk_4348','blk_4349','blk_4350','blk_4351','blk_4352'})));
assert(isempty(setdiff(oldIDs,newIDs)),'incident:DeletedBlock','旧版のブロックが削除されています。');
changed={'blk_2236','blk_2260','blk_3995'};
for k=1:numel(a)
    j=find(strcmp(newIDs,a(k).ID));assert(isscalar(j));
    expected=a(k);
    if strcmp(expected.ID,'blk_2236')
        expected.Inputs=replace(expected.Inputs,'blk_2242:outport:1','blk_4348:outport:1');
        expected.Inputs=replace(expected.Inputs,'blk_2240:outport:5','blk_4351:outport:1');
    elseif strcmp(expected.ID,'blk_2260')
        expected.Inputs=replace(expected.Inputs,'blk_2236:outport:3','blk_4352:outport:1');
    elseif strcmp(expected.ID,'blk_3995')
        expected.Parameters.FirmwareRevision='uint32(1804)';
    end
    assert(isequaln(expected,b(j)),'incident:UnexpectedChange','想定外の変更: %s',expected.ID);
end
% MATLAB Function本体は全14個で一致。7 PIDとSupervisorの設定も維持。
scripts=sfroot().find('-isa','Stateflow.EMChart');functions=0;
for k=1:numel(scripts)
    p=scripts(k).Path;if ~startsWith(p,[old '/']),continue;end
    id=reorg.id(p);target=sfroot().find('-isa','Stateflow.EMChart','Path',reorg.path(m,id));
    assert(isscalar(target)&&strcmp(scripts(k).Script,target.Script),'incident:FunctionChanged','%s',id);
    functions=functions+1;
end
assert(functions==14);assert(numel(find_system(m,'LookUnderMasks','all','Name','DedicatedPID'))==7);
% 最上位Supervisorのラベル・状態順序を比較します。
chartOld=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(old,'blk_4166'));
chartNew=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(m,'blk_4166'));
assert(isscalar(chartOld)&&isscalar(chartNew));
for cls={'Stateflow.State','Stateflow.Transition','Stateflow.Junction','Stateflow.Data'}
    assert(isequaln(chartContent(chartOld,cls{1}),chartContent(chartNew,cls{1})),'incident:SupervisorChanged','%s',cls{1});
end
check=char(model_check(m,'blk_2231','["unconnected_ports","unconnected_lines"]'));disp(check);
assert(~contains(check,'severity: error')&&~contains(check,'status: error'));
report=struct('Passed',true,'Model','StampFly_IMU400.slx','ModelSHA256',sha256(file), ...
    'BaselineSnapshot','archive/snapshots/Horizontal1801.slx','BaselineSHA256',sha256(oldFile), ...
    'PreservedBlockCount',numel(a),'AddedBoundaryBlocks',{added},'ChangedExistingBlocks',{changed}, ...
    'MATLABFunctionCount',functions,'MATLABFunctionSourcesUnchanged',true, ...
    'PIDCount',7,'PIDParametersPreserved',true,'SupervisorUnchanged',true, ...
    'EstimatorBoundaryChangesExplicit',true,'FullOutputEquivalenceClaimed',false, ...
    'WatchdogDisabled',false,'FlightCauseConfirmed',false,'HardwareIO',false);
fid=fopen(fullfile(root,'docs','incident_invariants_verification.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('INCIDENT_INVARIANTS_VERIFIED\n');
end
function rows=chartContent(chart,cls)
objects=chart.find('-isa',cls);rows=cell(1,numel(objects));
for k=1:numel(objects)
    o=objects(k);r=struct;
    for p={'LabelString','Name','Scope','ExecutionOrder','DataType','Port','InitialValue'}
        if isprop(o,p{1}),r.(p{1})=o.(p{1});end
    end
    rows{k}=jsonencode(r);
end
rows=sort(rows);
end
function value=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);value=lower(strtrim(value));
end
