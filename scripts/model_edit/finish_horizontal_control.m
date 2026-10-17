function report=finish_horizontal_control()
%FINISH_HORIZONTAL_CONTROL 接続済みの水平制御モデルを検査して保存します。
% 中断後の再開にも使います。ブロックを重複追加せず、境界の名前と
% 日本語の説明を整え、モデル更新が通ってから検証用のIDを記録します。
root=stampfly_project_root();ensure_simulink_toolkit();
assert(library.settingsLookup().gatePass);init_imu_flight();
m='StampFly_IMU400';open_system(fullfile(root,[m '.slx']));
estimator=find_system(m,'SearchDepth',1,'Name','HorizontalMotionEstimation');
controller=find_system(m,'LookUnderMasks','all','Name','HorizontalControl');
assert(isscalar(estimator)&&isscalar(controller));
estimator=reorg.id(estimator{1});controller=reorg.id(controller{1});

% 1. 元のSupervisorバスの項目名を保ちます。線名は分岐全体に共通です。
reorg.edit(m,'root',{reorg.configure('blk_4166.y3 -> blk_4168.u3',struct('Name','AttitudeReset')), ...
    reorg.configure('blk_4300',struct('InheritFromInputs','off'))});
% RelationalOperatorの追加時に既定演算へ戻った設定を明示して確認します。
reorg.edit(m,'blk_2297',{reorg.configure('blk_4307',struct('Operator','>=')), ...
    reorg.configure('blk_4308',struct('Operator','<='))});
assert(strcmp(get_param(reorg.path(m,'blk_4307'),'Operator'),'>='));
assert(strcmp(get_param(reorg.path(m,'blk_4308'),'Operator'),'<='));
% 新しい境界は定義済みバスの名前を使い、BusSelectorの伝播名に依存しません。
buses=find_system(reorg.path(m,estimator),'SearchDepth',1,'BlockType','BusCreator');
ops={};for k=1:numel(buses),ops{end+1}=reorg.configure(reorg.id(buses{k}),struct('InheritFromInputs','off'));end %#ok<AGROW>
reorg.edit(m,estimator,ops);

% 仮想の混合型バスはSystemブロックへ直接渡せないため、必要な条件を
% 名前付きの非仮想バスにします。元のSharedControlContextは変更しません。
[ci,~]=reorg.ports(m,controller);
contextAdapter=find_system(reorg.path(m,controller),'LookUnderMasks','all','SearchDepth',1,'Name','HorizontalControlContext');
if isempty(contextAdapter)
    reorg.edit(m,controller,{ ...
        reorg.add('BusSelector','HorizontalContextFields','contextFields',struct('OutputSignals', ...
            'Dt,ControlMode,FlightContext.Branch,ControlContext.Run,ControlContext.Reset,ControlContext.AltitudeEnabled')), ...
        reorg.add('DataTypeConversion','ControlModeToUint8','controlMode',struct('OutDataTypeStr','uint8')), ...
        reorg.add('BusCreator','HorizontalFlightContext','flight',struct('Inputs','1', ...
            'OutDataTypeStr','Bus: HorizontalFlightContextBus','NonVirtualBus','on','InheritFromInputs','off')), ...
        reorg.add('BusCreator','HorizontalControlGates','gates',struct('Inputs','3', ...
            'OutDataTypeStr','Bus: HorizontalControlGatesBus','NonVirtualBus','on','InheritFromInputs','off')), ...
        reorg.add('BusCreator','HorizontalControlContext','context',struct('Inputs','4', ...
            'OutDataTypeStr','Bus: HorizontalControlContextBus','NonVirtualBus','on','InheritFromInputs','off')), ...
        reorg.wire([ci{3} '.y1'],'#contextFields.u1'), ...
        reorg.wire('#contextFields.y1','#context.u1'), ...
        reorg.wire('#contextFields.y2','#controlMode.u1'),reorg.wire('#controlMode.y1','#context.u2'), ...
        reorg.wire('#contextFields.y3','#flight.u1'),reorg.wire('#flight.y1','#context.u3'), ...
        reorg.wire('#contextFields.y4','#gates.u1'),reorg.wire('#contextFields.y5','#gates.u2'), ...
        reorg.wire('#contextFields.y6','#gates.u3'),reorg.wire('#gates.y1','#context.u4'), ...
        reorg.wire('#context.y1','blk_4325.u3'),reorg.wire('#context.y1','blk_4327.u5')});
end

