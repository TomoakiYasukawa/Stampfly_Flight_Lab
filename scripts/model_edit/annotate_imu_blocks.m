function report=annotate_imu_blocks()
%ANNOTATE_IMU_BLOCKS 機能説明・端子名をモデルとマスク設定画面へ保存する。
root=stampfly_project_root();ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
spec=jsondecode(fileread(fullfile(root,'scripts','model_edit','imu_block_documentation.json')));
spec.Systems=systemDescriptions(spec.Systems);
m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));init_basic();
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(m); %#ok<NASGU>
blocks=find_system(m,'LookUnderMasks','all','FollowLinks','off','Type','Block');groups=struct;
records=struct('ID',{},'Name',{},'JapaneseDescription',{},'SettingsDescription',{});
for k=1:numel(blocks)
    p=blocks{k};type=get_param(p,'BlockType');name=get_param(p,'Name');id=reorg.id(p);
    if ~strcmp(get_param(p,'LinkStatus'),'none'),continue;end
    parent=get_param(p,'Parent');
    if insideNativeBlock(parent,m),continue;end
    description='';maskDescription=false;params=struct;
    if ismember(name,{'JapaneseExplanation','ModelExplanation'})
        description=scopeDescription(parent,m,spec);
        if isempty(description),continue;end
        params.MaskDisplay=maskDisplay(description);params.MaskDescription=description;
        params.ShowName='off';params.MaskIconFrame='off';maskDescription=true;
    elseif strcmp(type,'MATLABSystem')
        sys=get_param(p,'System');key=matlab.lang.makeValidName(sys);
        assert(isfield(spec.Systems,key),'cleanup:SystemHelp','No Japanese help for %s',sys);
        description=spec.Systems.(key).Description;
    elseif strcmp(type,'SubSystem')
        chart=sfroot().find('-isa','Stateflow.EMChart','Path',p);
        if ~isempty(chart)
            description=get_param(p,'Description');
            assert(~isempty(regexp(description,'[ぁ-んァ-ヶ一-龠]','once')));
        elseif ~isempty(get_param(p,'MaskType'))
            if strcmp(name,'DedicatedPID')
                description=['離散 PID の専用ブロックです。Ideal 形式、外部 dt、外部 Reset、' ...
                    '台形積分と台形微分フィルターを使います。係数は設定画面で編集します。' ...
                    '外側の Enabled subsystem の実行条件を保ちます。'];
            else,continue;end
        else
            description=scopeDescription(p,m,spec);
            if isempty(description),continue;end
            params.ShowPortLabels='FromPortBlockName';
            if strcmp(get_param(p,'Mask'),'on')
                [inputs,outputs]=reorg.ports(m,id);display=char(sprintf("disp('%s');",quote(name)));
                for j=1:numel(inputs)
                    n=get_param(reorg.path(m,inputs{j}),'Name');display=[display char(sprintf("port_label('input',%d,'%s');",j,quote(n)))]; %#ok<AGROW>
                end
                for j=1:numel(outputs)
                    n=get_param(reorg.path(m,outputs{j}),'Name');display=[display char(sprintf("port_label('output',%d,'%s');",j,quote(n)))]; %#ok<AGROW>
                end
                params.Mask='on';params.MaskDisplay=char(display);params.MaskDescription=description;maskDescription=true;
            end
        end
    else
        description=primitiveDescription(p,type,name);
        if isempty(description),continue;end
    end
    params.Description=description;
    if strcmp(parent,m),scope='root';else,scope=reorg.id(parent);end
    if ~isfield(groups,scope),groups.(scope)={};end
    groups.(scope){end+1}=reorg.configure(id,params);
    records(end+1)=struct('ID',id,'Name',name,'JapaneseDescription',true,'SettingsDescription',maskDescription); %#ok<AGROW>
end
% A fixed default is exposed in both aircraft radio blocks; no source edits needed.
groups.blk_2963{end+1}=reorg.configure('blk_3996',struct('Channel','uint8(3)'));
scopes=fieldnames(groups);
for k=1:numel(scopes),reorg.edit(m,scopes{k},groups.(scopes{k}));end
save_system(m);
% The receiver is still a current model. Keep its native System dialog and add help.
rx='M5Stamp_IMU_Rx';open_system(fullfile(root,[rx '.slx']));
devices=find_system(rx,'BlockType','MATLABSystem','System','imu.M5Receiver');assert(isscalar(devices));
key=matlab.lang.makeValidName('imu.M5Receiver');
reorg.edit(rx,'root',{reorg.configure(reorg.id(devices{1}),struct('Description',spec.Systems.(key).Description))});
save_system(rx);
report=struct('Model',m,'DocumentedBlockCount',numel(records),'Blocks',records, ...
    'SystemDialogHeaders',16,'ReceiverDocumented',true);
