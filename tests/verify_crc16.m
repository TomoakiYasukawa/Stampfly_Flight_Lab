function report=verify_crc16()
%VERIFY_CRC16 表参照CRCをビット単位の独立定義と比較する。
% 既知値、全256 byte、実ログ長と乱数で通信形式の一致を確認します。
assert(imu.crc16(uint8('123456789'))==uint16(hex2dec('29B1')));
for value=0:255
    bytes=uint8(value);assert(imu.crc16(bytes)==bitwise(bytes));
end
state=rng;cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(83);lengths=[0 1 2 5 13 26 35 61 91 104 109 112 180 188 244 256 1000];
for length=lengths
    for trial=1:20
        bytes=uint8(randi([0 255],length,1));assert(imu.crc16(bytes)==bitwise(bytes));
    end
end
report=struct('Passed',true,'KnownVector',true,'AllByteValues',true,'RandomVectors',numel(lengths)*20);
fprintf('CRC16_REFERENCE_VERIFICATION_PASSED\n');
end
function crc=bitwise(bytes)
crc=uint16(65535);
for value=bytes(:)'
    crc=bitxor(crc,bitshift(uint16(value),8));
    for k=1:8
        high=bitand(crc,uint16(32768))~=0;crc=bitshift(crc,1);
        if high,crc=bitxor(crc,uint16(4129));end
    end
end
end
