function result=import_official_log(file)
%IMPORT_OFFICIAL_LOG Decode USB SFI8 capture with the copied MAT recording system.
arguments
    file (1,1) string
end
fid=fopen(file,'rb');assert(fid>=0,'official:LogFile','Cannot read capture');
cleanup=onCleanup(@()fclose(fid));bytes=fread(fid,inf,'*uint8');
starts=strfind(char(bytes.'),'SFI8');
writer=imu.MatRecordingWriter(string(fullfile(stampfly_project_root(),'recordings')), ...
    struct('Project','Official400','Source',file,'MotorOutputEnabled',false,'RadioChannel',3));
bad=0;missing=0;last=[];states=[];ranges=[];times=[];fresh=[];motorMax=0;
for k=starts
    if k+189>numel(bytes),continue;end
    frame=bytes(k:k+189);
    try,sample=imu.decodeFrame(frame);catch,bad=bad+1;continue;end
    if ~isempty(last)
        gap=mod(double(sample.Sequence)-last,65536);
        if gap>1 && gap<32768,missing=missing+gap-1;end
    end
    last=double(sample.Sequence);writer.append(sample,frame);
    states(end+1)=double(sample.FlightState);ranges(end+1)=double(sample.ToFDistanceM);
    times(end+1)=sample.TimeSeconds;fresh(end+1)=sample.ToFFresh;
    motorMax=max(motorMax,max(double(sample.MotorCommands)));
end
path=writer.finish(missing,bad);
result=struct('MATFile',path,'ValidFrames',writer.Count,'CRCRejected',bad, ...
    'MissingFrames',missing,'States',unique(states),'RangeMinMaxM',[min(ranges) max(ranges)], ...
    'LogRateHz',1/median(diff(times)),'ComputedMotorMax',motorMax,'ToFFreshFraction',mean(fresh));
disp(result);
end
