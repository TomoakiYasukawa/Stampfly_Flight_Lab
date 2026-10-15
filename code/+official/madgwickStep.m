function [attitude,q] = madgwickStep(rates,accel,q,reset)
%MADGWICKSTEP Official updateIMU with body-axis conventions and invSqrt.
% Rates rad/s and accel g in official body frame [forward;left;down].
% Madgwick is fixed 400 Hz even though other official filters use measured dt.
% Translation of lib/MdgwickAHRS/MadgwickAHRS.cpp; original license retained.
%#codegen
if reset, q=single([1;0;0;0]); end
q0=q(1);q1=q(2);q2=q(3);q3=q(4);
% Retain original rad->deg->rad conversion coefficients, including rounding.
g=rates([2 1 3])*single(180/pi);g(3)=-g(3);
g=g*single(0.0174533);gx=g(1);gy=g(2);gz=g(3);
a=accel([2 1 3]);a(3)=-a(3);ax=a(1);ay=a(2);az=a(3);
dq=single(0.5)*[-q1*gx-q2*gy-q3*gz; q0*gx+q2*gz-q3*gy; ...
    q0*gy-q1*gz+q3*gx; q0*gz+q1*gy-q2*gx];
if ax~=0 || ay~=0 || az~=0
    reciprocal=fastInvSqrt(ax*ax+ay*ay+az*az);
    ax=ax*reciprocal;ay=ay*reciprocal;az=az*reciprocal;
    q02=q0*q0;q12=q1*q1;q22=q2*q2;q32=q3*q3;
    q0x2=single(2)*q0;q1x2=single(2)*q1;q2x2=single(2)*q2;q3x2=single(2)*q3;
    q0x4=single(4)*q0;q1x4=single(4)*q1;q2x4=single(4)*q2;
    q1x8=single(8)*q1;q2x8=single(8)*q2;
    gradient=[q0x4*q22+q2x2*ax+q0x4*q12-q1x2*ay; ...
        q1x4*q32-q3x2*ax+single(4)*q02*q1-q0x2*ay-q1x4+q1x8*q12+q1x8*q22+q1x4*az; ...
        single(4)*q02*q2+q0x2*ax+q2x4*q32-q3x2*ay-q2x4+q2x8*q12+q2x8*q22+q2x4*az; ...
        single(4)*q12*q3-q1x2*ax+single(4)*q22*q3-q2x2*ay];
    reciprocal=fastInvSqrt(gradient(1)*gradient(1)+gradient(2)*gradient(2)+gradient(3)*gradient(3)+gradient(4)*gradient(4));
    gradient=gradient*reciprocal;
    dq=dq-single(0.1)*gradient;
end
q=q+dq*single(1/400);
reciprocal=fastInvSqrt(q(1)*q(1)+q(2)*q(2)+q(3)*q(3)+q(4)*q(4));q=q*reciprocal;
roll=atan2(q(1)*q(2)+q(3)*q(4),single(0.5)-q(2)*q(2)-q(3)*q(3));
pitch=asin(-single(2)*(q(2)*q(4)-q(1)*q(3)));
yaw=atan2(q(2)*q(3)+q(1)*q(4),single(0.5)-q(3)*q(3)-q(4)*q(4));
% Original getYaw adds 180 degrees; do not hide this offset.
attitude=[pitch*single(57.29578);roll*single(57.29578); ...
    -(yaw*single(57.29578)+single(180))]*single(pi/180);
end

function y=fastInvSqrt(x)
i=typecast(x,'uint32');i=uint32(hex2dec('5f3759df'))-bitshift(i,-1);
y=typecast(i,'single');half=single(0.5)*x;
y=y*(single(1.5)-half*y*y);y=y*(single(1.5)-half*y*y);
end
