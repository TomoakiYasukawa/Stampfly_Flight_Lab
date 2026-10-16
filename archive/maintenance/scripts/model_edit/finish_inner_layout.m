function finish_inner_layout()
%FINISH_INNER_LAYOUT Arrange student-facing algorithms without changing math.
init_official;m='StampFly_Official_Bench400';
% Keep the main signal processing path wired. Shared mode/reset signals use
% local named Goto/From blocks so each processing stage remains visible.
sensorDirect=[117 572;117 573;572 118;573 118;118 574;118 575;574 119;572 119;573 119;119 576;119 577;119 578;576 570;577 571;570 120;571 120;120 579;120 580;578 121;121 581;122 582;122 583;581 123;582 123;123 584;123 585;123 586;124 587;125 588];
route(m,72,sensorDirect);
sensor={117,'軸・単位の変換','BMI270 → 航空機座標',[320 170 540 270];
118,'静止時の校正','800サンプルでオフセット推定',[850 150 1080 290];
119,'IMU フィルター','校正値を引き一次フィルター',[1420 170 1660 390];
120,'Madgwick 姿勢推定','400 Hz / Roll・Pitch・Yaw',[1990 160 2230 370];
121,'鉛直加速度','重力成分を除去・フィルター',[1990 520 2230 690];
122,'ToF 保持・外れ値処理','新着距離を判定 / 旧値を保持',[1420 830 1660 1030];
123,'高度 Kalman 推定','高度・鉛直速度・バイアス',[2550 630 2790 880];
124,'センサーの状態判定','距離異常・過加速度・低電圧',[3150 160 3400 620];
125,'推定器の診断信号','記録用にまとめる',[3150 930 3400 1190]};
place(m,72,sensor,3690,1370);placeSpecs(m,72);arrangeTags(m,72);
explain(m,72,'400 Hz の推定処理：軸変換 → 静止校正 → フィルター → 姿勢推定。下段は ToF と鉛直加速度から高度・上下速度を推定。各ブロックを個別に差し替え可能。');
% Control chains remain wired; common enable/reset/mode inputs use tags.
direct=[126 142;142 149;149 130;130 143;143 194;194 131;131 465;128 136;136 144;136 145;137 144;137 145;144 239;145 284;239 129;284 129;129 139;139 146;139 147;139 148;138 146;138 147;138 148;146 329;147 374;148 419;329 465;374 465;419 465;465 105;465 106];
route(m,92,direct);
control={126,'離陸・着陸の指令','目標高度 / 基準推力 / カウンター',[330 170 570 540];
553,'飛行モードの確定','着陸終了・Flip・過加速度',[330 760 570 1070];
127,'制御の有効化とリセット','各 PID の実行条件を決める',[900 150 1160 710];
128,'スティック → 姿勢・角速度','Stabilize / Sport / Flip',[1540 600 1800 1050];
149,'高度 PID','高度誤差 → 上下速度指令',[1040 1210 1260 1480];
130,'鉛直速度の指令選択','自動高度 / 着陸 -0.15 m/s',[1540 1220 1800 1450];
194,'鉛直速度 PID','速度誤差 → 推力補正',[2070 1210 2310 1480];
131,'推力補正と制限','基準推力 / フィルター / 上下限',[2600 1220 2860 1700];
239,'Roll 姿勢 PID','角度誤差 → Roll 角速度',[2070 170 2310 440];
284,'Pitch 姿勢 PID','角度誤差 → Pitch 角速度',[2070 630 2310 900];
129,'角速度指令の選択','姿勢 PID / Sport / Flip',[2610 400 2850 670];
329,'Roll 角速度 PID','角速度誤差 → モーター差分',[3160 160 3400 430];
374,'Pitch 角速度 PID','角速度誤差 → モーター差分',[3160 620 3400 890];
419,'Yaw 角速度 PID','角速度誤差 → モーター差分',[3160 1080 3400 1350];
465,'モーター配分・フィルター','4ch / Duty 0〜0.95 / 8 bit',[3800 400 4070 900];
132,'制御の診断信号','目標・補正量・配分前出力',[3800 1210 4070 1720]};
place(m,92,control,4510,1850);
other={142,[790 1240 830 1280];143,[1960 1240 2000 1280];136,[1900 680 1905 770];137,[1900 1010 1905 1100];144,[1960 205 2000 245];145,[1960 665 2000 705];139,[2960 500 2965 610];138,[2960 830 2965 940];146,[3050 200 3090 240];147,[3050 660 3090 700];148,[3050 1120 3090 1160]};
ops={};for k=1:size(other,1),ops{end+1}=conf(id(other{k,1}),struct('Position',other{k,2},'ShowName','off'));end;edit(m,92,ops);arrangeTags(m,92);
explain(m,92,'400 Hz の制御：高度 PID → 鉛直速度 PID → 共通推力。姿勢 PID → 角速度 PID → 4モーター配分。各 PID 内部は Sum / Gain / Unit Delay。共有の実行・リセット条件は名前付き信号で接続。');
notes={530,'公式の状態監督：INIT=0 → AVERAGE=1 → PARKING=3 → FLIGHT=2。ボタン・通信喪失・センサー状態に応じて LANDING=5 へ遷移。押下・解放の判定順を公式と一致させる。';
531,'公式 Flip：ボタンで開始し、推力・Roll角速度を段階的に切り替える。完了・中断時の保持値と推定器のリセットを公式の順に出力。USBベンチでは実モーター出力ゼロ。';
676,'LED・ブザー：校正、待機、飛行、低電圧、通信異常とモード変更を表示。色・周波数・再起動判定はモデル内。ハードウェアブロックは受け取った値だけを出力。';
700,'公式 JoyStick 用のテレメトリ：姿勢・角速度・PID診断・電圧・高度などを公式の順に整列。40 Hz ブロックがパケットを送信キューへ入れる。'};
for k=1:size(notes,1),chartNote(m,notes{k,1},notes{k,2});end
% Move status/telemetry fan-ins clear of the control block's output tags.
ops={conf('blk_666',struct('Position',[1250 610 1500 920])),conf('blk_681',struct('Position',[1250 1020 1500 1550])),conf('blk_640',struct('Position',[610 1020 900 1610])),conf('blk_4',struct('Position',[100 1840 340 1960])),conf('blk_13',struct('Position',[630 1850 760 1900])),conf('blk_17',struct('Position',[1250 1800 1500 2000]))};
edit(m,'root',ops);arrangeTags(m,'root');
for scope=[72 92],disp(model_check(m,id(scope),'["all"]'));end
disp(model_check(m,'root','["all"]'));save_system(m);
for sid=[72 92],p=resolve(m,sid);print(['-s' p],'-dpng','-r110',fullfile(pwd,'logs',['student_layout_' num2str(sid) '.png']));end
print(['-s' m],'-dpng','-r110',fullfile(pwd,'logs','bench_model_readable.png'));
end
function place(m,sid,main,right,bottom)
p=resolve(m,sid);blocks=find_system(p,'SearchDepth',1,'Type','Block');ops={};ni=0;no=0;nx=0;
for k=1:numel(blocks)
 if strcmp(blocks{k},p),continue;end
 n=str2double(extractAfter(Simulink.ID.getSID(blocks{k}),':'));idx=find(cellfun(@(x)isequal(x,n),main(:,1)),1);
 if ~isempty(idx)
  params=icon(main{idx,2},main{idx,3},main{idx,4});
  if ~isempty(sfroot().find('-isa','Stateflow.Chart','Path',blocks{k}))
   params=rmfield(params,{'Mask','MaskDisplay','MaskIconOpaque','ShowPortLabels'});
   params.AttributesFormatString=[main{idx,2} newline main{idx,3}];
  end
  ops{end+1}=conf(id(n),params);continue;
 end
 switch get_param(blocks{k},'BlockType')
 case 'Inport',ni=ni+1;pos=[30 180+ni*50 60 200+ni*50];
 case 'Outport',no=no+1;pos=[right 180+no*70 right+30 200+no*70];
 case {'From','Goto','SignalSpecification'},continue;
 otherwise,nx=nx+1;pos=[320+mod(nx-1,7)*480 bottom+floor((nx-1)/7)*120 420+mod(nx-1,7)*480 bottom+60+floor((nx-1)/7)*120];
 end
 ops{end+1}=conf(id(n),struct('Position',pos,'AttributesFormatString',''));
