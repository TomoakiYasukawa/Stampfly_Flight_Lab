function result = replace_sensor_charts(startIndex)
%REPLACE_SENSOR_CHARTS Replace calculation-only Charts in FlightTest400.
% 配線・ブロック作成は model_edit。MATLAB Function の本文は専用設定API。
root=stampfly_project_root();
if nargin<1,startIndex=1;end
model='StampFly_Official_FlightTest400'; scope='blk_72';
snapshot=load(fullfile(root,'tests','sensor_processing_before.mat'));
result=struct;
for k=startIndex:numel(snapshot.manifest)
    item=snapshot.manifest{k};
    if ismember(item.SID,[117 119 121 125])
        id=standardSubsystem(model,scope,item);
        switch item.SID
            case 117, buildAxis(model,id);
            case 119, buildIMUFilters(model,id);
            case 121, buildVertical(model,id);
            case 125, buildDiagnostics(model,id);
        end
    else
        reply=edit(model,scope,{add('MATLAB Function',[item.Name 'New'],'new',struct)});
        id=created(reply,'new');
        path=resolve(model,id);
        config=get_param(path,'MATLABFunctionConfiguration');
        % MATLAB Function本文はSimulink専用オブジェクトのFunctionScript。
        % model_editはこのプロパティを公開していないため、本文のみ設定。
        config.FunctionScript=item.Script;
        config.SupportVariableSizing=false;
        fn=sfroot().find('-isa','Stateflow.EMChart','Path',path);
        inputs=fn.Inputs; outputs=fn.Outputs;
        assert(numel(inputs)==numel(item.Sources) && numel(outputs)==numel(item.Destinations));
        for j=1:numel(inputs), inputs(j).DataType=item.InputTypes{j}; end
        for j=1:numel(outputs), outputs(j).DataType=item.OutputTypes{j}; end
        reconnect(model,scope,item,id);
    end
    result.(item.Name)=id;
end
notePath=resolve(model,'blk_836');
text=sprintf(['センサー処理 400 Hz：標準SimulinkブロックとMATLAB Function\n' ...
    '軸変換・一次フィルター・診断結合は標準ブロック。校正・Madgwick・ToF・Kalman・フラグは機能別関数。\n' ...
    '前回値・初回処理・待機リセット・single演算順序を旧Chartと比較。飛行状態の遷移は上位で管理。']);
