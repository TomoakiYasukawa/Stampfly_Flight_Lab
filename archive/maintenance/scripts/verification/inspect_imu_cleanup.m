function report=inspect_imu_cleanup()
%INSPECT_IMU_CLEANUP 整理前の端子・状態境界・組み込み関数を確認する。
root=stampfly_project_root();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);
model='StampFly_IMU400';open_system(stampfly_model_file(model));init_basic();
folder=fullfile(root,'build','imu_cleanup','inspection');if ~isfolder(folder),mkdir(folder);end
scopes={'root','blk_3178','blk_3183','blk_2746','blk_2755','blk_2857', ...
    'blk_3865','blk_3871','blk_3271','blk_3202','blk_3221','blk_3077', ...
    'blk_3015','blk_3052','blk_2244'};
for k=1:numel(scopes)
    reply=char(model_read(model,scopes{k},'0'));
    writeText(fullfile(folder,[scopes{k} '.txt']),reply);
end
blocks=find_system(model,'LookUnderMasks','all','FollowLinks','off','Type','Block');
records=struct('ID',{},'Path',{},'Parent',{},'Name',{},'Type',{},'System',{}, ...
    'Atomic',{},'Mask',{},'MaskType',{},'LinkStatus',{},'Inports',{},'Outports',{});
for k=1:numel(blocks)
    p=blocks{k};id=reorg.id(p);type=get_param(p,'BlockType');h=get_param(p,'PortHandles');
    sys='';atomic='';maskType='';
    if strcmp(type,'MATLABSystem'),sys=get_param(p,'System');end
    if strcmp(type,'SubSystem'),atomic=get_param(p,'TreatAsAtomicUnit');maskType=get_param(p,'MaskType');end
    records(k)=struct('ID',id,'Path',p,'Parent',get_param(p,'Parent'), ...
        'Name',get_param(p,'Name'),'Type',type,'System',sys,'Atomic',atomic, ...
        'Mask',get_param(p,'Mask'),'MaskType',maskType,'LinkStatus',get_param(p,'LinkStatus'), ...
        'Inports',numel(h.Inport),'Outports',numel(h.Outport));
end
charts=sfroot().find('-isa','Stateflow.EMChart');functions=struct('ID',{},'Name',{},'Path',{},'File',{});
for k=1:numel(charts)
    if ~startsWith(charts(k).Path,[model '/']),continue;end
    p=charts(k).Path;cfg=get_param(p,'MATLABFunctionConfiguration');id=reorg.id(p);
    file=fullfile(folder,[id '_' get_param(p,'Name') '.m']);writeText(file,cfg.FunctionScript);
    functions(end+1)=struct('ID',id,'Name',get_param(p,'Name'),'Path',p,'File',file); %#ok<AGROW>
end
details=struct;
for id={'blk_2746','blk_2755','blk_2857','blk_3178','blk_3183','blk_3865','blk_3871'}
    p=reorg.path(model,id{1});children=find_system(p,'SearchDepth',1,'Type','Block');items=struct;
    for k=1:numel(children)
        q=children{k};if strcmp(q,p),continue;end
        params=get_param(q,'DialogParameters');values=struct;
        if isempty(params),params=struct;end
        for f=fieldnames(params)'
            v=get_param(q,f{1});if ischar(v)||isnumeric(v)||islogical(v),values.(f{1})=v;end
        end
        values.Name=get_param(q,'Name');values.Type=get_param(q,'BlockType');
        items.(reorg.id(q))=values;
    end
    details.(id{1})=items;
end
report=struct('Model',model,'Blocks',records,'Functions',functions,'Details',details);
writeText(fullfile(folder,'manifest.json'),jsonencode(report,'PrettyPrint',true));
fprintf('IMU_CLEANUP_INSPECTION_COMPLETE: %d blocks, %d MATLAB Functions\n',numel(blocks),numel(functions));
end
function writeText(file,value)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',value);fclose(fid);
end
