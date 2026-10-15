function [branch,nextMode,ahrsReset,parkingReset,s]=supervisorStep(button,connected,overG,height,ahrsFlag,s)
%SUPERVISORSTEP Official init/average/parking/flight/landing branch ordering.
% Arming requires a debounced press, release and 40 release checks.
% Flip is intentionally excluded from the takeoff/hover reproduction.
%#codegen
branch=s.mode;nextMode=s.mode;ahrsReset=false;parkingReset=false;
if s.mode==uint8(0)
    nextMode=uint8(1);
elseif s.mode==uint8(1)
    if s.calibration<uint16(800),s.calibration=s.calibration+uint16(1);
    else,nextMode=uint8(3);end
else
    % get_arming_button() is called only from judge_mode_change().
    if button~=0
        s.buttonCounter=s.buttonCounter+int8(1);
        if s.buttonCounter>int8(10),s.buttonCounter=int8(10);s.buttonState=uint8(1);end
    else
        s.buttonCounter=s.buttonCounter-int8(1);
        if s.buttonCounter<int8(-10),s.buttonCounter=int8(-10);s.buttonState=uint8(0);end
    end
    event=false;
    if s.chatter==0
        if s.buttonState==1,s.chatter=uint8(1);end
    elseif s.buttonState==0
        s.chatter=s.chatter+uint8(1);
        if s.chatter>uint8(40),s.chatter=uint8(0);event=true;end
    end
    if s.mode==uint8(3)
        if event,nextMode=uint8(2);ahrsReset=true;end
        if ahrsFlag~=s.lastAHRSFlag && ahrsFlag==1,ahrsReset=true;end
        s.lastAHRSFlag=ahrsFlag;parkingReset=true;
    elseif s.mode==uint8(2)
        if event || ~connected,nextMode=uint8(5);end
        if overG~=0,nextMode=uint8(3);end
        if nextMode~=s.mode,ahrsReset=true;end
    elseif s.mode==uint8(5)
        if height<single(0.1) || event,nextMode=uint8(3);end
    end
end
s.mode=nextMode;
end
