function frame = packMotorFrame(sequence,timeSeconds,accel,gyro, ...
        imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
        flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
        orientationValid,heightM,heightValid,flowDeltaEN,motorCommands,motorValid,skipCRC)
if nargin < 24,skipCRC=false;end
%PACKMOTORFRAME Encode SFI5 sensor data and virtual motor commands.
% Motor order: front right, front left, rear right, rear left.
% No physical motor output is connected to these values.
base = imu.packHeightFrame(sequence,timeSeconds,accel,gyro, ...
    imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
    flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
    orientationValid,heightM,heightValid,flowDeltaEN,true);
assert(numel(motorCommands) == 4,'Expected four motor commands.');
frame = zeros(111,1,'uint8');
frame(1:104) = base(1:104);
frame(1:4) = uint8('SFI5');
valid = motorValid ~= 0 && all(isfinite(double(motorCommands(:))));
if valid
    frame(105:108) = uint8(min(max(round(double(motorCommands(:))),0),255));
end
frame(109) = uint8(valid);
if ~skipCRC
    frame(110:111) = reshape(typecast(imu.crc16(frame(1:109)),'uint8'),2,1);
end
end
