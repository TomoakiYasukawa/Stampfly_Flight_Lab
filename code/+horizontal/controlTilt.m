function angles=controlTilt(accelerationLocal,heading)
%CONTROLTILT 概要：局所水平加速度から既存姿勢PIDのRoll/Pitch目標を作ります。
% 機体座標は前・右・下。前方加速は負Pitch、右方加速は正Rollです。
% 既存FlightOutputsの軸交換後、機体回転はRz(heading)*Rx(Roll)*Ry(Pitch)
% と表せます。この演算順序から推力方向を逆算し、既存角度を渡します。
%#codegen
% 1. 局所加速度を現在の機首方向の前・右へ戻します。
c=horizontal.mathSingle('cos',single(heading));s=horizontal.mathSingle('sin',single(heading));
aForward=c*accelerationLocal(1)+s*accelerationLocal(2);
aRight=-s*accelerationLocal(1)+c*accelerationLocal(2);
% 2. Rz*Rx*Ryの下向き列から aRight=g*tan(Roll)、
% aForward=-g*tan(Pitch)/cos(Roll) を逆に解きます。
g=single(9.80665);roll=horizontal.mathSingle('atan2',aRight,g);
pitch=horizontal.mathSingle('atan2',-aForward*horizontal.mathSingle('cos',roll),g);
angles=[roll;pitch];
end
