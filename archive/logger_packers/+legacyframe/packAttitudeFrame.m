function frame = packAttitudeFrame(sequence,timeSeconds,accel,gyro, ...
        imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
        flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
        orientationValid)
%PACKATTITUDEFRAME Encode SFI3 with raw magnetometer and estimated attitude.
% The first 61 bytes keep the SFI2 payload layout. All numbers are little endian.
assert(numel(mag) == 3 && numel(orientation) == 4, ...
    'Expected Mag3 and Orientation4.');
base = legacyframe.packTelemetryFrame(sequence,timeSeconds,accel,gyro, ...
    imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
    flowStatus,flowShutter,xy,flowUsed);
frame = zeros(93,1,'uint8');
frame(1:61) = base(1:61);
frame(1:4) = uint8('SFI3');
frame(62:73) = reshape(typecast(single(mag(:)),'uint8'),12,1);
% Bit 0: most recent 25 Hz poll succeeded. Bit 1: this 50 Hz packet
% contains a new valid poll (even sequence numbers align with 25 Hz ticks).
newMagSample = magValid ~= 0 && bitand(uint16(sequence),uint16(1)) == 0;
frame(74) = uint8(magValid ~= 0) + bitshift(uint8(newMagSample),1);
q = single(orientation(:));
valid = orientationValid ~= 0 && all(isfinite(q)) && ...
    sum(q.^2) > single(1e-8);
if ~valid
    q = single([1;0;0;0]);
else
    q = q ./ sqrt(sum(q.^2));
end
frame(75:90) = reshape(typecast(q,'uint8'),16,1);
frame(91) = uint8(valid);
frame(92:93) = reshape(typecast(imu.crc16(frame(1:91)),'uint8'),2,1);
end
