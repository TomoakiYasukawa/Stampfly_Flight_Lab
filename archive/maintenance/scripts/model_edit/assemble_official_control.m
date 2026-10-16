function assemble_official_control()
%ASSEMBLE_OFFICIAL_MODULAR Build editable algorithms inside the Simulink file.
root=stampfly_project_root();addpath(root,fullfile(root,'models'));init_official;
model='StampFly_Official_Bench400';open_system(stampfly_model_file(model));
assert(library.settingsLookup().gatePass);
scope='blk_92';
cmd=chart(model,scope,'TakeoffLandingCommand',{'stick','single';'height','single';'voltage','single';'rangeFlag','uint8';'mode','uint8'},{'alt','single';'base','single';'counter','uint16';'raw','single';'auto','boolean';'manual','boolean'},strjoin({'function [alt,base,counter,raw,auto,manual]=stepFn(stick,height,voltage,rangeFlag,mode)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','persistent Alt Base Counter RangeOld Landing History;','if isempty(Alt)','Alt=single(.5);','Base=single(0);','Counter=uint16(0);','RangeOld=uint8(0);','Landing=false;','History=zeros(10,1,''single'');','end','            raw=single(0);auto=false;manual=false;','            if mode==3','                Base=single(0);Alt=single(0.5);Counter=uint16(0);Landing=false;','            elseif mode==2','                if uint8(stick(6))==4','                    auto=true;','                    if Counter<uint16(500)','                        Base=min(single(Counter)/single(1000),trim(single(3.8)));Counter=Counter+uint16(1);','                    elseif Counter<uint16(1000)','                        Base=min(single(Counter)/single(1000),trim(voltage));Counter=Counter+uint16(1);','                    else,Base=trim(voltage);end','                    th=stick(4);if th>single(-.2) && th<single(.2),th=single(0);end','                    Alt=min(max(single(double(Alt)+double(th)*.001),single(0.05)),single(1.8));','                    if rangeFlag>RangeOld || rangeFlag==20,Base=Base-single(.02);RangeOld=rangeFlag;end','                    raw=single(double(Base)*3.7);','                else','                    manual=true;th=min(max(stick(4),single(0)),single(1));','                    if th>single(-.2) && th<single(.2),th=single(0);end','                    raw=single((.00413+double(single(3.3)*th-single(5.44)*th*th+single(3.13)*th*th*th))*3.7);','                end','            elseif mode==5','                if ~Landing,Landing=true;History(:)=height;Base=trim(voltage);end','                if History(10)>=height,Base=single(double(Base)*.9999);end','                if height<single(.15),Base=single(double(Base)*.999);end','                for j=2:10,History(j)=History(j-1);end','                History(1)=height;','            end','            alt=Alt;base=Base;counter=Counter;','end','','function y=trim(v)','y=-single(.2448)*v+single(1.5892);','end'},newline),'[alt,base,counter,raw,auto,manual]=stepFn(stick,height,voltage,rangeFlag,mode);');
gates=chart(model,scope,'ControlEnableReset',{'raw','single';'manual','boolean';'auto','boolean';'mode','uint8';'controlMode','single';'dt','single';'oldFilter','single';'lastThrust','single'},{'command','single';'run','boolean';'reset','boolean';'altEnable','boolean';'angleEnable','boolean';'velEnable','boolean'},strjoin({'function [command,run,reset,altEnable,angleEnable,velEnable]=stepFn(raw,manual,auto,mode,controlMode,dt,oldFilter,lastThrust)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','            command=raw;','            if manual,command=filterStep(raw,dt,single(.01),oldFilter);end','            if mode==5 || mode==3,command=lastThrust;end','            active=mode==2 || mode==5;reset=active && double(command)/3.7<double(single(.1));run=active && ~reset;','            altEnable=run && auto;angleEnable=run && uint8(controlMode)==0;velEnable=run && (auto || mode==5);','end','','function s = filterStep(u,h,T,s)','%FILTERSTEP Exact Filter::update, including operation ordering.','%#codegen','s = s*T/(T+h) + u*h/(T+h);','end'},newline),'[command,run,reset,altEnable,angleEnable,velEnable]=stepFn(raw,manual,auto,mode,controlMode,dt,oldFilter,lastThrust);');
targets=chart(model,scope,'StickToAngleRate',{'stick','single';'mode','uint8';'run','boolean';'reset','boolean'},{'angle','single';'directRate','single';'resetError','single'},strjoin({'function [angle,directRate,resetError]=stepFn(stick,mode,run,reset)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','persistent Angle Centers;','if isempty(Angle)','Angle=zeros(2,1,''single'');','Centers=zeros(3,1,''single'');','end','            angleCmd=min(max(single(.4*double(stick(1:2))),single(-1)),single(1));yawCmd=min(max(stick(3),single(-1)),single(1));','            resetError=Angle;directRate=zeros(3,1,''single'');','            if reset,Centers(1:2)=angleCmd;Centers(3)=yawCmd;end','            if run','                directRate(3)=single(2*pi*double(yawCmd-Centers(3)));','                if uint8(stick(5))==1,directRate(1)=rateCommand(stick(1));directRate(2)=rateCommand(stick(2));end','                if uint8(stick(5))==0','                    limit=single(30*pi/180);Angle=min(max(single(.5*pi*double(angleCmd-Centers(1:2))),-limit),limit);','                end','            end','            angle=Angle;','            if mode<2,directRate(:)=single(0);end','end','','function y=rateCommand(x)','x=min(max(x,single(-1)),single(1));a=abs(x);t=a*(a*a*a*a*a*single(.5)+a*single(.5));','y=single(pi/180)*((single(1600)-single(70))*t+single(70)*a);if x<0,y=-y;end','end'},newline),'[angle,directRate,resetError]=stepFn(stick,mode,run,reset);');
rates=chart(model,scope,'SelectRateReference',{'direct','single';'rollPID','single';'pitchPID','single';'angleEnable','boolean'},{'rate','single'},strjoin({'function [rate]=stepFn(direct,rollPID,pitchPID,angleEnable)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','            rate=direct;if angleEnable,rate(1)=rollPID;rate(2)=pitchPID;end','end'},newline),'[rate]=stepFn(direct,rollPID,pitchPID,angleEnable);');
vref=chart(model,scope,'SelectVerticalReference',{'zRef','single';'mode','uint8'},{'vRef','single'},strjoin({'function [vRef]=stepFn(zRef,mode)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','            vRef=zRef;if mode==5,vRef=single(-.15);end','end'},newline),'[vRef]=stepFn(zRef,mode);');
thrust=chart(model,scope,'ThrustCorrectionLimits',{'command','single';'correction','single';'base','single';'auto','boolean';'manual','boolean';'velEnable','boolean';'mode','uint8';'dt','single';'oldFilter','single';'lastThrust','single'},{'thrust','single';'filter','single';'last','single'},strjoin({'function [thrust,filter,last]=stepFn(command,correction,base,auto,manual,velEnable,mode,dt,oldFilter,lastThrust)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','            thrust=command;filter=oldFilter;','            if mode==3,filter=single(0);','            elseif manual,filter=command;end','            if velEnable','                filter=filterStep(single(double(base+correction)*3.7),dt,single(.01),oldFilter);thrust=filter;','                if auto','                    if double(thrust)/3.7>double(single(base*single(1.15))),thrust=single(3.7*double(base)*double(single(1.15)));end','                    if double(thrust)/3.7<double(single(base*single(.85))),thrust=single(3.7*double(base)*double(single(.85)));end','                end','            end','            if mode==3,thrust=lastThrust;last=lastThrust;else,last=thrust;end','end','','function s = filterStep(u,h,T,s)','%FILTERSTEP Exact Filter::update, including operation ordering.','%#codegen','s = s*T/(T+h) + u*h/(T+h);','end'},newline),'[thrust,filter,last]=stepFn(command,correction,base,auto,manual,velEnable,mode,dt,oldFilter,lastThrust);');
diag=chart(model,scope,'ControlDiagnosticPack',{'alt','single';'base','single';'counter','uint16';'zRef','single';'thrust','single';'angle','single';'rate','single';'rollTorque','single';'pitchTorque','single';'yawTorque','single';'before','single'},{'diag','single'},strjoin({'function [diag]=stepFn(alt,base,counter,zRef,thrust,angle,rate,rollTorque,pitchTorque,yawTorque,before)','% 日本語の説明はブロック注釈とDescriptionを参照。','%#codegen','            diag=[alt;base;single(counter);zRef;thrust;angle;rate;rollTorque;pitchTorque;yawTorque;before];','end'},newline),'[diag]=stepFn(alt,base,counter,zRef,thrust,angle,rate,rollTorque,pitchTorque,yawTorque,before);');

