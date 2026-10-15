function [branch,mode,ahrsReset,parkingReset,connected]=stepFn(previousMode,button,newPacket,flags,ahrsFlag)
% 公式loop_400Hzの分岐開始時。遷移後も現在の分岐を最後まで実行する。
%#codegen
persistent calibration buttonCounter buttonState chatter lastAHRS connectionCounter;
if isempty(calibration)
 calibration=uint16(0);buttonCounter=int8(0);buttonState=uint8(0);
 chatter=uint8(0);lastAHRS=uint8(0);connectionCounter=uint16(0);
end
branch=previousMode;mode=branch;ahrsReset=false;parkingReset=branch==3;
if newPacket~=0,connectionCounter=uint16(0);end
connected=uint8(connectionCounter<uint16(40));
if branch==0,mode=uint8(1);
elseif branch==1
 if calibration<uint16(800),calibration=calibration+uint16(1);else,mode=uint8(3);end
else
 if button==1
  buttonCounter=buttonCounter+int8(1);
  if buttonCounter>int8(10),buttonCounter=int8(10);buttonState=uint8(1);end
 else
  buttonCounter=buttonCounter-int8(1);
  if buttonCounter<int8(-10),buttonCounter=int8(-10);buttonState=uint8(0);end
 end
 event=false;
 if chatter==0
  if buttonState==1,chatter=uint8(1);end
 elseif buttonState==0
  chatter=chatter+uint8(1);
  if chatter>uint8(40),chatter=uint8(0);event=true;end
 end
 if branch==3
  if event,mode=uint8(2);ahrsReset=true;end
  if ahrsFlag~=lastAHRS
   if ahrsFlag==1,ahrsReset=true;end
   lastAHRS=ahrsFlag;
  end
 elseif branch==2 || branch==6
  connectionCounter=uint16(mod(double(connectionCounter)+1,65536));
  connected=uint8(connectionCounter<uint16(40));
  if event,mode=uint8(5);end
  if connected==0,mode=uint8(5);end
  if flags(1)==1,mode=uint8(3);end
  if branch==2 && mode~=branch,ahrsReset=true;end
 elseif branch==5
  if event,mode=uint8(3);end
 end
end
end
