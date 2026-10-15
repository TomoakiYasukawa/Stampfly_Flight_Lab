function prepare_official_flight_test(enableMotors)
%PREPARE_OFFICIAL_FLIGHT_TEST Copy the verified bench for explicit flight tests.
% Default remains a dry run. Algorithms and IO timings are copied unchanged.
arguments
 enableMotors (1,1) logical = false
end
init_official;root=stampfly_project_root();bench='StampFly_Official_Bench400';m='StampFly_Official_FlightTest400';
file=stampfly_model_file(m);
% Refresh from the current bench; never silently reuse an older ToF model.
if bdIsLoaded(m),close_system(m,0);end
if isfile(file)
 copyfile(file,fullfile(root,'archive', ...
     ['FlightTest_before_refresh_' char(datetime('now','Format','yyyyMMdd_HHmmss')) '.slx']));
end
save_system(bench,file);
open_system(file);disp(model_read(m,'blk_604','0'));
ops={conf('blk_611',struct('AllowMotorOutput','true')),conf('blk_610',struct('Name','MotorOutputEnabled','Value',mat2str(enableMotors)))};
edit(m,'blk_604',ops);
disp(model_read(m,'root','0'));
text='公式制御の飛行テスト / 400 Hz / PWM 150 kHz指定・8 bit';
if enableMotors,text=[text ' / モーター出力有効：JoyStickで離陸・着陸'];else,text=[text ' / ドライラン：実モーター出力ゼロ'];end
edit(m,'root',{conf('blk_973',struct('MaskDisplay',['disp(''' text ''')'],'Description',text)),conf('blk_604',struct('MaskDisplay','disp(''モーター出力\n飛行テスト設定は内部を確認'')'))});
assert(strcmp(get_param(Simulink.ID.getFullName([m ':611']),'AllowMotorOutput'),'true'));
assert(strcmp(get_param(Simulink.ID.getFullName([m ':610']),'Value'),mat2str(enableMotors)));
disp(model_check(m,'root','["all"]'));save_system(m);
configure_stampfly_project();cd(root);
d=get_param(m,'CoderTargetData');assert(strcmp(d.Runtime.BuildAction,'Build'),'Use build only.');
slbuild(m);
end
function o=conf(target,params),o=struct('op','configure','target',target,'params',params);end
function edit(m,scope,ops)
model_read(m,scope,'0');r=char(model_edit(m,scope,jsonencode(ops),'incremental'));
if ~startsWith(strtrim(r),'status: ok'),disp(model_read(m,scope,'0'));disp(model_check(m,scope,'["all"]'));error('%s',r);end
end