end;edit(m,sid,ops);
end
function placeSpecs(m,sid)
p=resolve(m,sid);specs=find_system(p,'SearchDepth',1,'BlockType','SignalSpecification');ops={};
for k=1:numel(specs)
 h=get_param(specs{k},'PortHandles');line=get_param(h.Inport,'Line');q=get_param(get_param(line,'SrcPortHandle'),'Position');
 ops{end+1}=conf(bid(specs{k}),struct('Position',[q(1)+20 q(2)-8 q(1)+80 q(2)+8],'ShowName','off','AttributesFormatString','','FontSize','7'));
end;edit(m,sid,ops);
end
function route(m,sid,direct)
p=resolve(m,sid);blocks=find_system(p,'SearchDepth',1,'Type','Block');ops={};n=0;
for k=1:numel(blocks)
 if strcmp(blocks{k},p)||ismember(get_param(blocks{k},'BlockType'),{'Goto','From'}),continue;end
 src=bid(blocks{k});s=str2double(extractAfter(src,'blk_'));h=get_param(blocks{k},'PortHandles');
 for j=1:numel(h.Outport)
  line=get_param(h.Outport(j),'Line');if line<0,continue;end;dst=get_param(line,'DstPortHandle');dst=dst(dst>0);
  if isempty(dst)||any(arrayfun(@(x)strcmp(get_param(get_param(x,'Parent'),'BlockType'),'Goto'),dst)),continue;end
  tag=label(m,blocks{k},j);n=n+1;gref=['g' num2str(n)];added=false;
  for z=1:numel(dst)
   dpath=get_param(dst(z),'Parent');d=str2double(extractAfter(bid(dpath),'blk_'));if any(direct(:,1)==s & direct(:,2)==d),continue;end
   if ~added,ops{end+1}=struct('op','add_block','type','Goto','name',['Send_' tag],'ref',gref,'params',struct('GotoTag',tag,'TagVisibility','local','ShowName','off'));ops{end+1}=wire(sprintf('%s.y%d',src,j),['#' gref '.u1']);added=true;end
   fref=[gref 'f' num2str(z)];ops{end+1}=struct('op','add_block','type','From','name',['Read_' tag '_' num2str(z)],'ref',fref,'params',struct('GotoTag',tag,'ShowName','off'));ops{end+1}=wire(['#' fref '.y1'],sprintf('%s.u%d',bid(dpath),get_param(dst(z),'PortNumber')));
  end
 end
