function finish_bottom_tof()
%FINISH_BOTTOM_TOF Explain acquisition and logger validity inside the model.
init_official;
m = 'StampFly_Official_Bench400';
model_read(m,'blk_612','0');
sensorText = ['下向きToF：Medium、33 ms。起動時のStartMeasurementは1回。' ...
    'dcnt>14とready割り込みでcore0へ読み出しを要求し、400 Hz側は待たず最新結果を取得。' ...
    '状態0の最遠対象[mm]、新着フラグ、測定状態を出力。前向きToFはXSHUT=LOWで無効。'];
sensorNote = ['BMI270：ODR400 Hz。下向きToF：33 ms測定、取得は約25 Hz。' ...
    '400 Hz側は待たず最新値を使用。状態0=正常、90=読出し/同期エラー、255=対象なし。' ...
    '前向きToFは無効、Optical Flowは未実装。JoyStickは公式パケットを受信。'];
ops = {cfg(634,struct('Description',sensorText)), ...
    cfg(845,struct('Description',sensorNote,'MaskDisplay',noteMask(sensorNote))), ...
    cfg(622,struct('Description','下向きToFのみの測定状態。0=正常、90=読出し/同期エラー、255=対象なし、101以上=初期化失敗。')), ...
    cfg(626,struct('Description','前向きToFは無効。互換性のため出力ポートを残し、常に0 mmを出力。'))};
edit(m,'blk_612',ops);
model_read(m,'blk_640','0');
loggerText = ['50 Hz SFI8記録：下向きToF距離[m]と状態、ToFValid=(距離>0かつ状態0)。' ...
    'ToFFreshは前回の記録から測定完了数が変化したかで判定。' ...
    '無効時も数値ペイロードと状態を保存し、UIは無効データをNaNで表示。' ...
    'Optical FlowはNaN/無効を保存。高度はSimulinkのKalman出力。'];
edit(m,'blk_640',{cfg(663,struct('Description',loggerText)), ...
    cfg(848,struct('Description',loggerText,'MaskDisplay',noteMask(loggerText)))});
model_read(m,'root','0');
edit(m,'root',{cfg(612,struct('Description',sensorText)), ...
    cfg(640,struct('Description',loggerText)), ...
    cfg(681,struct('Description','公式JoyStickへ40 Hzで姿勢・高度・電圧等を返信。前向きToFは無効で0を返信。'))});
model_read(m,'blk_681','0');
notes = find_system(Simulink.ID.getFullName([m ':681']),'SearchDepth',1,'Name','ModelExplanation');
if ~isempty(notes)
    sid = ['blk_' extractAfter(Simulink.ID.getSID(notes{1}),':')];
    text = 'JoyStickへ公式テレメトリを40 Hzで返信。高度はSimulinkのKalman出力。前向きToFは無効（0）。';
    edit(m,'blk_681',{struct('op','configure','target',sid,'params', ...
        struct('Description',text,'MaskDisplay',noteMask(text)))});
end
disp(model_check(m,'root','["all"]'));
save_system(m);
end

function op = cfg(sid,params)
op = struct('op','configure','target',['blk_' num2str(sid)],'params',params);
end

function mask = noteMask(text)
mask = ['disp(''' strrep(['説明\n' text],'''','''''') ''')'];
end

function edit(m,scope,ops)
r = char(model_edit(m,scope,jsonencode(ops),'incremental'));
if ~startsWith(strtrim(r),'status: ok')
    model_read(m,scope,'0');model_check(m,scope,'["all"]');
    error('official:ToFAnnotation','%s',r);
end
model_read(m,scope,'0');
end
