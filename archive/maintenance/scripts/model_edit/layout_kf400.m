function report=layout_kf400()
%LAYOUT_KF400 Label and arrange only the added altitude filter diagrams.
% The original teaching layout is restored around the replacement wrapper.
root=stampfly_project_root();init_kf_flight();ensure_simulink_toolkit();
gate=library.settingsLookup();assert(gate.gatePass);
model='StampFly_KF400';baseline='StampFly_IMU400';
open_system(fullfile(root,[baseline '.slx']));open_system(stampfly_model_file(model));
listeners=layout.LayoutListeners();disabler=listeners.getScopedLayoutListenerDisabler(model); %#ok<NASGU>
s=jsondecode(fileread(fullfile(root,'docs','history','kf_flight_structure.json')));
before=reorg.links(model,'blk_2231');
reorg.edit(model,'blk_2231',{reorg.configure(s.AltitudeBlock, ...
    struct('ShowPortLabels','FromPortBlockName'))},'incremental');
reorg.edit(model,s.AltitudeBlock,{reorg.configure(s.FilterStepBlock, ...
    struct('ShowPortLabels','FromPortBlockName'))},'incremental');
% Content preview is an editor-only property absent from SATK's parameter
% schema, so handle this presentation preference with the native editor API.
for id={s.AltitudeBlock,s.FilterStepBlock,s.ScheduleBlock,s.OutputBlock,s.CurrentStateBlock}
    set_param(reorg.path(model,id{1}),'ContentPreviewEnabled','off');
end
header=sprintf(['StampFly IMU + Kalman Filter / 400 Hz\n' ...
    'センサー取得 → 校正・前処理 → 標準の姿勢・高度推定 → PID → モーター\n' ...
    '飛行モードは最上位のStateflowで管理。下段は観測・記録・状態表示。']);
display=char("disp(sprintf('"+strrep(strrep(string(header),"'","''"),newline,'\n')+"')); ");
reorg.edit(model,'root',{reorg.configure('blk_973',struct('MaskDisplay',display))},'incremental');
% Explicit presentation-only positioning is authorized by the user's layout
% request. No blocks, parameters used by algorithms, or connections change.
for scope={'root','blk_2231'}
    oldScope=baseline;if ~strcmp(scope{1},'root'),oldScope=reorg.path(baseline,scope{1});end
    children=find_system(oldScope,'SearchDepth',1,'Type','Block');
    for k=1:numel(children)
        if strcmp(children{k},oldScope),continue;end
        id=reorg.id(children{k});if strcmp(id,'blk_2236'),continue;end
        other=reorg.path(model,id);
        set_param(other,'Position',get_param(children{k},'Position'));
    end
end
set_param(reorg.path(model,s.AltitudeBlock),'Position',get_param(reorg.path(baseline,'blk_2236'),'Position'));
altitudeItems={ ...
    'blk_4189',[40 100 70 120];'blk_4190',[40 155 70 175]; ...
    'blk_4191',[40 235 70 255];'blk_4192',[40 305 70 325]; ...
    'blk_4193',[40 540 70 560];'blk_4198',[140 420 240 460]; ...
    s.ScheduleBlock,[360 220 585 500];s.FilterStepBlock,[935 150 1255 630]; ...
    s.OutputBlock,[1510 320 1730 490]; ...
    'blk_4194',[1900 330 1930 350];'blk_4195',[1900 405 1930 425];'blk_4196',[1900 480 1930 500]};
stepItems={ ...
    'blk_4202',[40 200 70 220];'blk_4203',[40 140 70 160]; ...
    'blk_4204',[1010 610 1040 630];'blk_4205',[40 430 70 450]; ...
    'blk_4206',[40 490 70 510];'blk_4207',[40 550 70 570]; ...
    'blk_4208',[40 735 70 755];'blk_4209',[40 370 70 390]; ...
    'blk_4210',[1010 685 1040 705];'blk_4211',[1590 455 1620 475]; ...
    'blk_4213',[450 40 480 70];'blk_4217',[40 290 140 330]; ...
    'blk_4218',[40 645 140 685];s.FilterBlock,[580 180 820 780]; ...
    s.CurrentStateBlock,[1150 360 1400 610];s.PrivateStateBlock,[1320 140 1370 190]};
for items={altitudeItems,stepItems}
    list=items{1};for k=1:size(list,1),set_param(reorg.path(model,list{k,1}),'Position',list{k,2});end
end
assert(isequal(before,reorg.links(model,'blk_2231')));
for scope={s.FilterStepBlock,s.AltitudeBlock,'blk_2231','root'}
    path=model;if ~strcmp(scope{1},'root'),path=reorg.path(model,scope{1});end
    lines=find_system(path,'FindAll','on','SearchDepth',1,'Type','Line');
    if ~isempty(lines),Simulink.BlockDiagram.routeLine(lines);end
    check=char(model_check(model,scope{1},'["all"]'));disp(check);
    assert(~contains(check,'severity: error'));
end
save_system(model);
s.ModelSHA256=sha256(stampfly_model_file(model));
s.PortLabelsVisible=true;s.LayoutPreservesOriginalTeachingDiagrams=true;
writeJSON(fullfile(root,'docs','history','kf_flight_structure.json'),s);
folder=fullfile(root,'docs','history','images');if ~isfolder(folder),mkdir(folder);end
scopes={s.AltitudeBlock,s.FilterStepBlock};names={'kf_altitude400.png','kf_filter_step400.png'};
for k=1:2,print(['-s' reorg.path(model,scopes{k})],'-dpng','-r100',fullfile(folder,names{k}));end
report=s;fprintf('KF400_LAYOUT_SAVED\n');
end
function digest=sha256(file)
[status,value]=system(sprintf('powershell -NoProfile -Command "(Get-FileHash -LiteralPath ''%s'' -Algorithm SHA256).Hash"',strrep(file,'''','''''')));
assert(status==0);digest=lower(strtrim(value));
end
function writeJSON(file,report)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
