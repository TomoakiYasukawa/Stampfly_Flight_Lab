function [command,run,reset,altEnable,angleEnable,velEnable,angleReset,flipFlag]=stepFn(raw,manual,auto,branch,controlMode,dt,oldFilter,lastThrust,phase,flipThrust,flipStart,flipDone,mode)
% angle_controlとrate_controlで異なるリセット条件を保持する。
%#codegen
persistent heldFlip;
if isempty(heldFlip),heldFlip=uint8(0);end
command=raw;
if manual,command=filterStep(raw,dt,single(.01),oldFilter);end
if branch==5 || branch==3 || flipDone,command=lastThrust;end
if branch==6 && phase>0,command=flipThrust;end
active=branch==2 || branch==5 || (branch==6 && ~flipDone);
angleCalled=active && (phase==0 || phase==1);
angleReset=angleCalled && double(command)/3.7<double(single(.1));
flipFlag=heldFlip;
if branch==3 || flipDone,flipFlag=uint8(0);end
if branch==6 && ~flipDone,flipFlag=phase;end
if flipStart,flipFlag=uint8(1);end
if angleReset,flipFlag=uint8(0);end
reset=active && double(command)/3.7<double(single(.1)) && flipFlag==0;
run=active && ~reset;
altEnable=angleCalled && ~angleReset && auto;
angleEnable=angleCalled && ~angleReset && uint8(controlMode)==0;
velEnable=run && ((auto && flipFlag==0) || mode==5);
if reset,flipFlag=uint8(0);end
heldFlip=flipFlag;
end
function s=filterStep(u,h,T,s),s=s*T/(T+h)+u*h/(T+h);end