ops={add('UnitDelay','ThrustFilterMemory','fm',struct('SampleTime','Official.Step','InitialCondition','single(0)')), ...
add('UnitDelay','HeldThrustMemory','tm',struct('SampleTime','Official.Step','InitialCondition','single(0)')), ...
add('Demux','StickFields','stick',struct('Outputs','6')), ...
add('Demux','AngleTargets','angles',struct('Outputs','2')), ...
add('Demux','EstimatedAngles','a',struct('Outputs','3')), ...
add('Demux','EstimatedRates','r',struct('Outputs','3')), ...
add('Demux','TargetRates','rr',struct('Outputs','3')), ...
add('Demux','ResetPreviousAngles','pe',struct('Outputs','2')), ...
add('Constant','Zero','zero',struct('Value','single(0)')), ...
add('Sum','AltitudeError','ez',struct('Inputs','+-')), ...
add('Sum','VerticalSpeedError','ev',struct('Inputs','+-')), ...
add('Sum','RollAngleError','ea1',struct('Inputs','+-')), ...
add('Sum','PitchAngleError','ea2',struct('Inputs','+-')), ...
add('Sum','RollRateError','er1',struct('Inputs','+-')), ...
add('Sum','PitchRateError','er2',struct('Inputs','+-')), ...
add('Sum','YawRateError','er3',struct('Inputs','+-'))};
x=edit(model,scope,ops,'incremental');
azpid=pid(model,scope,'AltitudePID',single([.38 10 .5 .125]),true);
vzpid=pid(model,scope,'VerticalSpeedPID',single([.08 .95 .08 .125]),false);
rap=pid(model,scope,'RollAnglePID',single([5 4 .04 .125]),false);
pap=pid(model,scope,'PitchAnglePID',single([5 4 .04 .125]),false);
rrp=pid(model,scope,'RollRatePID',single([.65 .7 .01 .125]),false);
prp=pid(model,scope,'PitchRatePID',single([.95 .7 .025 .125]),false);
yrp=pid(model,scope,'YawRatePID',single([3 .8 .01 .125]),false);
mix=mixer(model,scope);
ops={wire('blk_95.y1',[cmd '.u1']),wire('blk_98.y1',[cmd '.u2']),wire('blk_100.y1',[cmd '.u3']),wire('blk_101.y1',[cmd '.u4']),wire('blk_103.y1',[cmd '.u5']), ...
wire([cmd '.y4'],[gates '.u1']),wire([cmd '.y6'],[gates '.u2']),wire([cmd '.y5'],[gates '.u3']),wire('blk_103.y1',[gates '.u4']),wire([x.stick '.y5'],[gates '.u5']),wire('blk_104.y1',[gates '.u6']),wire([x.fm '.y1'],[gates '.u7']),wire([x.tm '.y1'],[gates '.u8']), ...
wire('blk_95.y1',[targets '.u1']),wire('blk_103.y1',[targets '.u2']),wire([gates '.y2'],[targets '.u3']),wire([gates '.y3'],[targets '.u4']), ...
wire('blk_95.y1',[x.stick '.u1']),wire([targets '.y1'],[x.angles '.u1']),wire([targets '.y3'],[x.pe '.u1']),wire('blk_96.y1',[x.a '.u1']),wire('blk_97.y1',[x.r '.u1']), ...
wire([targets '.y2'],[rates '.u1']),wire([rap '.y1'],[rates '.u2']),wire([pap '.y1'],[rates '.u3']),wire([gates '.y5'],[rates '.u4']),wire([rates '.y1'],[x.rr '.u1']), ...
wire([azpid '.y1'],[vref '.u1']),wire('blk_103.y1',[vref '.u2']),wire([cmd '.y1'],[x.ez '.u1']),wire('blk_98.y1',[x.ez '.u2']),wire([vref '.y1'],[x.ev '.u1']),wire('blk_99.y1',[x.ev '.u2']), ...
wire([x.angles '.y1'],[x.ea1 '.u1']),wire([x.a '.y1'],[x.ea1 '.u2']),wire([x.angles '.y2'],[x.ea2 '.u1']),wire([x.a '.y2'],[x.ea2 '.u2']), ...
wire([x.rr '.y1'],[x.er1 '.u1']),wire([x.r '.y1'],[x.er1 '.u2']),wire([x.rr '.y2'],[x.er2 '.u1']),wire([x.r '.y2'],[x.er2 '.u2']),wire([x.rr '.y3'],[x.er3 '.u1']),wire([x.r '.y3'],[x.er3 '.u2'])};
ps={azpid,vzpid,rap,pap,rrp,prp,yrp};es={x.ez,x.ev,x.ea1,x.ea2,x.er1,x.er2,x.er3};
en={[gates '.y4'],[gates '.y6'],[gates '.y5'],[gates '.y5'],[gates '.y2'],[gates '.y2'],[gates '.y2']};
pe={[x.zero '.y1'],[x.zero '.y1'],[x.pe '.y1'],[x.pe '.y2'],[x.zero '.y1'],[x.zero '.y1'],[x.zero '.y1']};
for k=1:7
ops=[ops,{wire([es{k} '.y1'],[ps{k} '.u1']),wire('blk_104.y1',[ps{k} '.u2']),wire(en{k},[ps{k} '.u3']),wire([gates '.y3'],[ps{k} '.u4']),wire(pe{k},[ps{k} '.u5'])}];
end
ops=[ops,{wire([gates '.y1'],[thrust '.u1']),wire([vzpid '.y1'],[thrust '.u2']),wire([cmd '.y2'],[thrust '.u3']),wire([cmd '.y5'],[thrust '.u4']),wire([cmd '.y6'],[thrust '.u5']),wire([gates '.y6'],[thrust '.u6']),wire('blk_103.y1',[thrust '.u7']),wire('blk_104.y1',[thrust '.u8']),wire([x.fm '.y1'],[thrust '.u9']),wire([x.tm '.y1'],[thrust '.u10']),wire([thrust '.y2'],[x.fm '.u1']),wire([thrust '.y3'],[x.tm '.u1']), ...
wire([thrust '.y1'],[mix '.u1']),wire([rrp '.y1'],[mix '.u2']),wire([prp '.y1'],[mix '.u3']),wire([yrp '.y1'],[mix '.u4']),wire([gates '.y2'],[mix '.u5']),wire([gates '.y3'],[mix '.u6']),wire('blk_102.y1',[mix '.u7']),wire('blk_103.y1',[mix '.u8']),wire('blk_104.y1',[mix '.u9']), ...
wire([cmd '.y1'],[diag '.u1']),wire([cmd '.y2'],[diag '.u2']),wire([cmd '.y3'],[diag '.u3']),wire([azpid '.y1'],[diag '.u4']),wire([thrust '.y1'],[diag '.u5']),wire([targets '.y1'],[diag '.u6']),wire([rates '.y1'],[diag '.u7']),wire([rrp '.y1'],[diag '.u8']),wire([prp '.y1'],[diag '.u9']),wire([yrp '.y1'],[diag '.u10']),wire([mix '.y3'],[diag '.u11']), ...
wire([mix '.y1'],'blk_105.u1'),wire([mix '.y2'],'blk_106.u1'),wire([diag '.y1'],'blk_107.u1')}];
edit(model,scope,ops,'full');model_check(model,scope,'["all"]');save_system(model);