edit(model,scope,{cfg('blk_836',struct('Description',text,'MaskDisplay',['disp(''' strrep(text,newline,'\n') ''')']))});
assert(strcmp(get_param(notePath,'Description'),text));
fprintf('%s\n',model_check(model,scope,'["all"]'));
save_system(model);
save(fullfile(root,'tests','sensor_replacement_ids.mat'),'result');
open_system(resolve(model,scope));
end

function id=standardSubsystem(model,scope,item)
inputNames={'AccelMps2','GyroRps'}; outputNames={'BodyAccelG','BodyGyroRps'};
if item.SID==119
    inputNames={'AccelG','GyroRps','Offset4','Mode','Dt'};
    outputNames={'FilteredAccel3','FilteredGyro3','AccelZDelta'};
elseif item.SID==121
    inputNames={'AccelZDelta','Mode','Dt'};outputNames={'VerticalAccel'};
elseif item.SID==125
    inputNames={'VerticalAccel','KalmanBias','FilteredRange','Offsets4','Count'};
    outputNames={'Diagnostics8'};
end
existing=find_system(resolve(model,scope),'SearchDepth',1,'Name',item.Name);
if ~isempty(existing) && ~strcmp(Simulink.ID.getSID(existing{1}),sprintf('%s:%d',model,item.SID))
    id=bid(existing{1});
    blocks=find_system(existing{1},'SearchDepth',1,'Type','Block');ops={};
    for k=1:numel(blocks)
        if strcmp(blocks{k},existing{1}) || ismember(get_param(blocks{k},'BlockType'),{'Inport','Outport'}),continue;end
        ops{end+1}=struct('op','delete','target',bid(blocks{k}));
    end
    edit(model,id,ops);return
end
reply=edit(model,scope,{struct('op','create_subsystem','name',[item.Name 'New'],'ref','new', ...
    'interface',struct('inputs',{inputNames},'outputs',{outputNames}))});
id=created(reply,'new');
reconnect(model,scope,item,id);
end
function reconnect(model,scope,item,id)
ops={};
for k=1:numel(item.Sources),ops{end+1}=wire(item.Sources{k},sprintf('%s.u%d',id,k));end
for k=1:numel(item.Destinations)
    for j=1:numel(item.Destinations{k}),ops{end+1}=wire(sprintf('%s.y%d',id,k),item.Destinations{k}{j});end
end
ops{end+1}=struct('op','delete','target',['blk_' num2str(item.SID)]);
ops{end+1}=cfg(id,struct('Name',item.Name,'Position',item.Position,'Description',item.Description));
edit(model,scope,ops);
end

function buildAxis(model,id)
[ins,outs]=portIds(model,id);
ops={add('Selector','SwapAccelXY','sa',struct('InputPortWidth','3','Indices','[2 1 3]')), ...
    add('Selector','SwapGyroXY','sg',struct('InputPortWidth','3','Indices','[2 1 3]')), ...
    add('Constant','GravityMps2','gravity',struct('Value','single(9.80665)')), ...
    add('Product','AccelToG','divide',struct('Inputs','*/')), ...
    add('Constant','BodyAxisSigns','sign',struct('Value','single([1;1;-1])')), ...
    add('Product','AccelBodySigns','as',struct('Inputs','**')), ...
    add('Product','GyroBodySigns','gs',struct('Inputs','**')), ...
    wire([ins{1} '.y1'],'#sa.u1'),wire([ins{2} '.y1'],'#sg.u1'), ...
    wire('#sa.y1','#divide.u1'),wire('#gravity.y1','#divide.u2'), ...
    wire('#divide.y1','#as.u1'),wire('#sign.y1','#as.u2'), ...
    wire('#sg.y1','#gs.u1'),wire('#sign.y1','#gs.u2'), ...
    wire('#as.y1',[outs{1} '.u1']),wire('#gs.y1',[outs{2} '.u1'])};
edit(model,id,ops,'full');
end
function buildDiagnostics(model,id)
[ins,outs]=portIds(model,id);
ops={add('DataTypeConversion','CountToSingle','count',struct('OutDataTypeStr','single')), ...
    add('Mux','PackDiagnostics8','pack',struct('Inputs','5'))};
for k=1:4,ops{end+1}=wire([ins{k} '.y1'],sprintf('#pack.u%d',k));end
ops=[ops,{wire([ins{5} '.y1'],'#count.u1'),wire('#count.y1','#pack.u5'),wire('#pack.y1',[outs{1} '.u1'])}];
edit(model,id,ops,'full');
end
function buildVertical(model,id)
[ins,outs]=portIds(model,id);
ops=modeLogic(ins{2});
ops=[ops,{add('Gain','UpwardSign','sign',struct('Gain','single(-1)')), ...
    struct('op','create_subsystem','name','VerticalLowpass','ref','filter', ...
    'interface',struct('inputs',{{'Input','Dt','Reset','Enable'}},'outputs',{{'Filtered'}})), ...
    wire([ins{1} '.y1'],'#sign.u1'),wire('#sign.y1','#filter.u1'), ...
    wire([ins{3} '.y1'],'#filter.u2'),wire('#reset.y1','#filter.u3'), ...
    wire('#enable.y1','#filter.u4'),wire('#filter.y1',[outs{1} '.u1'])}];
reply=edit(model,id,ops,'full');
buildLowpass(model,created(reply,'filter'),.1);
end
function buildIMUFilters(model,id)
[ins,outs]=portIds(model,id);
ops=modeLogic(ins{4});
ops=[ops,{add('Demux','AccelComponents','a',struct('Outputs','3')), ...
    add('Demux','GyroComponents','g',struct('Outputs','3')), ...
    add('Demux','OffsetComponents','off',struct('Outputs','4')), ...
    add('Mux','PackFilteredAccel','af',struct('Inputs','3')), ...
    add('Mux','PackFilteredGyro','gf',struct('Inputs','3')), ...
    wire([ins{1} '.y1'],'#a.u1'),wire([ins{2} '.y1'],'#g.u1'),wire([ins{3} '.y1'],'#off.u1')}];
for k=1:7
    ref=['f' num2str(k)];
    ops{end+1}=struct('op','create_subsystem','name',['Lowpass' num2str(k)],'ref',ref, ...
        'interface',struct('inputs',{{'Input','Dt','Reset','Enable'}},'outputs',{{'Filtered'}}));
    if k<=3
        src=sprintf('#a.y%d',k);
    else
        sumRef=['s' num2str(k)];
        ops{end+1}=add('Sum',['RemoveBias' num2str(k)],sumRef,struct('Inputs','+-'));
        if k<=6,a=sprintf('#g.y%d',k-3);b=sprintf('#off.y%d',k-3);
        else,a='#a.y3';b='#off.y4';end
        ops=[ops,{wire(a,['#' sumRef '.u1']),wire(b,['#' sumRef '.u2'])}];
        src=['#' sumRef '.y1'];
    end
    ops=[ops,{wire(src,['#' ref '.u1']),wire([ins{5} '.y1'],['#' ref '.u2']), ...
        wire('#reset.y1',['#' ref '.u3']),wire('#enable.y1',['#' ref '.u4'])}];
    if k<=3,ops{end+1}=wire(['#' ref '.y1'],sprintf('#af.u%d',k));
    elseif k<=6,ops{end+1}=wire(['#' ref '.y1'],sprintf('#gf.u%d',k-3));
    else,ops{end+1}=wire(['#' ref '.y1'],[outs{3} '.u1']);end
end
ops=[ops,{wire('#af.y1',[outs{1} '.u1']),wire('#gf.y1',[outs{2} '.u1'])}];
reply=edit(model,id,ops,'full');
for k=1:7
    timeConstant=.003;if k==7,timeConstant=.1;end
    buildLowpass(model,created(reply,['f' num2str(k)]),timeConstant);
end
end
function ops=modeLogic(mode)
ops={add('UnitDelay','PreviousMode','previous',struct('SampleTime','.0025','InitialCondition','uint8(0)')), ...
    add('Compare To Constant','ProcessingEnabled','enable',struct('relop','>','const','uint8(1)')), ...
    add('Compare To Constant','IsParking','parking',struct('relop','==','const','uint8(3)')), ...
    add('RelationalOperator','ModeChanged','changed',struct('Operator','~=')), ...
    add('Logic','ResetOnParkingEntry','reset',struct('Operator','AND','Inputs','2')), ...
    wire([mode '.y1'],'#previous.u1'),wire([mode '.y1'],'#enable.u1'),wire([mode '.y1'],'#parking.u1'), ...
    wire([mode '.y1'],'#changed.u1'),wire('#previous.y1','#changed.u2'), ...
    wire('#parking.y1','#reset.u1'),wire('#changed.y1','#reset.u2')};
end
function buildLowpass(model,id,timeConstant)
[ins,outs]=portIds(model,id);
ops={add('UnitDelay','PreviousFiltered','previous',struct('SampleTime','.0025','InitialCondition','single(0)')), ...
    add('Constant','ZeroOnReset','zero',struct('Value','single(0)')), ...
    add('Constant','TimeConstantS','T',struct('Value',sprintf('single(%.17g)',timeConstant))), ...
    add('Switch','ResetPrevious','reset',struct('Criteria','u2 ~= 0')), ...
    add('Sum','Denominator','den',struct('Inputs','++')), ...
    add('Product','PreviousTimesT','oldnum',struct('Inputs','**')), ...
    add('Product','PreviousTerm','oldterm',struct('Inputs','*/')), ...
    add('Product','InputTimesDt','newnum',struct('Inputs','**')), ...
    add('Product','InputTerm','newterm',struct('Inputs','*/')), ...
    add('Sum','UpdatedFiltered','sum',struct('Inputs','++')), ...
    add('Switch','UpdateOrHold','select',struct('Criteria','u2 ~= 0')), ...
    wire('#zero.y1','#reset.u1'),wire([ins{3} '.y1'],'#reset.u2'),wire('#previous.y1','#reset.u3'), ...
    wire('#T.y1','#den.u1'),wire([ins{2} '.y1'],'#den.u2'), ...
    wire('#reset.y1','#oldnum.u1'),wire('#T.y1','#oldnum.u2'), ...
    wire('#oldnum.y1','#oldterm.u1'),wire('#den.y1','#oldterm.u2'), ...
    wire([ins{1} '.y1'],'#newnum.u1'),wire([ins{2} '.y1'],'#newnum.u2'), ...
    wire('#newnum.y1','#newterm.u1'),wire('#den.y1','#newterm.u2'), ...
    wire('#oldterm.y1','#sum.u1'),wire('#newterm.y1','#sum.u2'), ...
    wire('#sum.y1','#select.u1'),wire([ins{4} '.y1'],'#select.u2'),wire('#reset.y1','#select.u3'), ...
    wire('#select.y1','#previous.u1'),wire('#select.y1',[outs{1} '.u1'])};
edit(model,id,ops,'full');
end
function [ins,outs]=portIds(model,id)
path=resolve(model,id);ins=find_system(path,'SearchDepth',1,'BlockType','Inport');outs=find_system(path,'SearchDepth',1,'BlockType','Outport');
[~,order]=sort(cellfun(@(p)str2double(get_param(p,'Port')),ins));ins=cellfun(@bid,ins(order),'UniformOutput',false);
[~,order]=sort(cellfun(@(p)str2double(get_param(p,'Port')),outs));outs=cellfun(@bid,outs(order),'UniformOutput',false);
end
function id=bid(path),id=['blk_' extractAfter(Simulink.ID.getSID(path),':')];end
function path=resolve(model,id),path=Simulink.ID.getFullName([model ':' extractAfter(id,'blk_')]);end
function op=add(type,name,ref,params),op=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);end
function op=wire(a,b),op=struct('op','connect','target',[a ' -> ' b]);end
function op=cfg(target,params),op=struct('op','configure','target',target,'params',params);end
function id=created(reply,ref),token=regexp(reply,[ref ': (blk_\d+)'],'tokens','once');assert(~isempty(token),'No created ID for %s',ref);id=token{1};end
function reply=edit(model,scope,ops,layout)
if nargin<4,layout='incremental';end
model_read(model,scope,'0');reply=char(model_edit(model,scope,jsonencode(ops),layout));
fprintf('%s\n',reply);
if ~startsWith(strtrim(reply),'status: ok')
    disp(model_read(model,scope,'0'));disp(model_check(model,scope,'["all"]'));
    error('official:SensorReplacement','%s',reply);
end
end
