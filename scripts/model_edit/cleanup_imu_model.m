function report=cleanup_imu_model(stage)
%CLEANUP_IMU_MODEL 現行 IMU モデルのセンサー配線・仮想階層・表示名を整理。
% Enabled / Resettable の実行条件と PID 係数は変更しない。
arguments
    stage (1,1) string {mustBeMember(stage,["tof","vectors","wrappers","pid","names"])}
end
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
model='StampFly_IMU400';open_system(fullfile(root,[model '.slx']));init_basic();
listeners=layout.LayoutListeners();
layoutDisabler=listeners.getScopedLayoutListenerDisabler(model); %#ok<NASGU>
folder=fullfile(root,'build','imu_cleanup');if ~isfolder(folder),mkdir(folder);end
checkpoint=fullfile(folder,'cleanup_checkpoint.mat');
if isfile(checkpoint),report=load(checkpoint,'report').report;
else,report=struct('Model',[model '.slx'],'CompletedStages',{{}},'BlockMap',struct);end
assert(~ismember(char(stage),report.CompletedStages),'cleanup:AlreadyDone','Stage already saved: %s',stage);
switch stage
    case "tof"
        reorg.edit(model,'blk_3183',{ ...
            struct('op','disconnect','target','blk_3186.y1 -> blk_3188.u1'), ...
            reorg.configure('blk_3188',struct('System','official.BottomToFSource','Name','BottomToFSource')), ...
            struct('op','delete','target','blk_3186'),struct('op','delete','target','blk_3184')});
        reorg.edit(model,'blk_3178',{struct('op','delete','target','blk_3181')});
        lift=reorg.lift(model,'blk_3183');report=mergeMap(report,lift);
        source=report.BlockMap.blk_3188;
        ops={reorg.wire([source '.y1'],'blk_3193.u1','DistanceMm'), ...
            reorg.wire([source '.y2'],'blk_3194.u1','Fresh'), ...
            reorg.wire([source '.y3'],'blk_3197.u1','FrontDistanceMm'), ...
            reorg.wire([source '.y4'],'blk_3195.u1','Status'), ...
            reorg.wire([source '.y5'],'blk_3196.u1','Info'), ...
            struct('op','delete','target','blk_3191'),struct('op','delete','target','blk_3192'), ...
            struct('op','delete','target',report.BlockMap.blk_3187)};
        reorg.edit(model,'blk_3178',ops);
        reorg.edit(model,'root',{reorg.configure('blk_4163',struct('OutputSignals','PreviousMode'))});
        report.BottomToFSource=source;report.BottomRangeBus=report.BlockMap.blk_3185;
    case "vectors"
        % Reuse the exact scalar recurrence in vector form. Element order stays XYZ.
        configureVectorLowpass(model,'blk_2755','AccelLowpassXYZ');
        configureVectorLowpass(model,'blk_2806','GyroLowpassXYZ');
        old={'blk_2772','blk_2789','blk_2823','blk_2840','blk_2752','blk_2753', ...
            'blk_2875','blk_2876','blk_2877','blk_2880','blk_2881','blk_2882'};
        ops={reorg.add('Selector','GyroBiasXYZ','gyroBias', ...
            struct('NumberOfDimensions','1','IndexMode','One-based', ...
                'InputPortWidth','4','IndexOptionArray',{{'Index vector (dialog)'}},'IndexParamArray',{{'[1 2 3]'}})), ...
            reorg.add('Selector','AccelBiasZ','accelBias', ...
            struct('NumberOfDimensions','1','IndexMode','One-based', ...
                'InputPortWidth','4','IndexOptionArray',{{'Index vector (dialog)'}},'IndexParamArray',{{'4'}})), ...
            reorg.add('Selector','AccelZ','accelZ', ...
                struct('NumberOfDimensions','1','IndexMode','One-based', ...
                'IndexOptionArray',{{'Index vector (dialog)'}},'IndexParamArray',{{'3'}})), ...
            reorg.add('Sum','RemoveGyroBiasXYZ','removeBias',struct('Inputs','+-','IconShape','rectangular')), ...
            reorg.wire('blk_2749.y1','#gyroBias.u1'),reorg.wire('blk_2749.y1','#accelBias.u1'), ...
            reorg.wire('blk_2747.y1','#accelZ.u1'),reorg.wire('blk_2747.y1','blk_2755.u1'), ...
            reorg.wire('blk_2748.y1','#removeBias.u1'),reorg.wire('#gyroBias.y1','#removeBias.u2'), ...
            reorg.wire('#removeBias.y1','blk_2806.u1'), ...
            reorg.wire('#accelZ.y1','blk_2883.u1'),reorg.wire('#accelBias.y1','blk_2883.u2'), ...
            reorg.wire('blk_2755.y1','blk_2885.u1'),reorg.wire('blk_2806.y1','blk_2886.u1'), ...
            reorg.configure('blk_2857',struct('Name','VerticalDeltaLowpass')), ...
            reorg.configure('blk_2883',struct('Name','RemoveAccelBiasZ'))};
        for k=1:numel(old),ops{end+1}=struct('op','delete','target',old{k});end %#ok<AGROW>
        reply=reorg.edit(model,'blk_2746',ops);
        report.VectorFilters=struct('Acceleration','blk_2755','AngularRate','blk_2806', ...
            'VerticalDelta','blk_2857','GyroBias',reorg.created(reply,'gyroBias'), ...
            'AccelZ',reorg.created(reply,'accelZ'),'AccelBias',reorg.created(reply,'accelBias'));
    case "wrappers"
        % Remove redundant terminators that already branch to diagnostic buses.
        reorg.edit(model,'blk_3202',{struct('op','delete','target','blk_3205'),struct('op','delete','target','blk_3207')});
        candidates={'blk_3271','blk_3202','blk_3221','blk_3077','blk_3015','blk_3052','blk_2244'};
        for k=1:numel(candidates)
            assertVirtual(model,candidates{k});
            lifted=reorg.lift(model,candidates{k});report=mergeMap(report,lifted);
        end
    case "pid"
        wrappers={'blk_3865','blk_3881','blk_3897','blk_3913','blk_3929','blk_3945','blk_3961'};
        enabled={'blk_3871','blk_3887','blk_3903','blk_3919','blk_3935','blk_3951','blk_3967'};
        for k=1:numel(wrappers)
            report=liftPID(model,wrappers{k},enabled{k},report);
        end
        assert(numel(find_system(model,'LookUnderMasks','all','Name','DedicatedPID'))==7);
    case "names"
        % 400 Hz is a model setting; remove it from display names and matching tags.
        scopes=[{'root'};findScopeIDs(model)];
        renamed=struct('ID',{},'Before',{},'After',{});
        for k=1:numel(scopes)
            if strcmp(scopes{k},'root'),p=model;else,p=reorg.path(model,scopes{k});end
            children=find_system(p,'SearchDepth',1,'Type','Block');ops={};
            for j=1:numel(children)
                q=children{j};if strcmp(q,p),continue;end
                name=get_param(q,'Name');new=regexprep(name,'400','');params=struct;
                if ~strcmp(name,new)
                    if ismember(new,cellfun(@(b)get_param(b,'Name'),children,'UniformOutput',false))
                        if strcmp(name,'Diagnostics400'),new='SystemDiagnostics';
                        else,error('cleanup:NameConflict','Renaming would conflict: %s',new);end
                    end
                    params.Name=new;renamed(end+1)=struct('ID',reorg.id(q),'Before',name,'After',new); %#ok<AGROW>
                end
                if ismember(get_param(q,'BlockType'),{'Goto','From','GotoTagVisibility'})
                    tag=get_param(q,'GotoTag');if contains(tag,'400'),params.GotoTag=strrep(tag,'400','');end
                end
                if ~isempty(fieldnames(params)),ops{end+1}=reorg.configure(reorg.id(q),params);end %#ok<AGROW>
            end
            if ~isempty(ops),reorg.edit(model,scopes{k},ops);end
        end
        report.RenamedBlocks=renamed;
