function name=recordingStopName(reason)
%RECORDINGSTOPNAME 概要：保存の終了理由を表示します。待機復帰は着陸の保証ではありません。
switch char(reason)
    case {'parked','parked_next_takeoff'},name='待機復帰';
    case 'telemetry_lost',name='通信途絶';
    case 'firmware_restart',name='機体時刻リセット';
    case 'initialization',name='初期化・校正へ移行';
    case 'disconnected',name='切断';
    case 'app_closed',name='アプリ終了';
    case 'manual_recording',name='手動記録へ移行';
    case 'manual_stop',name='手動停止';
    case 'unknown',name='終了理由なし（旧記録）';
    otherwise,name=sprintf('終了理由: %s',char(reason));
end
end
