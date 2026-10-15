function [y,s] = kalmanStep(z,acc,h,resetState,s)
%KALMANSTEP Direct translation of Alt_kalman::update, state [v;z;bias].
% Preserve reset(): covariance and public output reset, private x is retained.
%#codegen
if resetState
    s.P = single(100)*eye(3,'single'); s.output(:) = single(0);
else
    p=s.P; b=single(-0.01); f=single(1)+h*b;
    xp=[s.x(1)+(acc-s.x(3))*h;s.x(2)+s.x(1)*h;s.x(3)*f];
    pp=zeros(3,3,'single');
    pp(1,1)=p(1,1)-h*(p(3,1)+p(1,3))+h*h*p(3,3)+h*h*single(0.01);
    pp(1,2)=h*(p(1,1)-p(3,2))-h*h*p(3,1)+p(1,2);
    pp(1,3)=f*(p(1,3)-h*p(3,3));
    pp(2,1)=h*(p(1,1)-p(2,3))-h*h*p(1,3)+p(2,1);
    pp(2,2)=h*h*p(1,1)+h*(p(2,1)+p(1,2))+p(2,2);
    pp(2,3)=f*(p(2,3)+h*p(1,3));
    pp(3,1)=f*(p(3,1)-h*p(3,3));
    pp(3,2)=f*(p(3,2)+h*p(3,1));
    pp(3,3)=f*f*p(3,3)+h*h;
    k=[pp(1,2);pp(2,2);pp(3,2)]/(pp(2,2)+single(0.004*0.004));
    e=z-xp(2); s.x=xp+k*e; s.output=s.x;
    s.P(1,:)=pp(1,:)-k(1)*pp(2,:);
    s.P(2,:)=pp(2,:)*(single(1)-k(2));
    s.P(3,:)=-k(3)*pp(2,:)+pp(3,:);
end
y=s.output;
end
