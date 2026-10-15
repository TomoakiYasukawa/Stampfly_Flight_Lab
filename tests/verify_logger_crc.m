function result=verify_logger_crc()
%VERIFY_LOGGER_CRC Compare all byte values and deterministic packet data.
assert(imu.crc16(uint8('123456789'))==uint16(hex2dec('29B1')));
for len=[0 1 37 63 93 106 111 114 182 188 190 256 1024]
 bytes=uint8(mod((0:len-1)*73+29,256));assert(imu.crc16(bytes)==original(bytes));
end
for byte=0:255,assert(imu.crc16(uint8(byte))==original(uint8(byte)));end
result=struct('ByteValues',256,'PacketLengths',13,'KnownVector','29B1','Passed',true);
save(fullfile(fileparts(mfilename('fullpath')),'logger_crc_verification.mat'),'result');disp(result);
end
function crc=original(bytes)
crc=uint16(65535);
for k=1:numel(bytes)
 crc=bitxor(crc,bitshift(uint16(bytes(k)),8));
 for bit=1:8
  if bitand(crc,uint16(32768)),crc=bitxor(bitshift(crc,1),uint16(4129));else,crc=bitshift(crc,1);end
 end
end
end
