function frame = packFrame(sequence, timeSeconds, accel, gyro, status)
%PACKFRAME Encode one 37-byte SFI1 IMU packet for ESP-NOW and USB.
% All multibyte fields use little-endian byte order.
frame = zeros(37, 1, 'uint8');
frame(1:4) = uint8('SFI1');
frame(5:6) = reshape(typecast(uint16(sequence), 'uint8'), 2, 1);
milliseconds = uint32(max(0, floor(double(timeSeconds) * 1000)));
frame(7:10) = reshape(typecast(milliseconds, 'uint8'), 4, 1);
values = single([accel(:); gyro(:)]);
assert(numel(values) == 6, 'Expected three acceleration and three gyro values.');
frame(11:34) = reshape(typecast(values, 'uint8'), 24, 1);
frame(35) = uint8(status);
frame(36:37) = reshape(typecast(imu.crc16(frame(1:35)), 'uint8'), 2, 1);
end
