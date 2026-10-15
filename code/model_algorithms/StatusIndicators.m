function [color1,color2,tone,restart]=stepFn(mode,controlMode,altFlag,flipFlag,lowVoltage,rcError,ahrsFlag,button)
% 公式led_driveの状態色。ブザーの200ms待機は400Hzカウンターへ置換。
%#codegen
persistent Blink Rainbow C1 C2 Tick AHRSPrev ToneTicks ButtonCount WasPressed;
if isempty(Blink)
 Blink=uint16(0);Rainbow=uint32(255);C1=uint32(0);C2=uint32(0);Tick=uint16(0);AHRSPrev=uint8(0);ToneTicks=uint16(0);ButtonCount=uint8(0);WasPressed=false;
end
if mode==1,C1=uint32(hex2dec('FF00FF'));C2=C1;
elseif mode==5,C1=uint32(hex2dec('00FF00'));C2=C1;
elseif mode==2
 c=uint32(hex2dec('FFFF00'));
 if controlMode~=0,c=uint32(hex2dec('DC669B'));elseif flipFlag~=0,c=uint32(hex2dec('FF9933'));end
 if altFlag>=1,c=uint32(hex2dec('331155'));end
 if rcError==1,c=uint32(hex2dec('FF0000'));end
 C1=c;C2=c;if lowVoltage>=100,C1=uint32(hex2dec('18EBF9'));end
elseif mode==3
 if lowVoltage<100
  if Blink==0
   top=bitand(Rainbow,uint32(hex2dec('800000')))~=0;Rainbow=bitshift(Rainbow,1);if top,Rainbow=bitor(Rainbow,uint32(1));end
   C1=Rainbow;C2=Rainbow;Blink=Blink+uint16(1);
  end
  Blink=Blink+uint16(1);if Blink>20,Blink=uint16(0);end
 else
  if Blink<10,C1=uint32(hex2dec('18EBF9'));C2=C1;
  elseif Blink<200,C1=uint32(0);C2=uint32(0);else,Blink=uint16(0);end
  Blink=Blink+uint16(1);
 end
 if ahrsFlag~=AHRSPrev && ahrsFlag==1,ToneTicks=uint16(80);end
 AHRSPrev=ahrsFlag;
end
tone=uint32(0);
% Startup notes from official buzzer.h. Four 200ms notes, then silence.
if Tick<320
 notes=uint32([294 441 350 393]);idx=min(floor(double(Tick)/80)+1,4);tone=notes(idx);Tick=Tick+uint16(1);
elseif ToneTicks>0,tone=uint32(4000);ToneTicks=ToneTicks-uint16(1);end
restart=false;
if button==1,ButtonCount=min(ButtonCount+uint8(1),uint8(40));if ButtonCount>=4,WasPressed=true;end
elseif WasPressed,restart=true;WasPressed=false;ButtonCount=uint8(0);else,ButtonCount=uint8(0);end
% FastLED brightness15, show32: cap displayed channels without changing logic.
color1=scale(C1);color2=scale(C2);
end
function c=scale(x)
r=bitand(bitshift(x,-16),uint32(255));g=bitand(bitshift(x,-8),uint32(255));b=bitand(x,uint32(255));
c=bitor(bitor(bitshift(uint32(double(r)*15/255),16),bitshift(uint32(double(g)*15/255),8)),uint32(double(b)*15/255));
end