end;if ~isempty(ops),edit(m,sid,ops);end
end
function tag=label(m,p,j)
names=get_param(p,'OutputSignalNames');name=get_param(p,'Name');
chart=sfroot().find('-isa','Stateflow.Chart','Path',p);
if ~isempty(chart),out=chart.find('-isa','Stateflow.Data','Scope','Output');for k=1:numel(out),if out(k).Port==j,name=out(k).Name;end;end
elseif strcmp(get_param(p,'BlockType'),'SubSystem'),out=find_system(p,'SearchDepth',1,'BlockType','Outport');for k=1:numel(out),if str2double(get_param(out{k},'Port'))==j,name=get_param(out{k},'Name');end;end
elseif numel(names)>=j && ~isempty(names{j}),name=names{j};end
if strcmp(get_param(p,'BlockType'),'SignalSpecification'),h=get_param(p,'PortHandles');line=get_param(h.Inport,'Line');src=get_param(line,'SrcPortHandle');name=label(m,get_param(src,'Parent'),get_param(src,'PortNumber'));tag=name;return;end
tag=[matlab.lang.makeValidName(name) '_S' extractAfter(bid(p),'blk_') 'P' num2str(j)];
end
function arrangeTags(m,sid)
if ischar(sid),p=m;else,p=resolve(m,sid);end;ops={};
for type={'Goto','From'}
 list=find_system(p,'SearchDepth',1,'BlockType',type{1});
 for k=1:numel(list)
  h=get_param(list{k},'PortHandles');
  if strcmp(type{1},'Goto'),line=get_param(h.Inport,'Line');q=get_param(get_param(line,'SrcPortHandle'),'Position');pos=[q(1)+22 q(2)-8 q(1)+162 q(2)+8];
  else,line=get_param(h.Outport,'Line');dst=get_param(line,'DstPortHandle');q=get_param(dst(1),'Position');pos=[q(1)-170 q(2)-8 q(1)-22 q(2)+8];end
  ops{end+1}=conf(bid(list{k}),struct('Position',pos,'FontSize','8'));
 end
end;edit(m,sid,ops);
end
function explain(m,sid,text)
p=resolve(m,sid);b=find_system(p,'SearchDepth',1,'Name','ModelExplanation');assert(numel(b)==1);
params=icon('説明',text,[320 15 3400 105]);params.MaskIconFrame='off';params.ShowName='off';params.Description=text;edit(m,sid,{conf(bid(b{1}),params)});
end
function chartNote(m,sid,text)
p=resolve(m,sid);c=sfroot().find('-isa','Stateflow.Chart','Path',p);a=c.find('-isa','Stateflow.Annotation');
if isempty(a),op=struct('op','add_block','type','Annotation','ref','JapaneseExplanation','params',struct('Text',text,'Position',[30 450 650 100]));else,op=conf(['sf_' num2str(sid) ':' num2str(a(1).SSIdNumber)],struct('Text',text));end
edit(m,sid,{op});disp(model_check(m,id(sid),'["stateflow_lint"]'));
end
function p=icon(title,text,pos)
t=char(strrep([title newline text],"'","''"));t=strrep(t,newline,'\n');p=struct('Mask','on','MaskDisplay',['disp(''' t ''')'],'MaskIconOpaque','opaque','ShowPortLabels','FromPortBlockName','Position',pos,'AttributesFormatString','','FontSize','10','Description',text);
end
function r=edit(m,sid,ops)
if isnumeric(sid),scope=id(sid);else,scope=sid;end
model_read(m,scope,'0');r=char(model_edit(m,scope,jsonencode(ops),'incremental'));if ~startsWith(strtrim(r),'status: ok'),disp(model_read(m,scope,'0'));disp(model_check(m,scope,'["all"]'));error('official:LayoutEdit','%s',r);end
end
function p=resolve(m,sid),p=Simulink.ID.getFullName([m ':' num2str(sid)]);end
function x=id(sid),x=['blk_' num2str(sid)];end
function x=bid(p),x=['blk_' extractAfter(Simulink.ID.getSID(p),':')];end
function o=conf(target,params),o=struct('op','configure','target',target,'params',params);end
function o=wire(a,b),o=struct('op','connect','target',[a ' -> ' b]);end
