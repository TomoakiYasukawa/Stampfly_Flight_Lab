function report=audit_imu_cleanup()
%AUDIT_IMU_CLEANUP 保存モデルの配線・説明・端子表示と全体更新を確認する。
root=stampfly_project_root();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
license('checkout','Navigation_Toolbox');init_imu_flight();
models={'StampFly_IMU400','M5Stamp_IMU_Rx'};
reports=struct('Model',{},'FullUpdatePassed',{},'CheckedScopes',{}, ...
    'ConnectionIssues',{},'MATLABFunctionCount',{},'JapaneseFunctionComments',{}, ...
    'CustomSystemHeaders',{},'MaskedSubsystemPortLabels',{});
for n=1:numel(models)
    model=models{n};open_system(fullfile(root,[model '.slx']));
    set_param(model,'SimulationCommand','update');
    scopes=[{model};find_system(model,'LookUnderMasks','all','FollowLinks','off','BlockType','SubSystem')];
    scopes=unique(scopes,'stable');issues={};checked=0;
    for k=1:numel(scopes)
        p=scopes{k};
        if ~strcmp(p,model) && insideNative(p,model),continue;end
        % MATLAB FunctionをStateflowの内部接続として誤検出しない。
        % 信号端子は親スコープと、下のPortHandles監査で確認する。
        if ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',p)) || ...
                ~isempty(sfroot().find('-isa','Stateflow.EMChart','Path',p)),continue;end
        if strcmp(p,model),id='root';else,id=reorg.id(p);end
        result=char(model_check(model,id,'["unconnected_ports","unconnected_lines"]'));checked=checked+1;
        if contains(result,'severity: error') || contains(result,'status: error')
            issues{end+1}=struct('Scope',id,'Result',result); %#ok<AGROW>
        end
    end
    disp(model_check(model,'root','["stateflow_lint"]'));
    % 数値信号の未接続入力・出力を別の方法でも確認する。
    blocks=find_system(model,'LookUnderMasks','all','FollowLinks','off','Type','Block');
    masks=0;headers=0;functions=0;
    for k=1:numel(blocks)
        p=blocks{k};if insideNative(p,model),continue;end
        if ~strcmp(get_param(p,'LinkStatus'),'none'),continue;end
        ports=get_param(p,'PortHandles');
        for side={'Inport','Outport'}
            for j=1:numel(ports.(side{1}))
                if get_param(ports.(side{1})(j),'Line')<0
                    issues{end+1}=struct('Scope',reorg.id(p),'Result', ...
                        sprintf('Unconnected %s %d',side{1},j)); %#ok<AGROW>
                end
            end
        end
        chart=sfroot().find('-isa','Stateflow.EMChart','Path',p);
        if ~isempty(chart)
            script=chart.Script;
            comments=regexp(script,'(?m)^\s*%[^\r\n]*','match');
            assert(numel(comments)>=3 && hasJapanese(strjoin(comments,newline)), ...
                'cleanup:FunctionComments','Japanese overview/sections missing: %s',p);
            assert(hasJapanese(get_param(p,'Description')));
            functions=functions+1;
        end
        if strcmp(get_param(p,'BlockType'),'MATLABSystem')
            cls=get_param(p,'System');
            if startsWith(cls,{'official.','stampfly.','basic.','imu.','horizontal.'})
                source=fileread(which(cls));
                assert(contains(source,'function header=getHeaderImpl()') || ...
                    contains(source,'function header = getHeaderImpl()'), ...
                    'cleanup:SystemHeader','Japanese settings help missing: %s',cls);
                assert(hasJapanese(get_param(p,'Description')));headers=headers+1;
            end
        end
        if strcmp(get_param(p,'BlockType'),'SubSystem') && ...
                strcmp(get_param(p,'Mask'),'on') && isempty(get_param(p,'MaskType'))
            display=get_param(p,'MaskDisplay');
            if ~isempty(ports.Inport) || ~isempty(ports.Outport)
                assert(contains(display,'port_label'), ...
                    'cleanup:PortLabels','Mask port labels missing: %s',p);
                masks=masks+1;
            end
        end
    end
    assert(isempty(issues),'cleanup:Connectivity','%s has connection errors: %s',model,jsonencode(issues));
    reports(n)=struct('Model',model,'FullUpdatePassed',true,'CheckedScopes',checked, ...
        'ConnectionIssues',{issues},'MATLABFunctionCount',functions, ...
        'JapaneseFunctionComments',true,'CustomSystemHeaders',headers, ...
        'MaskedSubsystemPortLabels',masks);
end
assert(reports(1).MATLABFunctionCount==14);
main=models{1};
tof=reorg.path(main,'blk_4187');
assert(strcmp(get_param(tof,'System'),'official.BottomToFSource'));
assert(isempty(get_param(tof,'PortHandles').Inport));
assert(slResolve(get_param(tof,'SampleTime'),main)==.0025);
assert(isempty(find_system(main,'LookUnderMasks','all','Name','OfficialFlipSequence')));
assert(isempty(find_system(main,'LookUnderMasks','all','Name','MadgwickAttitude')));
report=struct('Models',reports,'Passed',true,'RawToFHasNoModeInput',true, ...
    'RawToFStep',.0025,'PhysicalFlightTested',false,'Flashed',false);
writeJSON(fullfile(root,'docs','imu_cleanup_model_audit.json'),report);
fprintf('IMU_CLEANUP_SAVED_MODEL_AUDIT_PASSED\n');
end

function yes=insideNative(p,m)
% 標準ライブラリーの実装やStateflow内部端子は独自配線監査から除く。
yes=false;
parent=get_param(p,'Parent');
while ~isempty(parent) && ~strcmp(parent,m)
    if ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',parent)) || ...
            ~isempty(sfroot().find('-isa','Stateflow.EMChart','Path',parent)) || ...
            ~isempty(get_param(parent,'MaskType')) || ...
            ~strcmp(get_param(parent,'LinkStatus'),'none')
        yes=true;return;
    end
    parent=get_param(parent,'Parent');
end
end
function yes=hasJapanese(text)
yes=~isempty(regexp(text,'[ぁ-んァ-ヶ一-龠]','once'));
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
