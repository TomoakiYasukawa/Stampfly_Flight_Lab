function frame=packCommandExtension(sequence,t,buildID,revision,estimate,control)
%PACKCOMMANDEXTENSION SFIX190. Command values are full single precision.
% Reserved button/phase bytes stay zero for compatibility with StampFlyIMUApp.
% Layout is documented in docs/logging_extensions.md; all scalars little endian.
%#codegen
frame=zeros(190,1,'uint8');frame(1:4)=uint8('SFIX');
frame(5:6)=reshape(typecast(sequence,'uint8'),2,1);
frame(7:10)=reshape(typecast(uint32(max(0,floor(double(t)*1000))),'uint8'),4,1);
frame(11:14)=reshape(typecast(uint32(buildID),'uint8'),4,1);
frame(15:18)=reshape(typecast(uint32(revision),'uint8'),4,1);
frame(19:86)=reshape(typecast(single(estimate.ControlDiagnostics),'uint8'),68,1);
frame(87:110)=reshape(typecast(single(control.Pilot.Sticks),'uint8'),24,1);
frame(111:126)=reshape(typecast(single(control.Duty),'uint8'),16,1);
frame(127:130)=control.AppliedCounts;
frame(131:146)=reshape(typecast(uint32(control.PWMStatus([2 3 1 4])),'uint8'),16,1);
frame(147:154)=uint8([control.Pilot.ArmButton;control.Pilot.NewPacket;control.Pilot.AHRSRequest; ...
    uint8(0);control.PacketError;control.Connected;control.AltitudeEnabled;uint8(0)]);
frame(155)=uint8(control.PreviousMode);frame(156)=uint8(control.Mode);
frame(157:160)=reshape(typecast(single(control.Dt),'uint8'),4,1);
frame(161:164)=reshape(typecast(uint32(control.StartUs),'uint8'),4,1);
frame(165:188)=reshape(typecast(single(control.UsedSticks),'uint8'),24,1);
frame(189:190)=reshape(typecast(imu.crc16(frame(1:188)),'uint8'),2,1);
end
