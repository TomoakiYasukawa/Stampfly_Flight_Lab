function crc = crc16(bytes)
%CRC16 CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF).
% Four-bit ROM lookup: identical checksum with two updates per byte.
crc=uint16(65535);
table=uint16([0 4129 8258 12387 16516 20645 24774 28903 ...
    33032 37161 41290 45419 49548 53677 57806 61935]);
data=uint8(bytes(:));
for k=1:numel(data)
    crc=bitxor(crc,bitshift(uint16(data(k)),8));
    index=double(bitshift(crc,-12))+1;
    crc=bitxor(bitshift(crc,4),table(index));
    index=double(bitshift(crc,-12))+1;
    crc=bitxor(bitshift(crc,4),table(index));
end
end
