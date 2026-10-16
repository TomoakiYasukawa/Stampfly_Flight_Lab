function snapshot=semanticSnapshot(model)
%SEMANTICSNAPSHOT 配置変更前後の演算・端子接続・実行条件を比較する。
% 表示位置・説明・マスクアイコンを除き、設定値と信号の始点/終点を記録。
blocks=find_system(model,'LookUnderMasks','all','FollowLinks','off','Type','Block');
records=struct('ID',{},'Name',{},'Type',{},'Parameters',{},'Conditions',{},'Inputs',{});
for k=1:numel(blocks)
    p=blocks{k};objects=get_param(p,'ObjectParameters');
    parameters=get_param(p,'DialogParameters');values=struct;
    if isempty(parameters),parameters=struct;end
    % マスクを付けると DialogParameters はマスクの編集欄だけになる。
    % 実行条件の検証では、マスクの有無によらず内在する設定も読む。
    if isfield(objects,'IntrinsicDialogParameters')
        intrinsic=get_param(p,'IntrinsicDialogParameters');
        if ~isempty(intrinsic)
            for f=fieldnames(intrinsic)'
                parameters.(f{1})=intrinsic.(f{1});
            end
        end
    end
    for f=sort(fieldnames(parameters))'
        if ismember(f{1},{'MaskDisplay','MaskDescription','Description'}),continue;end
        values.(f{1})=get_param(p,f{1});
    end
    conditions=struct;
    for f={'SampleTime','TreatAsAtomicUnit','Priority','TagVisibility','FunctionName','RTWSystemCode'}
        if isfield(objects,f{1}),conditions.(f{1})=get_param(p,f{1});end
    end
    ports=get_param(p,'PortHandles');edges=strings(0,1);
    for field=fieldnames(ports)'
        if ismember(field{1},{'Outport','State','LConn','RConn'}),continue;end
        for j=1:numel(ports.(field{1}))
            line=get_param(ports.(field{1})(j),'Line');if line<0,continue;end
            source=get_param(line,'SrcPortHandle');if source<0,continue;end
            edges(end+1)=string(field{1})+":"+j+" <- "+ ...
                string(reorg.id(get_param(source,'Parent')))+":"+ ...
                string(get_param(source,'PortType'))+":"+ ...
                string(get_param(source,'PortNumber')); %#ok<AGROW>
        end
    end
    records(k)=struct('ID',reorg.id(p),'Name',get_param(p,'Name'), ...
        'Type',get_param(p,'BlockType'),'Parameters',values, ...
        'Conditions',conditions,'Inputs',sort(edges));
end
[~,order]=sort(string({records.ID}));snapshot=records(order);
end
