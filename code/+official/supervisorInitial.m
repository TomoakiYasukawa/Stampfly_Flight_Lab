function s=supervisorInitial()
%#codegen
s=struct('mode',uint8(0),'calibration',uint16(0),'buttonCounter',int8(0), ...
    'buttonState',uint8(0),'chatter',uint8(0),'lastAHRSFlag',uint8(0));
end