end

function ids=edit(model,scope,ops,layout)
% One scope per call; stop on any partial operation rather than hiding errors.
model_read(model,scope,'0');
r=char(model_edit(model,scope,jsonencode(ops),layout));
if ~startsWith(strtrim(r),'status: ok'),error('official:EditFailed','%s',r);end
matches=regexp(r,'(?m)^\s+(\w+): (blk_\d+)\s*$','tokens');ids=struct;
for k=1:numel(matches),ids.(matches{k}{1})=matches{k}{2};end
end
function op=add(type,name,ref,params)
op=struct('op','add_block','type',type,'name',name,'ref',ref,'params',params);
end
function op=wire(a,b)
op=struct('op','connect','target',[a ' -> ' b]);
end
function op=config(target,params)
op=struct('op','configure','target',target,'params',params);
end
function id=chart(model,parent,name,inputs,outputs,script,label)
ids=edit(model,parent,{add('Chart',name,'chart',struct)},'incremental');id=ids.chart;
ops={config(['chart:' model],struct('ActionLanguage','MATLAB'))};
for k=1:size(inputs,1)
    ops{end+1}=add('Data',inputs{k,1},['i' num2str(k)],struct('Scope','Input','DataType',inputs{k,2}));
end
for k=1:size(outputs,1)
    ops{end+1}=add('Data',outputs{k,1},['o' num2str(k)],struct('Scope','Output','DataType',outputs{k,2}));
