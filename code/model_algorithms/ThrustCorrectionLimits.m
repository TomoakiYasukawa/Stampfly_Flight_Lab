function [thrust,filter,last]=stepFn(command,correction,base,auto,manual,velEnable,branch,dt,oldFilter,lastThrust,flipFlag)
% rate_control: Auto補正がLanding補正より優先。Flip中はAuto補正を停止。
%#codegen
thrust=command;filter=oldFilter;
if branch==3,filter=single(0);elseif manual,filter=command;end
if velEnable
 filter=filterStep(single(double(base+correction)*3.7),dt,single(.01),filter);thrust=filter;
 if auto && flipFlag==0
  if double(thrust)/3.7>double(single(base*single(1.15))),thrust=single(3.7*double(base)*double(single(1.15)));end
  if double(thrust)/3.7<double(single(base*single(.85))),thrust=single(3.7*double(base)*double(single(.85)));end
 end
end
if branch==3,thrust=lastThrust;last=lastThrust;else,last=thrust;end
end
function s=filterStep(u,h,T,s),s=s*T/(T+h)+u*h/(T+h);end
