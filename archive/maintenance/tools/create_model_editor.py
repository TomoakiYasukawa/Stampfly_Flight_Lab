"""Generate a reproducible MATLAB editor; all model edits use genuine model_edit."""
from pathlib import Path
import re

root=Path(__file__).resolve().parents[3]
out=root/'archive/maintenance/scripts/model_edit/assemble_official_modular.m'

header=r'''function assemble_official_modular()
%ASSEMBLE_OFFICIAL_MODULAR Build editable algorithms inside the Simulink file.
root=stampfly_project_root();addpath(root,fullfile(root,'models'));init_official;
model='StampFly_Official_Bench400';open_system(stampfly_model_file(model));
assert(library.settingsLookup().gatePass);
'''

helpers=r'''
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
'''

def mq(s):return "'"+s.replace("'","''")+"'"
def script_arg(s):
    return 'strjoin({'+','.join(mq(x) for x in s.splitlines())+'},newline)'
def cells(items):
    return '{'+';'.join(mq(a)+','+mq(b) for a,b in items)+'}'

def class_to_embedded(name):
    text=(root/'code/+official'/f'{name}.m').read_text(encoding='utf-8')
    m=re.search(r'function \[([^\]]+)\]=stepImpl\(o,([^\)]+)\)\n(.*?)\n        end',text,re.S)
    outputs=m[1].split(',');inputs=m[2].split(',');body=m[3]
    priv=re.search(r'properties \(Access=private\)\n(.*?)\n    end',text,re.S)
    state=[];init=[]
    if priv:
        for line in priv[1].splitlines():
            a,b=line.strip().split('=',1);state.append(a);init.append(f'{a}={b};')
    pub=re.search(r'properties \(Nontunable\)\n(.*?)\n    end',text,re.S)
    for line in pub[1].splitlines():
        a,b=line.strip().split('=',1)
        if a!='SampleTime':body=body.replace('o.'+a,b)
    body=re.sub(r'o\.(\w+)',r'\1',body)
    code='function ['+','.join(outputs)+']=stepFn('+','.join(inputs)+')\n% 日本語の説明はブロック注釈とDescriptionを参照。\n%#codegen\n'
    if state:code+='persistent '+' '.join(state)+';\nif isempty('+state[0]+')\n'+'\n'.join(init)+'\nend\n'
    code+=body+'\nend\n'
    trailing=text[text.find('\nfunction ',text.find('\nend\n')+1):] if '\nfunction ' in text else ''
    code+=trailing
    # Embed estimator recurrences so the model does not depend on package files.
    for fn in ['filterStep','madgwickStep','kalmanStep','kalmanInitial']:
        if 'official.'+fn in code:
            extra=(root/'code/+official'/f'{fn}.m').read_text(encoding='utf-8')
            code=code.replace('official.'+fn,fn)+'\n'+extra
    code=code.replace('official.kalmanInitial','kalmanInitial')
    if 'kalmanInitial()' in code and not re.search(r'function s\s*=\s*kalmanInitial',code):
        code+='\n'+(root/'code/+official/kalmanInitial.m').read_text(encoding='utf-8')
    return inputs,outputs,code

sensor_specs=[
('IMUAxes400','IMUAxisConversion',[('accelMps2','single'),('gyroRps','single')],[('a','single'),('g','single')]),
('IMUCalibration400','IMUBiasCalibration',[('a','single'),('g','single'),('mode','uint8')],[('offset','single'),('count','uint16')]),
('IMUFilters400','IMUFiltering',[('a','single'),('g','single'),('offset','single'),('mode','uint8'),('dt','single')],[('af','single'),('gf','single'),('azd','single')]),
('Madgwick400','MadgwickAttitude',[('rates','single'),('accel','single'),('mode','uint8'),('reset','boolean')],[('a','single'),('q','single')]),
('VerticalAccel400','VerticalAcceleration',[('azd','single'),('mode','uint8'),('dt','single')],[('az','single')]),
('ToFPreprocess400','ToFHoldOutlierFilter',[('mm','int16'),('fresh','uint8'),('mode','uint8'),('dt','single')],[('alt','single'),('raw','int16')]),
('AltitudeKalman400','AltitudeKalman',[('alt','single'),('az','single'),('mode','uint8'),('dt','single'),('parkingReset','boolean')],[('height','single'),('velocity','single'),('bias','single')]),
('SensorFlags400','SensorFlags',[('accel','single'),('azd','single'),('voltage','single'),('mode','uint8'),('altFlag','uint8'),('velocity','single'),('rawRange','int16'),('dt','single'),('parkingReset','boolean')],[('flags','uint8')]),
('SensorDiagnostics400','SensorDiagnosticPack',[('az','single'),('bias','single'),('alt','single'),('offset','single'),('count','uint16')],[('diag','single')])]

body=header
body+="edit(model,'blk_72',{"
body+=','.join("struct('op','delete','target','blk_%d')"%i for i in range(108,117))+"},'incremental');\n"
refs=['axes','cal','filter','att','az','tof','kal','flags','diag']
for ref,(cls,name,ins,outs) in zip(refs,sensor_specs):
    iv,ov,code=class_to_embedded(cls)
    call='['+','.join(ov)+']=stepFn('+','.join(iv)+');'
    body+=ref+'=chart(model,\'blk_72\','+mq(name)+','+cells(ins)+','+cells(outs)+','+script_arg(code)+','+mq(call)+');\n'

