function frame = packHeightFrame(sequence,timeSeconds,accel,gyro, ...
        imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
        flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
        orientationValid,heightM,heightValid,flowDeltaEN,skipCRC)
if nargin < 22,skipCRC=false;end
%PACKHEIGHTFRAME Encode SFI4 with raw ToF and onboard corrected height.
% Bytes 1:91 keep the SFI3 payload. All numbers are little endian.
base = imu.packAttitudeFrame(sequence,timeSeconds,accel,gyro, ...
    imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
    flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
    orientationValid,true);
assert(numel(flowDeltaEN) == 2,'Expected CorrectedDeltaEN2.');
frame = zeros(106,1,'uint8');
frame(1:91) = base(1:91);
frame(1:4) = uint8('SFI4');
valid = heightValid ~= 0 && isfinite(heightM) && heightM >= 0;
if valid
    height = single(heightM);
else
    height = single(NaN);
end
frame(92:95) = reshape(typecast(height,'uint8'),4,1);
frame(96) = uint8(valid);
frame(97:104) = reshape(typecast(single(flowDeltaEN(:)),'uint8'),8,1);
if ~skipCRC
    frame(105:106) = reshape(typecast(imu.crc16(frame(1:104)),'uint8'),2,1);
end
end
