function scales = heightTuningScales()
%HEIGHTTUNINGSCALES Fixed-point units in the SFP1 height parameter packet.
% Order: position P, vertical velocity P/I, filter time, max correction,
% takeoff throttle, hover throttle, max vertical speed, landing throttle.
scales = single([1000;100;100;1000;10;10;10;1000;10]);
end
