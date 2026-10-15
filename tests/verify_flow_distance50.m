function report=verify_flow_distance50()
%VERIFY_FLOW_DISTANCE50 既存の距離換算との一致、回転除去、累積巡回を確認。
adapter=imu.FlowDistance50;original=imu.GroundFlowXYTracker;
cleanup=onCleanup(@()releaseBoth(adapter,original)); %#ok<NASGU>
raw=uint16([80;4000;128;0;40;60;10;1]);
gyro=zeros(3,1,'single');pose=single([0;0;0;.5]);totals=zeros(2,1,'uint32');
adapter(totals,raw,gyro,pose);
original(single([0;0]),uint8(raw(1)),uint8(1),uint8(bitshift(raw(2),-8)), ...
    single(.5),uint8(1),single(.5),uint8(1),gyro,uint8(1),single([1;0;0;0]),uint8(1));
maxError=0;
for k=1:100
    totals=uint32([3*k;2*k]);
    [a,used,delta]=adapter(totals,raw,gyro,pose);
    [b,oldUsed,oldDelta]=original(single([3;2]),uint8(raw(1)),uint8(1),uint8(bitshift(raw(2),-8)), ...
        single(.5),uint8(1),single(.5),uint8(1),gyro,uint8(1),single([1;0;0;0]),uint8(1));
    maxError=max(maxError,max(abs(double(a)-double(b))));
    assert(used==oldUsed && maxError<1e-7 && max(abs(double(delta)-double(oldDelta)))<1e-8);
end
assert(norm(double(a))>.4 && used==1);
reset(adapter);
gyro=single([.2;.1;0]);adapter(zeros(2,1,'uint32'),raw,gyro,pose);
% 1 count right at 0.5 m equals .5/385 m east before gyro correction.
[a,used]=adapter(uint32([1;0]),raw,zeros(3,1,'single'),pose);
assert(used==1 && abs(double(a(1))-.5/385)<1e-8 && abs(a(2))<1e-8);
held=a;raw(8)=0;[a,used,delta]=adapter(uint32([4;3]),raw,gyro,pose);
assert(used==0 && isequal(a,held) && all(isnan(delta)));
raw(8)=1;reset(adapter);
adapter(uint32([4294967294;0]),raw,zeros(3,1,'single'),pose);
[a,used]=adapter(uint32([1;0]),raw,zeros(3,1,'single'),pose);
assert(used==1 && abs(double(a(1))-3*.5/385)<1e-8);
report=struct('Passed',true,'ExistingTrackerComparedSamples',100, ...
    'MaxPositionDifferenceM',maxError,'CountsPerRad',385,'DisplayLogOnly',true);
disp(report);
end
function releaseBoth(a,b)
release(a);release(b);
end
