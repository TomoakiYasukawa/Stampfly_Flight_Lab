function finish_student_layout()
%FINISH_STUDENT_LAYOUT Japanese explanations, named ports and visible data flow.
init_official;m='StampFly_Official_Bench400';
renamePorts(m,612,{'FinalMode'},{'Stick6','Accel3','Gyro3','IMUFresh','BottomMm','ToFNew','ToFStatus','BatteryV','BatteryValid','ToFInfo4','FrontMm','ArmButton','NewPacket','AHRSFlag','FlipButton','PacketError','Temperature'});
renamePorts(m,604,{'Counts4'},{'AppliedCounts4','PWMInfo4'});
renamePorts(m,640,{'Accel3','Gyro3','IMUFresh','TimeSec','BottomMm','ToFNew','ToFStatus','BatteryV','BatteryValid','Duty4','Mode','Attitude3','Height','Velocity','ControlDiag17','SensorDiag8','ToFInfo4'},{'USBDrops','RadioQueued','LEDMode'});
renamePorts(m,666,{'Stick6','SensorFlags3','ModeBeforeTick','AltFlag','FlipFlag','PacketError','AHRSFlag'},{});
renamePorts(m,681,{'AltFlag','Mode','FrontMm','TimeSec','Dt','Attitude3','Rates3','ControlDiag17','Accel3','BatteryV','Duty4','Height','SensorDiag8','Velocity'},{'Sent'});
edit(m,'blk_38',{configure('blk_48',struct('Name','NewPacket','Description','新しいJoyStickパケットをこの周期で受信したか。通信中のフラグとは異なります。'))});
% Replace bench root diagnostic fanout with one named virtual bus.
out=find_system(m,'SearchDepth',1,'BlockType','Outport');
if numel(out)>1
 [~,order]=sort(cellfun(@(x)str2double(get_param(x,'Port')),out));out=out(order);
 labels=cellfun(@(x)get_param(x,'Name'),out,'UniformOutput',false);sources=cell(size(out));
 for k=1:numel(out),p=get_param(out{k},'PortHandles');line=get_param(p.Inport,'Line');src=get_param(line,'SrcPortHandle');sources{k}=sprintf('%s.y%d',bid(get_param(src,'Parent')),get_param(src,'PortNumber'));end
 reply=edit(m,'root',{struct('op','create_subsystem','name','DiagnosticBus400','ref','diag','interface',struct('inputs',{labels},'outputs',{{'Diagnostics'}}))});diag=created(reply,'diag');
 path=resolve(m,diag);ins=ports(path,'Inport');outs=ports(path,'Outport');ops={struct('op','add_block','type','BusCreator','name','NamedDiagnosticBus','ref','bus','params',struct('Inputs',num2str(numel(ins))))};
 for k=1:numel(ins),ops{end+1}=wire([bid(ins{k}) '.y1'],sprintf('#bus.u%d',k),struct('Name',labels{k}));end
 ops{end+1}=wire('#bus.y1',[bid(outs{1}) '.u1']);edit(m,diag,ops);
 ops={};for k=1:numel(out),ops{end+1}=wire(sources{k},sprintf('%s.u%d',diag,k));ops{end+1}=struct('op','delete','target',bid(out{k}));end
 ops{end+1}=struct('op','add_block','type','Outport','name','Diagnostics','ref','out','params',struct('Port','1'));
 ops{end+1}=wire([diag '.y1'],'#out.u1');ops{end+1}=struct('op','delete','target','blk_565');ops{end+1}=struct('op','delete','target','blk_566');edit(m,'root',ops);
else
 path=find_system(m,'SearchDepth',1,'Name','DiagnosticBus400');diag=bid(path{1});
