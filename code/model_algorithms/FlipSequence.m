function [start,done,phase,thrust,rollRate,angleReset,ahrsReset,normalControl]=stepFn(button,branch,voltage,previousReset,lastRate)
% 公式 flip(): 180 + 40*4 + 10 + 190 tick。制御は別のPIDブロック。
%#codegen
persistent counter buttonCount rate didReset;
if isempty(counter),counter=uint16(0);buttonCount=uint8(0);rate=single(0);didReset=false;end
start=false;done=false;phase=uint8(0);thrust=single(0);rollRate=single(0);angleReset=false;ahrsReset=false;normalControl=true;
if branch==3 || previousReset,counter=uint16(0);rate=single(0);didReset=false;end
if branch==6
 rate=lastRate(1);
 T=single(double(-single(.2448)*voltage+single(1.5892))*3.7);
 flipTime=single(.4);flipStep=uint16(fix(flipTime/single(.0025)));quarter=idivide(flipStep,uint16(4));
 domega=single(double(single(.00217))*8*pi/double(flipTime)/double(flipTime));
 if counter<180
  phase=uint8(1);normalControl=false;
  if voltage>3.8,thrust=single(double(T)+.17*3.7);else,thrust=single(double(T)+.15*3.7);end
 elseif counter<180+quarter
  phase=uint8(2);normalControl=false;thrust=T*single(.3);rate=rate+domega;
 elseif counter<180+2*quarter
  phase=uint8(3);normalControl=false;thrust=T*single(.15);rate=rate+domega;
 elseif counter<180+3*quarter
  phase=uint8(4);normalControl=false;thrust=T*single(.15);rate=rate-domega;
 elseif counter<180+flipStep
  phase=uint8(5);normalControl=false;thrust=T;rate=rate-domega;
 elseif counter<190+flipStep
  phase=uint8(6);normalControl=false;thrust=single(double(T)+double(single(.18))*3.7);rate=single(0);angleReset=true;
  if ~didReset,ahrsReset=true;didReset=true;end
 elseif counter<380+flipStep,normalControl=true;
 else,done=true;normalControl=false;counter=uint16(0);didReset=false;
 end
 rollRate=rate;if ~done,counter=counter+uint16(1);end
end
if branch==2 || (branch==6 && normalControl)
 if button==1
  buttonCount=buttonCount+uint8(1);
  if buttonCount>uint8(10),buttonCount=uint8(0);start=true;end
 else,buttonCount=uint8(0);end
end
end
