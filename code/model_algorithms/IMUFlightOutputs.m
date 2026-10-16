function [angles,q,rates]=IMUFlightOutputs(orientation,angularVelocity,run,reset,rawRates)
% 概要：IMU Filter の姿勢とバイアス補正済み角速度を、従来の飛行制御の座標・順序へ戻します。出力は角度 [Roll, Pitch, Yaw] [rad]、クォータニオン [w, x, y, z]、機体 XYZ 角速度 [rad/s] です。
%#codegen
% 1. 推定停止中に公開する前回の角度・姿勢・バイアスを保持します。初期姿勢は単位クォータニオンです。
persistent heldAngles heldQuaternion heldBias
if isempty(heldAngles)
    heldAngles=zeros(3,1,'single');
    heldQuaternion=single([1;0;0;0]);
    heldBias=zeros(3,1,'single');
end
% 2. リセットでは姿勢と角速度バイアスを初期化します。角度は次の推定更新まで前回値を保ちます。
if reset
    heldQuaternion=single([1;0;0;0]);
    heldBias=zeros(3,1,'single');
end
% 3. 補正済み角速度を機体 XYZ に戻し、更新時はその値を PID へ渡します。
correctedRates=single([angularVelocity(2);angularVelocity(1);-angularVelocity(3)]);
% 4. クォータニオンから角度を計算します。asin の入力制限、従来の rad/deg 換算係数、Yaw の 180° オフセットを維持します。
if run
    heldQuaternion=single(orientation(:));
    w=heldQuaternion(1);x=heldQuaternion(2);y=heldQuaternion(3);z=heldQuaternion(4);
    roll=atan2(single(2)*(w*x+y*z),single(1)-single(2)*(x*x+y*y));
    pitch=asin(min(single(1),max(single(-1),single(2)*(w*y-z*x))));
    yaw=atan2(single(2)*(x*y+w*z),single(1)-single(2)*(y*y+z*z));
    heldAngles=[pitch*single(57.29578);roll*single(57.29578); ...
        -(yaw*single(57.29578)+single(180))]*single(pi/180);
    heldBias=single(rawRates(:))-correctedRates;
end
% 5. 出力を公開します。停止中は生のフィルター済み角速度から最後のバイアスを引き、追加の周期遅れを入れません。
angles=heldAngles;q=heldQuaternion;
rates=single(rawRates(:))-heldBias;
if run,rates=correctedRates;end
end