end
% Compact opaque icons prevent the model editor drawing subsystem contents.
items={612,'センサーと操作入力','400 Hz 取得 / ToF 最新値',[120 120 340 560];38,'姿勢・高度と飛行制御','400 Hz / 内部を個別編集',[610 120 865 560];604,'モーター出力','150 kHz / 8 bit / 出力ゼロ',[1150 150 1390 260]; ...
640,'データロガー','50 Hz / SFI8 / MAT 保存',[610 740 865 1170];666,'LED とブザー','400 Hz 判断 / 送出キュー',[1150 400 1390 620];681,'JoyStick へ返信','40 Hz / 公式パケット',[1150 760 1390 1110]};
ops={};for k=1:size(items,1),ops{end+1}=configure(['blk_' num2str(items{k,1})],icon(items{k,2},items{k,3},items{k,4}));end
ops{end+1}=configure(diag,icon('観測・診断バス','名前付き信号 / 400 Hz',[1630 120 1890 560]));
ops{end+1}=configure('blk_4',struct('Position',[100 1320 300 1400],'AttributesFormatString','','Description','GPTimer 2500 usで起動。実際のDtとタイマー診断を出力。'));
ops{end+1}=configure('blk_13',struct('Position',[450 1330 520 1370]));ops{end+1}=configure('blk_17',struct('Position',[1150 1280 1390 1420]));
rootOut=find_system(m,'SearchDepth',1,'BlockType','Outport');ops{end+1}=configure(bid(rootOut{1}),struct('Position',[2010 320 2040 340]));edit(m,'root',ops);
% Retain two direct links for the main left-to-right pipeline. Other fanouts
% use local Goto/From tags so reading a signal name replaces tracing long wires.
routeTags(m,'root',{'blk_612','blk_38','blk_604'},[612 38;38 604]);
arrangeTags(m,'root');
notes={38,'センサー入力 → 推定 → 状態管理 → PID → モーター指令。各ブロックを個別に編集できます。';
72,'400 Hz：軸変換 → 800点校正 → フィルター → Madgwick姿勢推定。下向きToFの保持値と鉛直加速度から高度Kalmanを更新。';
92,'高度PID → 鉛直速度PID、および姿勢角PID → 角速度PID。PID内部はSum / Gain / Unit Delayなどの標準ブロック。';
604,'入力 Counts4 は FR / FL / RR / RL。LEDCキャリア150 kHz指定・8 bit、指令更新400 Hz。ベンチは定数Enable=falseとAllowMotorOutput=falseで実出力ゼロ。';
612,'BMI270のODR400 Hz。下向きToFは33 ms、ready確認とcore0取得で最新値を保持。前向きToFは無効、Optical Flowは未実装。JoyStickは公式25 byteパケットを受信。';
640,'stampfly_imu_monitorのSFI8形式とMATロガーをコピー。400 Hz信号を50 Hzで保存。Optical Flowは未実装のためNaN。計算Dutyと実適用値は別。';
666,'公式のモード・姿勢制御方式・高度制御・Flip・低電圧・通信エラーからLED色とブザー周波数を決定。ハードウェアはキュー送出のみ。';
681,'公式JoyStickへ40 Hzで姿勢・高度・電圧等を返信。前向きToFは無効で0を返信。'};
for k=1:size(notes,1),scope=['blk_' num2str(notes{k,1})];note(m,scope,notes{k,2});end
% Readable subsystem icons while preserving their separate functions.
for sid=[72 92 149 194 239 284 329 374 419 465]
 p=resolve(m,['blk_' num2str(sid)]);parent=get_param(p,'Parent');
 edit(m,scopeId(m,parent),{configure(bid(p),icon(get_param(p,'Name'),'ダブルクリックで内部を編集',get_param(p,'Position')))});
end
% Simplify the critical two inner scopes without changing delays or arithmetic.
routeTags(m,'blk_38',{},zeros(0,2));simpleLayout(m,'blk_38',{72,[300 180 560 530];530,[840 180 1050 360];531,[840 570 1050 760];92,[1350 180 1640 720]});
arrangeTags(m,'blk_38');
note(m,'root',sprintf('StampFly 公式制御：学生用の機能別モデル\n基本周期 0.0025 s（400 Hz） / PWM 150 kHz指定・8 bit\nUSBベンチ：バッテリー・プロペラなし、実モーター出力ゼロ\n左からセンサー取得 → 推定・制御 → モーター出力。下段は記録・通信・状態表示。'));
% Apply final positions after structural edits and automatic layout are complete.
ops={};for k=1:size(items,1),ops{end+1}=configure(['blk_' num2str(items{k,1})],icon(items{k,2},items{k,3},items{k,4}));end
ops{end+1}=configure(diag,icon('観測・診断バス','名前付き信号 / 400 Hz',[1630 120 1890 560]));
ops{end+1}=configure('blk_4',struct('Position',[100 1320 300 1400]));ops{end+1}=configure('blk_13',struct('Position',[450 1330 520 1370]));ops{end+1}=configure('blk_17',struct('Position',[1150 1280 1390 1420]));
ops{end+1}=configure(bid(rootOut{1}),struct('Position',[2010 320 2040 340]));edit(m,'root',ops);arrangeTags(m,'root');
renameExistingTags(m,'root');
model_check(m,'root','["all"]');save_system(m);open_system(m);
print(['-s' m],'-dpng','-r130',fullfile(stampfly_project_root(),'logs','bench_model_readable.png'));
end
function renamePorts(m,sid,inNames,outNames)
 id=['blk_' num2str(sid)];p=resolve(m,id);ins=ports(p,'Inport');outs=ports(p,'Outport');assert(numel(ins)==numel(inNames)&&numel(outs)==numel(outNames));ops={};
 for k=1:numel(ins),ops{end+1}=configure(bid(ins{k}),struct('Name',inNames{k}));end
 for k=1:numel(outs),ops{end+1}=configure(bid(outs{k}),struct('Name',outNames{k}));end
 edit(m,id,ops);