fid=fopen(fullfile(root,'docs','imu_block_documentation.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('IMU_BLOCK_DOCUMENTATION_COMPLETE: %d blocks\n',numel(records));
end

function result=systemDescriptions(input)
% JSON decoding changes dots in property names to valid struct field names.
result=input;
end
function text=scopeDescription(p,m,spec)
if strcmp(p,m)
    text=['StampFly の学習用実装。400 Hz でセンサー取得→校正→姿勢・高度推定→' ...
        '離着陸と 7 PID→4 モーターへ処理します。Flip はありません。' ...
        '最上位 Stateflow がモードを管理し、下段は観測・記録・状態表示です。'];return;
end
name=get_param(p,'Name');key=matlab.lang.makeValidName(name);
if isfield(spec.Subsystems,key),text=spec.Subsystems.(key);else,text='';end
end
function yes=insideNativeBlock(p,m)
yes=false;
while ~strcmp(p,m)
    if ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',p)),yes=true;return;end
    if strcmp(get_param(p,'BlockType'),'SubSystem') && ...
            (~isempty(get_param(p,'MaskType'))||~strcmp(get_param(p,'LinkStatus'),'none'))
        yes=true;return;
    end
    p=get_param(p,'Parent');
end
end
function text=primitiveDescription(p,type,name)
switch type
    case 'Goto',text=sprintf('名前付き信号 %s を公開します。対応する From は同じ値を読み、周期遅れを追加しません。',get_param(p,'GotoTag'));
    case 'From',text=sprintf('名前付き信号 %s を読みます。設定画面の Goto source から送信元を確認できます。',get_param(p,'GotoTag'));
    case 'BusCreator',text=sprintf('%s：異なる単位・型を持つ関連信号を名前付きバスにまとめます。入力線の信号名が項目名です。',name);
    case 'BusSelector',text=sprintf('%s：バスから %s を選びます。元のベクトルの成分順序は変更しません。',name,get_param(p,'OutputSignals'));
    case 'UnitDelay',text=sprintf('%s：前周期の値を保持して出力します。更新順序と状態保持に必要な 1 周期遅延です。初期値 %s、周期 %s 秒。',name,get_param(p,'InitialCondition'),get_param(p,'SampleTime'));
    case 'ZeroOrderHold',text=sprintf('%s：入力の最新値を指定周期で保持します。異なる更新周期の観測値を診断へ渡します。',name);
    case 'Selector',text=sprintf('%s：必要なベクトル成分を選びます。選択位置は設定画面の Indices で確認します。',name);
    case 'DataTypeConversion',text=sprintf('%s：後段のバス・演算に合わせて %s 型へ変換します。',name,get_param(p,'OutDataTypeStr'));
    case 'Sum',text=sprintf('%s：入力を %s の符号で加減算します。ベクトルでは各成分に同じ演算を適用します。',name,get_param(p,'Inputs'));
    case 'Product',text=sprintf('%s：入力の乗算・除算（%s）を行います。フィルターは既存の演算順序を保ちます。',name,get_param(p,'Inputs'));
    case 'Gain',text=sprintf('%s：入力に %s を掛けます。座標変換・単位換算・制御係数は用途ごとに維持します。',name,get_param(p,'Gain'));
    case 'Mux',text=sprintf('%s：同じ型の値を入力端子の順でベクトルに結合します。ログ仕様・モーター順に対応する結合は順序を保ちます。',name);
    case 'Demux',text=sprintf('%s：ベクトルを元の成分順に分解します。個別の誤差や符号処理が必要な箇所で使います。',name);
    case 'Switch',text=sprintf('%s：条件入力で更新値と保持・リセット値を選びます。条件は %s。',name,get_param(p,'Criteria'));
    case 'Saturate',text=sprintf('%s：下限 %s、上限 %s で入力を制限します。',name,get_param(p,'LowerLimit'),get_param(p,'UpperLimit'));
    case 'Constant',text=sprintf('%s：固定値 %s を出力します。意味と単位は親の機能説明と信号名を参照します。',name,get_param(p,'Value'));
    case 'Terminator',text=sprintf('%s：使用しない観測出力をここで終端します。接続された制御信号を変更しません。',name);
    otherwise,text='';
end
end
function out=quote(in),out=strrep(in,"'","''");end
function text=maskDisplay(description)
lines=regexp(description,'(?<=。)','split');lines=lines(~cellfun(@isempty,lines));
text=sprintf("disp(sprintf('%s'));",strrep(strrep(strjoin(lines,newline),"'","''"),newline,'\n'));
end
