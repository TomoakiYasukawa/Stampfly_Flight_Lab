function [y,s] = pidStep(e,h,g,s)
%PIDSTEP Exact PID::update recurrence. State = [integral; differential; error].
% Derived from M5StampFly/src/pid.cpp (MIT, Kouhei Ito and M5Stack, 2024).
%#codegen
s(1) = s(1) + h*(e+s(3))/single(2)/g(2);
s(1) = min(max(s(1),single(-30000)),single(30000));
s(2) = (single(2)*g(4)*g(3)-h)*s(2)/(single(2)*g(4)*g(3)+h) ...
    + single(2)*g(3)*(e-s(3))/(single(2)*g(4)*g(3)+h);
s(3) = e;
y = g(1)*(e+s(1)+s(2));
end