end
function routeTags(m,scope,unused,direct) %#ok<INUSD>
 if strcmp(scope,'root'),p=m;else,p=resolve(m,scope);end
 blocks=find_system(p,'SearchDepth',1,'Type','Block');ops={};number=0;
 for k=1:numel(blocks)
  if strcmp(blocks{k},p)||ismember(get_param(blocks{k},'BlockType'),{'Goto','From'}),continue;end
  h=get_param(blocks{k},'PortHandles');
  for j=1:numel(h.Outport)
   line=get_param(h.Outport(j),'Line');if line<0,continue;end
   dst=get_param(line,'DstPortHandle');dst=dst(dst>0);if isempty(dst),continue;end
   if any(arrayfun(@(x)strcmp(get_param(get_param(x,'Parent'),'BlockType'),'Goto'),dst)),continue;end
   src=bid(blocks{k});tag=['S' extractAfter(src,'blk_') 'P' num2str(j)];
   names=get_param(blocks{k},'OutputSignalNames');
   if strcmp(get_param(blocks{k},'BlockType'),'SubSystem') && isempty(sfroot().find('-isa','Stateflow.Chart','Path',blocks{k}))
    outputBlocks=ports(blocks{k},'Outport');if numel(outputBlocks)>=j,names{j}=get_param(outputBlocks{j},'Name');end
   end
   if numel(names)>=j && ~isempty(names{j}),tag=[matlab.lang.makeValidName(names{j}) '_S' extractAfter(src,'blk_') 'P' num2str(j)];end
   number=number+1;ref=['g' num2str(number)];createdGoto=false;
   for n=1:numel(dst)
    dpath=get_param(dst(n),'Parent');did=bid(dpath);sid=str2double(extractAfter(src,'blk_'));dsid=str2double(extractAfter(did,'blk_'));
    if any(direct(:,1)==sid & direct(:,2)==dsid),continue;end
    if ~createdGoto
     ops{end+1}=struct('op','add_block','type','Goto','name',['Send_' tag],'ref',ref,'params',struct('GotoTag',tag,'TagVisibility','local','ShowName','off'));ops{end+1}=wire(sprintf('%s.y%d',src,j),['#' ref '.u1']);createdGoto=true;
    end
    fref=[ref 'f' num2str(n)];ops{end+1}=struct('op','add_block','type','From','name',['Read_' tag '_' num2str(n)],'ref',fref,'params',struct('GotoTag',tag,'ShowName','off'));
    ops{end+1}=wire(['#' fref '.y1'],sprintf('%s.u%d',did,get_param(dst(n),'PortNumber')));
   end
  end
 end
 if ~isempty(ops),edit(m,scope,ops);end
end
function arrangeTags(m,scope)
 if strcmp(scope,'root'),p=m;else,p=resolve(m,scope);end
 ops={};g=find_system(p,'SearchDepth',1,'BlockType','Goto');f=find_system(p,'SearchDepth',1,'BlockType','From');
 for k=1:numel(g),h=get_param(g{k},'PortHandles');line=get_param(h.Inport,'Line');src=get_param(line,'SrcPortHandle');q=get_param(src,'Position');ops{end+1}=configure(bid(g{k}),struct('Position',[q(1)+22 q(2)-8 q(1)+165 q(2)+8],'FontSize','8'));end
 for k=1:numel(f),h=get_param(f{k},'PortHandles');line=get_param(h.Outport,'Line');dst=get_param(line,'DstPortHandle');q=get_param(dst(1),'Position');ops{end+1}=configure(bid(f{k}),struct('Position',[q(1)-170 q(2)-8 q(1)-22 q(2)+8],'FontSize','8'));end
 edit(m,scope,ops);
