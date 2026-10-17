function states=flightStateDefinition(schema)
%FLIGHTSTATEDEFINITION 概要：現行Stateflowのモードを記録・画面で共通に解釈します。
% Mode 2は浮上ランプを含む飛行制御で、ホバリング達成を意味しません。
if nargin<1,schema='StampFlyOfficial-v1';end
states=struct('Schema','StampFlyOfficial-v1', ...
    'Codes',[0 1 2 3 5], ...
    'Names',{{'初期化','800サンプル校正','飛行制御','待機','自動着陸'}}, ...
    'Colors',[.45 .45 .45;.55 .40 .15;.00 .45 .74;.25 .50 .25;.85 .35 .05], ...
    'FlightCodes',[2 5],'ParkedCode',3);
if strcmp(schema,'StampFlyHover-v1')
    % 旧ホバリング専用プログラムは、記録が明示した場合にだけ解釈します。
    states.Schema='StampFlyHover-v1';states.Codes=0:4;
    states.Names={'待機','離陸','ホバリング','着陸','非常停止'};
    states.FlightCodes=[1 2 3];states.ParkedCode=0;
elseif ~strcmp(schema,states.Schema)
    % 定義を推測して別のプログラムへ誤った状態名を付けません。
    states.Schema='unknown';states.Codes=0:5;
    states.Names=arrayfun(@(v)sprintf('Mode %d',v),0:5,'UniformOutput',false);
    states.Colors=lines(6);states.FlightCodes=[];states.ParkedCode=NaN;
end
end
