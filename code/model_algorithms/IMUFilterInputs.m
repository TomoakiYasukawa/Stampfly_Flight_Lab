function [accelMps2,gyroRps,run,filterReset]=IMUFilterInputs(rates,accelG,mode,reset)
% 概要：IMU Filter の入力を準備します。機体座標 XYZ の角速度 [rad/s] と加速度 [g] を、推定器の座標と SI 単位へ変換します。校正中のリセット要求は、推定を再開するまで保持します。
%#codegen
% 1. 入力座標を [Y, X, -Z] に変換し、加速度を m/s² に換算します。静止時に推定器の Z が +g になる NED の定義です。
accelMps2=single([accelG(2),accelG(1),-accelG(3)])*single(9.80665);
gyroRps=single([rates(2),rates(1),-rates(3)]);
% 2. 起動・校正中（Mode 0, 1）は推定を停止し、Mode 2 以降で更新します。
run=mode>uint8(1);
% 3. 停止中には Resettable subsystem も実行されないため、要求を記憶して再開時の最初の更新に渡します。
persistent pendingReset
if isempty(pendingReset),pendingReset=false;end
if reset,pendingReset=true;end
filterReset=pendingReset;
if run,pendingReset=false;end
end