wires=[('blk_75.y1','axes.u1'),('blk_76.y1','axes.u2'),('axes.y1','cal.u1'),('axes.y2','cal.u2'),('blk_80.y1','cal.u3'),('axes.y1','filter.u1'),('axes.y2','filter.u2'),('cal.y1','filter.u3'),('blk_80.y1','filter.u4'),('blk_82.y1','filter.u5'),('filter.y2','att.u1'),('filter.y1','att.u2'),('blk_80.y1','att.u3'),('blk_83.y1','att.u4'),('filter.y3','az.u1'),('blk_80.y1','az.u2'),('blk_82.y1','az.u3'),('blk_77.y1','tof.u1'),('blk_78.y1','tof.u2'),('blk_80.y1','tof.u3'),('blk_82.y1','tof.u4'),('tof.y1','kal.u1'),('az.y1','kal.u2'),('blk_80.y1','kal.u3'),('blk_82.y1','kal.u4'),('blk_84.y1','kal.u5'),('filter.y1','flags.u1'),('filter.y3','flags.u2'),('blk_79.y1','flags.u3'),('blk_80.y1','flags.u4'),('blk_81.y1','flags.u5'),('kal.y2','flags.u6'),('tof.y2','flags.u7'),('blk_82.y1','flags.u8'),('blk_84.y1','flags.u9'),('az.y1','diag.u1'),('kal.y3','diag.u2'),('tof.y1','diag.u3'),('cal.y1','diag.u4'),('cal.y2','diag.u5'),('att.y1','blk_85.u1'),('filter.y2','blk_86.u1'),('kal.y1','blk_87.u1'),('kal.y2','blk_88.u1'),('flags.y1','blk_89.u1'),('att.y2','blk_90.u1'),('diag.y1','blk_91.u1')]
def ep(x):
    a,b=x.split('.')
    return mq(x) if a.startswith('blk_') else '['+a+' '+mq('.'+b)+']'
body+="edit(model,'blk_72',{\n"+','.join('wire('+ep(a)+','+ep(b)+')' for a,b in wires)+"},'full');\n"
body+="model_check(model,'blk_72','[\"all\"]');\nsave_system(model);\n"
out.write_text(body+helpers,encoding='utf-8')

# Stage 2: the controller is made from individual command blocks, seven
# visible PID subsystems and a separate mixer/filter/quantizer subsystem.
control=header
control+="scope='blk_92';\n"
specs=[
('TakeoffCommand400','TakeoffLandingCommand',[('stick','single'),('height','single'),('voltage','single'),('rangeFlag','uint8'),('mode','uint8')],[('alt','single'),('base','single'),('counter','uint16'),('raw','single'),('auto','boolean'),('manual','boolean')],'cmd'),
('ControlGates400','ControlEnableReset',[('raw','single'),('manual','boolean'),('auto','boolean'),('mode','uint8'),('controlMode','single'),('dt','single'),('oldFilter','single'),('lastThrust','single')],[('command','single'),('run','boolean'),('reset','boolean'),('altEnable','boolean'),('angleEnable','boolean'),('velEnable','boolean')],'gates'),
('StickTargets400','StickToAngleRate',[('stick','single'),('mode','uint8'),('run','boolean'),('reset','boolean')],[('angle','single'),('directRate','single'),('resetError','single')],'targets'),
('RateReference400','SelectRateReference',[('direct','single'),('rollPID','single'),('pitchPID','single'),('angleEnable','boolean')],[('rate','single')],'rates'),
('VelocityReference400','SelectVerticalReference',[('zRef','single'),('mode','uint8')],[('vRef','single')],'vref'),
('ThrustFinalize400','ThrustCorrectionLimits',[('command','single'),('correction','single'),('base','single'),('auto','boolean'),('manual','boolean'),('velEnable','boolean'),('mode','uint8'),('dt','single'),('oldFilter','single'),('lastThrust','single')],[('thrust','single'),('filter','single'),('last','single')],'thrust'),
('ControlDiagnostics400','ControlDiagnosticPack',[('alt','single'),('base','single'),('counter','uint16'),('zRef','single'),('thrust','single'),('angle','single'),('rate','single'),('rollTorque','single'),('pitchTorque','single'),('yawTorque','single'),('before','single')],[('diag','single')],'diag')]
for cls,name,ins,outs,ref in specs:
    iv,ov,code=class_to_embedded(cls)
    control+=ref+'=chart(model,scope,'+mq(name)+','+cells(ins)+','+cells(outs)+','+script_arg(code)+','+mq('['+','.join(ov)+']=stepFn('+','.join(iv)+');')+');\n'
control+=r'''
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
'''
pidhelper=r'''
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
'''
(root/'code/model_algorithms').mkdir(exist_ok=True)
_,_,mixcode=class_to_embedded('MotorMixer400')
(root/'code/model_algorithms/MotorMixer400.m').write_text(mixcode,encoding='utf-8')
(root/'archive/maintenance/scripts/model_edit/assemble_official_control.m').write_text(control+helpers+pidhelper,encoding='utf-8')
print(out)