end
ops{end+1}=struct('op','add_block','type','EMFunction','ref','function', 'params',struct('Script',script));
ops{end+1}=add('State','Calculate','calculate',struct('LabelString',['Calculate' newline 'en,du: ' label]));
ops{end+1}=struct('op','connect','target','? -> #calculate');
edit(model,id,ops,'full');
model_check(model,id,'["stateflow_lint"]');
end

function id=pid(model,parent,name,g,hold)
ids=edit(model,parent,{struct('op','create_subsystem','name',name,'ref','pid','interface',struct('inputs',{{'Error','Dt','Enable','Reset','PreviousError'}},'outputs',{{'Output'}}))},'incremental');id=ids.pid;
r=char(model_read(model,id,'0'));ins=regexp(r,'(?m)- id: (blk_\d+) #u\d+','tokens');outs=regexp(r,'(?m)- id: (blk_\d+) #y\d+','tokens');
e=ins{1}{1};dt=ins{2}{1};en=ins{3}{1};reset=ins{4}{1};pe=ins{5}{1};out=outs{1}{1};
ops={};
for pair={'i','d','e','y'}
ref=pair{1};ops{end+1}=add('UnitDelay',[upper(ref) 'Memory'],ref,struct('SampleTime','Official.Step','InitialCondition','single(0)'));
end
ops=[ops,{add('Constant','Zero','zero',struct('Value','single(0)')),add('Constant','Kp','kp',struct('Value',sprintf('single(%.9g)',g(1)))),add('Constant','Ti','ti',struct('Value',sprintf('single(%.9g)',g(2)))),add('Constant','Td','td',struct('Value',sprintf('single(%.9g)',g(3)))),add('Constant','Eta','eta',struct('Value',sprintf('single(%.9g)',g(4))))}];
for ref={'ip','dp','ep','inext','dnext','enext','ynext','output'}
ops{end+1}=add('Switch',['Select_' ref{1}],ref{1},struct('Criteria','u2 ~= 0'));
end
ops=[ops,{add('Sum','ErrorPair','esum',struct('Inputs','++')),add('Product','ErrorPairDt','idt',struct),add('Gain','HalfIntegral','half',struct('Gain','single(.5)')),add('Product','DivideTi','iti',struct('Inputs','*/')),add('Sum','IntegralUpdate','iadd',struct('Inputs','++')),add('Saturate','IntegralLimit','ilim',struct('UpperLimit','single(30000)','LowerLimit','single(-30000)')), ...
add('Product','EtaTd','etd',struct),add('Gain','TwiceEtaTd','twoetd',struct('Gain','single(2)')),add('Sum','DerivativeDenominator','den',struct('Inputs','++')),add('Sum','DerivativePreviousNumerator','num',struct('Inputs','+-')),add('Product','PreviousDerivativeProduct','dpdt',struct),add('Product','PreviousDerivativeTerm','dterm1',struct('Inputs','*/')),add('Sum','ErrorDifference','ediff',struct('Inputs','+-')),add('Gain','TwiceTd','twotd',struct('Gain','single(2)')),add('Product','DerivativeErrorProduct','dedt',struct),add('Product','DerivativeErrorTerm','dterm2',struct('Inputs','*/')),add('Sum','DerivativeUpdate','dadd',struct('Inputs','++')),add('Sum','PIDTerms','terms',struct('Inputs','+++')),add('Product','ApplyKp','calc',struct)}];
ops=[ops,{wire('#zero.y1','#ip.u1'),wire([reset '.y1'],'#ip.u2'),wire('#i.y1','#ip.u3'),wire('#zero.y1','#dp.u1'),wire([reset '.y1'],'#dp.u2'),wire('#d.y1','#dp.u3'),wire([pe '.y1'],'#ep.u1'),wire([reset '.y1'],'#ep.u2'),wire('#e.y1','#ep.u3'), ...
wire([e '.y1'],'#esum.u1'),wire('#ep.y1','#esum.u2'),wire([dt '.y1'],'#idt.u1'),wire('#esum.y1','#idt.u2'),wire('#idt.y1','#half.u1'),wire('#half.y1','#iti.u1'),wire('#ti.y1','#iti.u2'),wire('#ip.y1','#iadd.u1'),wire('#iti.y1','#iadd.u2'),wire('#iadd.y1','#ilim.u1'), ...
wire('#eta.y1','#etd.u1'),wire('#td.y1','#etd.u2'),wire('#etd.y1','#twoetd.u1'),wire('#twoetd.y1','#den.u1'),wire([dt '.y1'],'#den.u2'),wire('#twoetd.y1','#num.u1'),wire([dt '.y1'],'#num.u2'),wire('#num.y1','#dpdt.u1'),wire('#dp.y1','#dpdt.u2'),wire('#dpdt.y1','#dterm1.u1'),wire('#den.y1','#dterm1.u2'), ...
wire([e '.y1'],'#ediff.u1'),wire('#ep.y1','#ediff.u2'),wire('#td.y1','#twotd.u1'),wire('#twotd.y1','#dedt.u1'),wire('#ediff.y1','#dedt.u2'),wire('#dedt.y1','#dterm2.u1'),wire('#den.y1','#dterm2.u2'),wire('#dterm1.y1','#dadd.u1'),wire('#dterm2.y1','#dadd.u2'), ...
wire([e '.y1'],'#terms.u1'),wire('#ilim.y1','#terms.u2'),wire('#dadd.y1','#terms.u3'),wire('#kp.y1','#calc.u1'),wire('#terms.y1','#calc.u2'), ...
wire('#ilim.y1','#inext.u1'),wire([en '.y1'],'#inext.u2'),wire('#ip.y1','#inext.u3'),wire('#inext.y1','#i.u1'),wire('#dadd.y1','#dnext.u1'),wire([en '.y1'],'#dnext.u2'),wire('#dp.y1','#dnext.u3'),wire('#dnext.y1','#d.u1'),wire([e '.y1'],'#enext.u1'),wire([en '.y1'],'#enext.u2'),wire('#ep.y1','#enext.u3'),wire('#enext.y1','#e.u1'), ...
wire('#calc.y1','#ynext.u1'),wire([en '.y1'],'#ynext.u2'),wire('#y.y1','#ynext.u3'),wire('#ynext.y1','#y.u1'),wire('#calc.y1','#output.u1'),wire([en '.y1'],'#output.u2')}];
if hold,ops{end+1}=wire('#y.y1','#output.u3');else,ops{end+1}=wire('#zero.y1','#output.u3');end
ops{end+1}=wire('#output.y1',[out '.u1']);edit(model,id,ops,'full');model_check(model,id,'["all"]');
end
function id=mixer(model,parent)
% Function-only mixer temporary stage; replaced with visible arithmetic next.
root=stampfly_project_root();src=fileread(fullfile(root,'code','model_algorithms','MotorMixer400.m'));
id=chart(model,parent,'MotorMixerFilter8bit',{'thrust','single';'rollTorque','single';'pitchTorque','single';'yawTorque','single';'run','boolean';'reset','boolean';'overG','uint8';'mode','uint8';'dt','single'}, ...
{'duty','single';'counts','uint8';'before','single'},src,'[duty,counts,before]=stepFn(thrust,rollTorque,pitchTorque,yawTorque,run,reset,overG,mode,dt);');
end