end
for scope={'root','blk_3178','blk_2746','blk_2231','blk_2274','blk_2963'}
    result=char(model_check(model,scope{1},'["all"]'));disp(result);
    assert(~contains(result,'severity: error'),'cleanup:Connectivity','Incomplete scope %s',scope{1});
end
save_system(model);report.CompletedStages{end+1}=char(stage);save(checkpoint,'report');
writeJSON(fullfile(root,'docs','imu_cleanup_structure.json'),report);
fprintf('IMU_CLEANUP_STAGE_COMPLETE: %s\n',stage);
end

function configureVectorLowpass(m,id,name)
p=reorg.path(m,id);assertVirtual(m,id);children=find_system(p,'SearchDepth',1,'Type','Block');ops={};
for k=1:numel(children)
    q=children{k};n=get_param(q,'Name');params=struct;
    if strcmp(n,'PreviousFiltered'),params.InitialCondition="zeros(3,1,'single')";
    elseif strcmp(n,'ZeroOnReset'),params.Value="zeros(3,1,'single')";
    elseif strcmp(n,'Input'),params.PortDimensions='3';
    elseif strcmp(get_param(q,'BlockType'),'Product'),params.Multiplication='Element-wise(.*)';
    end
    if ~isempty(fieldnames(params)),ops{end+1}=reorg.configure(reorg.id(q),params);end %#ok<AGROW>
