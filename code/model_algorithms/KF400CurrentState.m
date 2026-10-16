function state=KF400CurrentState(xhat,az,dt,processParameters)
%KF400CURRENTSTATE Export the posterior at the original estimator's time.
% The standard current estimator corrects the previous state; advance it here.
%#codegen
x=single(xhat(:));h=single(dt);
state=single([x(1)+(az-x(3))*h;
    x(2)+x(1)*h;
    x(3)*(single(1)-processParameters(3)*h)]);
end
