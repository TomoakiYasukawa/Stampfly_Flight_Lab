function display=flightStatePresentation(schema)
%FLIGHTSTATEPRESENTATION 概要：機体のMode番号と、画面上の表示順を分離します。
% 状態番号は変更せず、公式版だけを初期化→校正→待機→飛行→着陸へ並べます。
if nargin<1,schema='StampFlyOfficial-v1';end
states=imu.flightStateDefinition(schema);
display=states;
if strcmp(states.Schema,'StampFlyOfficial-v1')
    display.Codes=[0 1 3 2 5];
    display.Names={'初期化','校正','待機','飛行制御','着陸'};
    [~,order]=ismember(display.Codes,states.Codes);
    display.Colors=states.Colors(order,:);
end
display.Levels=0:numel(display.Codes)-1;
end
