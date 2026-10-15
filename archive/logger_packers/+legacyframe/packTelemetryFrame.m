function frame = packTelemetryFrame(sequence,timeSeconds,accel,gyro, ...
        imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
        flowStatus,flowShutter,xy,flowUsed)
%PACKTELEMETRYFRAME Encode one 63-byte SFI2 sensor packet.
% All multibyte values are little endian. Positions are MATLAB 1-based.
assert(numel(accel) == 3 && numel(gyro) == 3 && ...
    numel(flowDelta) == 2 && numel(xy) == 2, ...
    'Expected Accel3, Gyro3, Flow2, and XY2.');
frame = zeros(63,1,'uint8');
frame(1:4) = uint8('SFI2');
frame(5:6) = reshape(typecast(uint16(sequence),'uint8'),2,1);
milliseconds = uint32(max(0,floor(double(timeSeconds)*1000)));
frame(7:10) = reshape(typecast(milliseconds,'uint8'),4,1);
frame(11:34) = reshape(typecast(single([accel(:);gyro(:)]),'uint8'),24,1);
frame(35) = uint8(imuValid);
frame(36:39) = reshape(typecast(single(tofM),'uint8'),4,1);
frame(40) = uint8(tofValid);
frame(41) = uint8(tofRangeStatus);
frame(42:49) = reshape(typecast(single(flowDelta(:)),'uint8'),8,1);
frame(50) = uint8(flowQuality);
frame(51) = uint8(flowStatus);
frame(52) = uint8(flowShutter);
frame(53:60) = reshape(typecast(single(xy(:)),'uint8'),8,1);
frame(61) = uint8(flowUsed);
frame(62:63) = reshape(typecast(imu.crc16(frame(1:61)),'uint8'),2,1);
end
