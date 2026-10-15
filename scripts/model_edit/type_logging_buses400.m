function type_logging_buses400()
%TYPE_LOGGING_BUSES400 記録用の構造体バスをSATKで明示する。
model='StampFly_PIDBlock_FlightTest400';init_logging_buses();
reorg.edit(model,'blk_2963',{ ...
    typed('blk_3997','LogRawBus'),typed('blk_4009','LogEstimateBus'), ...
    typed('blk_4019','LogCommandBus'),typed('blk_4034','LogExtraBus')});
reorg.edit(model,'blk_3979',{typed('blk_3988','LogFlowBus')});
reorg.edit(model,'blk_3983',{typed('blk_3991','LogMagBus')});
% JoyStickの数値処理はそのままで、ログに渡す構造体の型だけ明示する。
reorg.edit(model,'blk_3202',{typed('blk_3203','LogPilotBus')});
disp(model_check(model,'blk_2963','["all"]'));
save_system(model,[],'OverwriteIfChangedOnDisk',true);
end

function op=typed(id,name)
op=reorg.configure(id,struct('OutDataTypeStr',['Bus: ' name],'NonVirtualBus','on'));
end
