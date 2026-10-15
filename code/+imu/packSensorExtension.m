function frame=packSensorExtension(sequence,t,buildID,revision,raw,estimate,control,extra)
%PACKSENSOREXTENSION SFIY246. Sensor-only diagnostics; no control feedback.
%#codegen
frame=zeros(246,1,'uint8');frame(1:4)=uint8('SFIY');
frame(5:6)=reshape(typecast(sequence,'uint8'),2,1);
frame(7:10)=reshape(typecast(uint32(max(0,floor(double(t)*1000))),'uint8'),4,1);
frame(11:14)=reshape(typecast(uint32(buildID),'uint8'),4,1);
frame(15:18)=reshape(typecast(uint32(revision),'uint8'),4,1);
frame(19:50)=reshape(typecast(single(estimate.SensorDiagnostics),'uint8'),32,1);
frame(51:62)=reshape(typecast(single(estimate.FilteredAccel),'uint8'),12,1);
frame(63:74)=reshape(typecast(single(estimate.FilteredGyro),'uint8'),12,1);
frame(75:90)=reshape(typecast(single(estimate.Quaternion),'uint8'),16,1);
frame(91:98)=reshape(typecast(single(extra.Flow.Delta),'uint8'),8,1);
frame(99:114)=reshape(typecast(uint32(extra.Flow.Info),'uint8'),16,1);
frame(115:122)=reshape(typecast(uint32(extra.Flow.Totals),'uint8'),8,1);
frame(123:138)=reshape(typecast(uint16(extra.Flow.Raw),'uint8'),16,1);
frame(139:162)=reshape(typecast(uint32(extra.Mag.Info),'uint8'),24,1);
frame(163:165)=extra.Mag.Flags;frame(166:168)=estimate.Flags;
frame(169:172)=reshape(typecast(single(raw.Temperature),'uint8'),4,1);
frame(173:176)=reshape(typecast(single(control.Dt),'uint8'),4,1);
frame(177:208)=reshape(typecast(uint32(extra.Timing),'uint8'),32,1);
frame(209:224)=reshape(typecast(uint32(extra.Scheduler),'uint8'),16,1);
frame(225:240)=reshape(typecast(uint32(raw.ToFInfo),'uint8'),16,1);
frame(241:244)=uint8([raw.IMUFresh;raw.BatteryValid;control.OutputEnabled;0]);
frame(245:246)=reshape(typecast(imu.crc16(frame(1:244)),'uint8'),2,1);
end
