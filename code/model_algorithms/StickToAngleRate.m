function [angle,directRate,resetError]=stepFn(stick,branch,run,reset,phase,flipRate,angleReset,lastRate,flipDone,controlMode)
% command、角度目標、中立点を別々に保持。Sportは角度commandを更新しない。
%#codegen
persistent Angle Centers AngleCmd YawCmd;
if isempty(Angle),Angle=zeros(2,1,'single');Centers=zeros(3,1,'single');AngleCmd=zeros(2,1,'single');YawCmd=single(0);end
directRate=lastRate;resetError=Angle;
commandCalled=branch==2 || branch==5 || (branch==6 && phase==0 && ~flipDone);
if commandCalled
 if uint8(controlMode)==0 || branch==5,AngleCmd=min(max(single(.4*double(stick(1:2))),single(-1)),single(1));end
 YawCmd=min(max(stick(3),single(-1)),single(1));
 directRate(3)=single(2*pi*double(YawCmd-Centers(3)));
 if uint8(controlMode)==1,directRate(1)=rateCommand(stick(1));directRate(2)=rateCommand(stick(2));end
elseif branch==6 && phase==1,AngleCmd(:)=single(0);
end
if angleReset,Centers(1:2)=AngleCmd;end
if reset,Centers(3)=YawCmd;end
if run && (phase==0 || phase==1) && uint8(controlMode)==0
 limit=single(30*pi/180);Angle=min(max(single(.5*pi*double(AngleCmd-Centers(1:2))),-limit),limit);
end
if branch==6 && phase>=2,directRate(1)=flipRate;directRate(2)=single(0);end
if branch==3,directRate(1)=single(0);end
if reset,directRate(:)=single(0);end
angle=Angle;
end
function y=rateCommand(x)
x=min(max(x,single(-1)),single(1));a=abs(x);t=a*(a*a*a*a*a*single(.5)+a*single(.5));
y=single(pi/180)*((single(1600)-single(70))*t+single(70)*a);if x<0,y=-y;end
end
