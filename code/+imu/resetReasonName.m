function name=resetReasonName(value)
%RESETREASONNAME 概要：ESP32の起動理由を説明します。時刻逆転だけでは原因を推測しません。
switch double(value)
    case 0,name='未記録';
    case 1,name='電源投入';
    case 2,name='外部リセット';
    case 3,name='ソフトウェア再起動';
    case 4,name='例外・パニック';
    case 5,name='割込みウォッチドッグ';
    case 6,name='タスクウォッチドッグ';
    case 7,name='ウォッチドッグ';
    case 8,name='スリープ復帰';
    case 9,name='電圧低下リセット';
    case 10,name='SDIOリセット';
    case 11,name='USBリセット';
    case 12,name='JTAGリセット';
    case 13,name='eFuseエラー';
    case 14,name='電源グリッチ';
    case 15,name='CPUロックアップ';
    otherwise,name=sprintf('起動理由 %g',double(value));
end
end