end
reorg.edit(m,id,ops);
parent=get_param(p,'Parent');reorg.edit(m,reorg.id(parent),{reorg.configure(id,struct('Name',name))});
end

function report=liftPID(m,outer,inner,report)
% Keep the Enabled subsystem intact, including its control port and held states.
assertVirtual(m,outer);p=reorg.path(m,outer);name=get_param(p,'Name');parent=get_param(p,'Parent');scope=reorg.id(parent);
links=reorg.links(m,scope);outside=links(strcmp({links.Src},outer));
copy='ReorganizationCopySource';folder=fullfile(stampfly_project_root(),'build','model_edit');
if ~isfolder(folder),mkdir(folder);end
file=fullfile(folder,[copy '.slx']);
if bdIsLoaded(copy),close_system(copy,0);end
save_system(m);copyfile(get_param(m,'FileName'),file);open_system(file);clean=onCleanup(@()close_system(copy,0)); %#ok<NASGU>
reorg.edit(m,scope,{reorg.configure(outer,struct('Name',[name '_Wrapper']))});
ops={reorg.add(reorg.path(copy,inner),name,'pid')};
ports=[1 2 4 3];dest={'u1','u2','u3','enable'};
for k=1:4
    link=links(strcmp({links.Dst},outer)&[links.DstPort]==ports(k));assert(isscalar(link));
    ops{end+1}=reorg.wire(sprintf('%s.y%d',link.Src,link.SrcPort),['#pid.' dest{k}]); %#ok<AGROW>
end
for k=1:numel(outside)
    ops{end+1}=reorg.wire('#pid.y1',sprintf('%s.u%d',outside(k).Dst,outside(k).DstPort),outside(k).Name); %#ok<AGROW>
end
ops{end+1}=struct('op','delete','target',outer);reply=reorg.edit(m,scope,ops);
report.BlockMap.(outer)=reorg.created(reply,'pid');report.BlockMap.(inner)=reorg.created(reply,'pid');
end

function assertVirtual(m,id)
p=reorg.path(m,id);assert(strcmp(get_param(p,'TreatAsAtomicUnit'),'off'));
for type={'EnablePort','TriggerPort','ResetPort','ActionPort'}
    assert(isempty(find_system(p,'SearchDepth',1,'BlockType',type{1})), ...
        'cleanup:ExecutionBoundary','Cannot lift execution-controlled subsystem %s',id);
end
end
function report=mergeMap(report,lift)
for k=1:numel(lift.Sources),report.BlockMap.(lift.Sources{k})=lift.Copies{k};end
end
function scopes=findScopeIDs(m)
paths=find_system(m,'LookUnderMasks','all','FollowLinks','off','BlockType','SubSystem');scopes={};
for k=1:numel(paths)
    p=paths{k};if ~strcmp(get_param(p,'LinkStatus'),'none')||~isempty(get_param(p,'MaskType')),continue;end
    if ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',p)),continue;end
    scopes{end+1,1}=reorg.id(p); %#ok<AGROW>
end
end
function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));fclose(fid);
end
