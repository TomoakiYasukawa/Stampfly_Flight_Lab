function [alt,base,counter,raw,auto,manual,controlMode]=stepFn(stick,height,voltage,rangeFlag,branch,phase,flipDone)
% 公式get_command/auto_landing。Alt_flagはManual切替時にも保持される。
%#codegen
persistent Alt Base Counter RangeOld Landing History AltFlag ControlMode;
if isempty(Alt)
 Alt=single(.5);Base=single(0);Counter=uint16(0);RangeOld=uint8(0);
 Landing=false;History=zeros(10,1,'single');AltFlag=false;ControlMode=uint8(0);
end
raw=single(0);manual=false;
if branch==3
 Base=single(0);Alt=single(.5);Counter=uint16(0);Landing=false;AltFlag=false;
elseif branch==2 || (branch==6 && phase==0 && ~flipDone)
 ControlMode=uint8(stick(5));
 if uint8(stick(6))==4
  AltFlag=true;
  if Counter<500
   Base=min(single(Counter)/single(1000),trim(single(3.8)));Counter=Counter+uint16(1);
  elseif Counter<1000
   Base=min(single(Counter)/single(1000),trim(voltage));Counter=Counter+uint16(1);
  else,Base=trim(voltage);end
  th=stick(4);if th>-.2 && th<.2,th=single(0);end
  Alt=min(max(single(double(Alt)+double(th)*.001),single(.05)),single(1.8));
  if rangeFlag>RangeOld || rangeFlag==20,Base=Base-single(.02);RangeOld=rangeFlag;end
  raw=single(double(Base)*3.7);
 else
  manual=true;th=min(max(stick(4),single(0)),single(1));
  if th>-.2 && th<.2,th=single(0);end
  raw=single((.00413+double(single(3.3)*th-single(5.44)*th*th+single(3.13)*th*th*th))*3.7);
 end
elseif branch==5
 AltFlag=false;
 if ~Landing,Landing=true;History(:)=height;Base=trim(voltage);end
 if History(10)>=height,Base=single(double(Base)*.9999);end
 if height<.15,Base=single(double(Base)*.999);end
 if height<.1,Landing=false;end
 for j=2:10,History(j)=History(j-1);end
 History(1)=height;
end
alt=Alt;base=Base;counter=Counter;auto=AltFlag;controlMode=single(ControlMode);
end
function y=trim(v),y=-single(.2448)*v+single(1.5892);end
