function [run,filterReset,A,B,C,Q]=KF400Schedule(mode,dt,parkingReset,processParameters)
%KF400SCHEDULE Preserve the original altitude estimator update schedule.
% C observes the predicted height so the standard block uses current dt/az.
%#codegen
persistent first previousMode pendingReset
if isempty(first)
    first=false;
    previousMode=uint8(0);
    pendingReset=false;
end
if parkingReset,pendingReset=true;end
if mode==uint8(3) && mode~=previousMode,first=false;end
run=false;
if mode>uint8(1)
    if first,run=true;else,first=true;end
end
filterReset=pendingReset;
if run,pendingReset=false;end
previousMode=mode;
h=single(dt);
velocityVariance=processParameters(1);
biasVariance=processParameters(2);
biasDecay=processParameters(3);
A=single([1 0 -h;h 1 0;0 0 1-h*biasDecay]);
B=single([h;0;0]);
% Original observation C0=[0 1 0]. Use C0*A=[h 1 0] for timing alignment.
C=single([h 1 0]);
Q=diag(single([velocityVariance*h*h;0;biasVariance*h*h]));
end
