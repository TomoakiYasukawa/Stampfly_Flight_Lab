function frame = packFlightDiagnosticsFrame(sequence,timeSeconds,accel,gyro, ...
        imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
        flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
        orientationValid,heightM,heightValid,flowDeltaEN,motorCommands, ...
        motorValid,flightState,acceptedCommandSequence,diagnostics,buildID,skipCRC)
if nargin < 28,skipCRC=false;end
%PACKFLIGHTDIAGNOSTICSFRAME SFI7, 182 bytes, including CRC-16.
% First 112 bytes retain the SFI6 data layout. The 32 diagnostics are
% signed int16 with per-field scales; -32768 denotes an unavailable value.
base = imu.packFlightFrame(sequence,timeSeconds,accel,gyro, ...
    imuValid,tofM,tofValid,tofRangeStatus,flowDelta,flowQuality, ...
    flowStatus,flowShutter,xy,flowUsed,mag,magValid,orientation, ...
    orientationValid,heightM,heightValid,flowDeltaEN,motorCommands, ...
    motorValid,flightState,acceptedCommandSequence,true);
assert(numel(diagnostics) == 32,'imu:DiagnosticShape', ...
    'Expected 32 SFI7 diagnostic values.');
values = single(diagnostics(:));
scales = imu.flightDiagnosticScales();
quantized = zeros(32,1,'int16');
for k = 1:32
    if ~isfinite(values(k))
        quantized(k) = int16(-32768);
    else
        bounded = min(max(round(values(k)*scales(k)),single(-32767)), ...
            single(32767));
        quantized(k) = int16(bounded);
    end
end
frame = zeros(182,1,'uint8');
frame(1:112) = base(1:112);
frame(1:4) = uint8('SFI7');
frame(113:176) = reshape(typecast(quantized,'uint8'),64,1);
frame(177:180) = reshape(typecast(uint32(buildID),'uint8'),4,1);
if ~skipCRC
    frame(181:182) = reshape(typecast(imu.crc16(frame(1:180)),'uint8'),2,1);
end
end
