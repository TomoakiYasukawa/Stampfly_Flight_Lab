function report=build_graphical_finalize()
%BUILD_GRAPHICAL_FINALIZE Mode selection with explicit transition priorities.
model='StampFly_Official_FlightTest400';id='blk_553';
description=sprintf(['周期末に飛行状態を確定\n' ...
    '優先度1: 過加速度→待機。2: Flip完了→飛行。3: Flip開始→Flip。4: 着陸中かつ高度<0.1 m→待機。\n' ...
    'それ以外は前段のpreModeを維持。優先度は公式の後勝ちif分岐と一致。MATLAB関数なし。']);
reorg.chartInterface(model,id,description);
ops={reorg.add('Event','decide','decide',struct('Name','decide','Scope','Local')), ...
    reorg.add('State','FinalModes','modes',struct('LabelString','FinalModes','ExecutionOrder',1, ...
    'Decomposition','EXCLUSIVE_OR','Position',[40 50 1400 800]))};
reply=reorg.edit(model,id,ops,'full');modes=reorg.created(reply,'modes');
names={'INIT','AVERAGE','PARKING','FLIGHT','LANDING','FLIP','OTHER'};values=[0 1 3 2 5 6 -1];ops={};
for k=1:numel(names)
    action=sprintf('mode=uint8(%d);',values(k));if values(k)<0,action='mode=preMode;';end
    ops{end+1}=reorg.add('State',names{k},names{k},struct('LabelString',[names{k} newline 'en: ' action], ...
        'Position',[80+mod(k-1,3)*430 100+floor((k-1)/3)*230 260 80]));
end
ops{end+1}=reorg.add('Junction','PrioritySelection','selection',struct('Position',[520 250 12 12]));
ops{end+1}=reorg.transition('?','#INIT','',1);
reply=reorg.edit(model,modes,ops,'full');ids=struct;for k=1:numel(names),ids.(names{k})=reorg.created(reply,names{k});end
selection=reorg.created(reply,'selection');
ops={reorg.transition(modes,selection,'decide',1), ...
    reorg.transition(selection,ids.PARKING,'[(branch==2 || branch==5 || branch==6) && overG==1]',1), ...
    reorg.transition(selection,ids.FLIGHT,'[branch==6 && flipDone]',2), ...
    reorg.transition(selection,ids.FLIP,'[flipStart && (branch==2 || branch==6)]',3), ...
    reorg.transition(selection,ids.PARKING,'[branch==5 && height<.1]',4)};
for k=1:numel(names)
    label=sprintf('[preMode==uint8(%d)]',values(k));if values(k)<0,label='';end
    ops{end+1}=reorg.transition(selection,ids.(names{k}),label,4+k);
end
reorg.edit(model,id,ops);
code='mode=preMode;send(decide,FinalModes);';
parentPosition=sfroot().find('-isa','Stateflow.Chart','Path',reorg.path(model,id)).find('-isa','Stateflow.State','Name','FinalModes').Position;
cyclePosition=[parentPosition(1)+parentPosition(3)+2000 parentPosition(2) 550 160];
reorg.edit(model,id,{reorg.add('State','CycleInput','cycle',struct('LabelString',['CycleInput' newline 'en: ' code newline 'du: ' code], ...
    'ExecutionOrder',2,'Position',cyclePosition)), ...
    reorg.add('Annotation','JapaneseExplanation','note',struct('Text',description,'Position',[50 950 1450 130]))});
report=struct('StateNames',{names},'NoMATLABFunctions',true);save_system(model);
end