% 2. ブロックの設定画面と端子に、処理の意味を日本語で示します。
decorate(m,estimator,'水平推定：フロー時刻に同期した角速度積分、ToFと姿勢による投影、品質と鮮度の確認を行います。局所Xは基準機首、Yは右です。');
decorate(m,controller,'水平制御：移動・減速・停止位置保持の速度目標、速度PI、姿勢目標への変換を行います。既存の姿勢・角速度PIDの前段です。');
decorate(m,'blk_2274',get_param(reorg.path(m,'blk_2274'),'Description'));
decorate(m,'blk_2297',get_param(reorg.path(m,'blk_2297'),'Description'));
decorate(m,'blk_3421',get_param(reorg.path(m,'blk_3421'),'Description'));
% 新しいアダプターとSystemブロックにも、設定画面の用途説明を付けます。
children=find_system(m,'LookUnderMasks','all','FollowLinks','off','Type','Block');groups=struct;
for k=1:numel(children)
    b=children{k};id=reorg.id(b);sid=str2double(extractAfter(id,'blk_'));
    if ~isfinite(sid)||sid<4274,continue;end
    parent=get_param(b,'Parent');scope='root';if ~strcmp(parent,m),scope=reorg.id(parent);end
    if strcmp(get_param(b,'BlockType'),'MATLABSystem')
        cls=get_param(b,'System');source=fileread(which(cls));
        overview=regexp(source,'(?m)^\s*%[^\r\n]*','match');
        text=strjoin(overview(1:min(3,numel(overview))),newline);
    else
        text=[get_param(b,'Name') '：水平推定・制御のデータと実行条件を選択・結合します。2軸の順序は局所X（基準機首）、Y（右）です。'];
    end
    if ~isfield(groups,scope),groups.(scope)={};end
    groups.(scope){end+1}=reorg.configure(id,struct('Description',text)); %#ok<AGROW>
end
for scope=fieldnames(groups)',reorg.edit(m,scope{1},groups.(scope{1}));end
logger=find_system(m,'LookUnderMasks','all','BlockType','MATLABSystem','System','basic.ExtendedLogger50');
assert(isscalar(logger));parent=get_param(logger{1},'Parent');
reorg.edit(m,reorg.id(parent),{reorg.configure(reorg.id(logger{1}),struct('FirmwareRevision','uint32(1801)'))});
save_system(m);
% 型が未解決なら先にモデル更新で原因を確認します。
set_param(m,'SimulationCommand','update');
for scope={estimator,controller,'blk_3421','blk_2297','blk_2274','root'}
    disp(model_read(m,scope{1},'0'));reply=char(model_check(m,scope{1},'["all"]'));disp(reply);
    assert(~contains(reply,'severity: error')&&~contains(reply,'status: error'),'horizontal:Connectivity','%s',reply);
end
save_system(m);

% 3. 型と寸法を含むモデル更新が成功してから、構造記録を確定します。
assert(numel(find_system(m,'LookUnderMasks','all','Name','DedicatedPID'))==7);
save_system(m);
command=find_system(reorg.path(m,controller),'LookUnderMasks','all','SearchDepth',1,'BlockType','MATLABSystem','System','horizontal.Command');
assert(isscalar(command));
report=struct('Model',[m '.slx'],'Estimator',estimator,'Controller',controller,'Command',reorg.id(command{1}), ...
    'PreviousMotorSaturation','blk_4313','FlightMotionInput','blk_4303','TakeoffMotionInput','blk_4304', ...
    'AttitudeMotionInput','blk_4314','AttitudeSaturationInput','blk_4315', ...
    'FirmwareRevision',1801,'PIDCount',7,'PhysicalFlightTested',false);
folder=fullfile(root,'build','horizontal_control');save(fullfile(folder,'installation.mat'),'report');
fid=fopen(fullfile(root,'docs','horizontal_control_structure.json'),'w','n','UTF-8');
assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_CONTROL_INSTALLED_AND_UPDATED\n');
end

function decorate(m,id,description)
p=reorg.path(m,id);[inputs,outputs]=reorg.ports(m,id);
display=sprintf('disp(''%s'');',get_param(p,'Name'));
for k=1:numel(inputs),display=[display sprintf('port_label(''input'',%d,''%s'');',k,get_param(reorg.path(m,inputs{k}),'Name'))];end %#ok<AGROW>
for k=1:numel(outputs),display=[display sprintf('port_label(''output'',%d,''%s'');',k,get_param(reorg.path(m,outputs{k}),'Name'))];end %#ok<AGROW>
parent=get_param(p,'Parent');scope='root';if ~strcmp(parent,m),scope=reorg.id(parent);end
reorg.edit(m,scope,{reorg.configure(id,struct('Description',description,'Mask','on', ...
    'MaskDescription',description,'ShowName','off','ShowPortLabels','FromPortBlockName'))});
reorg.edit(m,scope,{reorg.configure(id,struct('MaskDisplay',display))});
end