end
function simpleLayout(m,scope,main)
 p=resolve(m,scope);blocks=find_system(p,'SearchDepth',1,'Type','Block');ops={};rowIn=0;rowOut=0;rowMem=0;
 for k=1:numel(blocks)
  if strcmp(blocks{k},p),continue;end
  id=bid(blocks{k});sid=str2double(extractAfter(id,'blk_'));idx=find(cellfun(@(x)isequal(x,sid),main(:,1)),1);
  if ~isempty(idx),pos=main{idx,2};
  else
   switch get_param(blocks{k},'BlockType')
    case 'Inport',rowIn=rowIn+1;pos=[60 100+rowIn*40 90 120+rowIn*40];
    case 'Outport',rowOut=rowOut+1;pos=[1860 100+rowOut*40 1890 120+rowOut*40];
    case {'Goto','From'},continue;
    otherwise,rowMem=rowMem+1;pos=[300+mod(rowMem-1,5)*290 950+floor((rowMem-1)/5)*120 420+mod(rowMem-1,5)*290 1010+floor((rowMem-1)/5)*120];
   end
  end
  ops{end+1}=configure(id,struct('Position',pos,'AttributesFormatString',''));
 end
 edit(m,scope,ops);
end
function note(m,scope,text)
 if strcmp(scope,'root'),p=m;else,p=resolve(m,scope);end
 rt=sfroot;chart=rt.find('-isa','Stateflow.Chart','Path',p);
 if ~isempty(chart),edit(m,scope,{struct('op','add_block','type','Annotation','ref','note','params',struct('Text',text))});
 else
  % Simulink annotations are diagram documentation, created through model_edit.
  name='ModelExplanation';existing=find_system(p,'SearchDepth',1,'Name',name);
  if isempty(existing)
   r=edit(m,scope,{struct('op','create_subsystem','name',name,'ref','note','interface',struct('inputs',{{}},'outputs',{{}}))});id=created(r,'note');
  else,id=bid(existing{1});end
  params=icon('説明',text,[80 15 1300 95]);params.Description=text;params.ShowName='off';params.MaskIconFrame='off';params.BackgroundColor='white';
  edit(m,scope,{configure(id,params)});
 end
end
function renameExistingTags(m,scope)
 if strcmp(scope,'root'),p=m;else,p=resolve(m,scope);end
 tags=find_system(p,'SearchDepth',1,'BlockType','Goto');ops={};
 for k=1:numel(tags)
  h=get_param(tags{k},'PortHandles');line=get_param(h.Inport,'Line');src=get_param(line,'SrcPortHandle');path=get_param(src,'Parent');port=get_param(src,'PortNumber');
  old=get_param(tags{k},'GotoTag');name=get_param(path,'Name');
  if strcmp(get_param(path,'BlockType'),'SubSystem') && isempty(sfroot().find('-isa','Stateflow.Chart','Path',path))
   outs=ports(path,'Outport');name=get_param(outs{port},'Name');
  end
  if strcmp(get_param(path,'Name'),'TickStart400'),labels={'StartUs','Dt','Scheduler'};name=labels{port};end
  tag=[matlab.lang.makeValidName(name) '_S' extractAfter(bid(path),'blk_') 'P' num2str(port)];
  ops{end+1}=configure(bid(tags{k}),struct('GotoTag',tag));
  f=find_system(p,'SearchDepth',1,'BlockType','From','GotoTag',old);for j=1:numel(f),ops{end+1}=configure(bid(f{j}),struct('GotoTag',tag));end
 end
 edit(m,scope,ops);
end
function p=icon(title,subtitle,pos)
 title=strrep(strrep(title,"'","''"),newline,'\n');subtitle=strrep(strrep(subtitle,"'","''"),newline,'\n');
 p=struct('Mask','on','MaskDisplay',['disp(''' title '\n' subtitle ''')'],'MaskIconOpaque','opaque','ShowPortLabels','FromPortBlockName','Position',pos,'AttributesFormatString','','FontSize','10');
end
function list=ports(p,type),list=find_system(p,'SearchDepth',1,'BlockType',type);[~,i]=sort(cellfun(@(x)str2double(get_param(x,'Port')),list));list=list(i);end
function id=bid(p),id=['blk_' extractAfter(Simulink.ID.getSID(p),':')];end
function p=resolve(m,id),p=Simulink.ID.getFullName([m ':' extractAfter(id,'blk_')]);end
function id=scopeId(m,p),if strcmp(p,m),id='root';else,id=bid(p);end;end
function op=configure(id,params),op=struct('op','configure','target',id,'params',params);end
function op=wire(a,b,params),op=struct('op','connect','target',[a ' -> ' b]);if nargin>2,op.params=params;end;end
function id=created(r,ref),t=regexp(r,[ref ': (blk_\d+)'],'tokens','once');id=t{1};end
function r=edit(m,scope,ops)
 model_read(m,scope,'0');r=char(model_edit(m,scope,jsonencode(ops),'incremental'));
 if ~startsWith(strtrim(r),'status: ok'),disp(model_read(m,scope,'0'));disp(model_check(m,scope,'["all"]'));error('official:LayoutEdit','%s',r);end
end
