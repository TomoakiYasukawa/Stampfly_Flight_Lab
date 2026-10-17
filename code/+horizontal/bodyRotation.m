function [R,valid]=bodyRotation(filterQuaternion)
%BODYROTATION 概要：IMU Filter の姿勢を機体の前・右・下へ変換します。
% 推定器の角速度は [機体Y, 機体X, -機体Z]。同じ正規直交変換を
% クォータニオンのベクトル部と基準座標に適用します。表示Yawの180°
% オフセットは使わず、後段で離陸時の機首を局所座標の基準にします。
%#codegen
R=eye(3,'single');valid=false;
% 1. 非有限値・ゼロノルムの姿勢を除外します。
q=single(filterQuaternion(:));n2=sum(q.*q);
if ~all(isfinite(q)) || n2<single(.5) || n2>single(1.5),return;end
q=q/horizontal.mathSingle('sqrt',n2);
% 2. 推定器 [w,x,y,z] → 機体 [w,y,x,-z] とし、点の回転行列を作ります。
w=q(1);x=q(3);y=q(2);z=-q(4);two=single(2);
R=[1-two*(y*y+z*z),two*(x*y-w*z),two*(x*z+w*y); ...
   two*(x*y+w*z),1-two*(x*x+z*z),two*(y*z-w*x); ...
   two*(x*z-w*y),two*(y*z+w*x),1-two*(x*x+y*y)];
valid=true;
end
