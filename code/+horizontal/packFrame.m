function frame=packFrame(sequence,time,buildID,revision,diagnostics24,motion)
%PACKFRAME 概要：水平補助の指令・有効性をCRC付きSFIH182へ記録します。
% 従来3パケットは維持し、水平補助だけを独立した補足パケットにします。
% 先頭18byteはSFIX/SFIYと同じSequence・時刻・ビルド識別です。
%#codegen
frame=zeros(182,1,'uint8');frame(1:4)=uint8('SFIH');
frame(5:6)=reshape(typecast(uint16(sequence),'uint8'),2,1);
frame(7:10)=reshape(typecast(uint32(max(0,floor(double(time)*1000))),'uint8'),4,1);
frame(11:14)=reshape(typecast(uint32(buildID),'uint8'),4,1);
frame(15:18)=reshape(typecast(uint32(revision),'uint8'),4,1);
values=single([diagnostics24(:);motion.Status(:);motion.Diagnostics(:)]);
frame(19:178)=reshape(typecast(values,'uint8'),160,1);
frame(179:180)=uint8(0);
frame(181:182)=reshape(typecast(imu.crc16(frame(1:180)),'uint8'),2,1);
end
