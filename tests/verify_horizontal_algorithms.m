function report=verify_horizontal_algorithms()
%VERIFY_HORIZONTAL_ALGORITHMS 実装クラス自体を使い、座標・有効性・状態を確認。
% 物理機器やモーターは操作しません。統合モデルの検証は別途行います。
root=stampfly_project_root();
[flow,imu,range,context,motion,control]=horizontal.fixture();
cases=struct;
% 1. 実際のFlightOutputsと機体姿勢変換を往復します。
for roll=[-.3 0 .3]
    for pitch=[-.2 0 .2]
        for yaw=[-2 .4 2]
            body=official.eulerQuaternion(single([roll;pitch;yaw]));
            filter=single([body(1);body(3);body(2);-body(4)]);
            [R,ok]=horizontal.bodyRotation(filter);assert(ok);
            assert(norm(R'*R-eye(3,'single'),'fro')<2e-6);
            assert(abs(R(3,3)-cos(roll)*cos(pitch))<2e-6);
        end
    end
end
for a=single([.2 0;-.2 0;0 .2;0 -.2;.2 .2]')
    target=horizontal.controlTilt(a,single(0));
    qf=official.eulerQuaternion(single([target(2);target(1);0]));
    [R,ok]=horizontal.bodyRotation(qf);assert(ok);
    physical=-single(9.80665)*R(1:2,3)/R(3,3);
    assert(norm(physical-a)<single(2e-6));
end
cases.Coordinates=true;
% カウンター差の整数実装を境界と乱数で元の定義と比較します。
boundaries=uint32([0 1 2147483647 2147483648 4294967294 4294967295]);
for current=boundaries
    for previous=boundaries
        assert(double(horizontal.counterDelta(current,previous))==mod(double(current)-double(previous),4294967296));
    end
end
randomState=rng;restoreRandom=onCleanup(@()rng(randomState)); %#ok<NASGU>
rng(48);pairs=uint32(floor(rand(2,1000)*4294967296));
for k=1:size(pairs,2)
    assert(double(horizontal.counterDelta(pairs(1,k),pairs(2,k)))==mod(double(pairs(1,k))-double(pairs(2,k)),4294967296));
end
cases.IntegerCounterDifference=true;
% 2. 時刻・累積countの巡回、一定速度、ゼロcount、品質・欠測・ToF経過を確認します。
tracker=horizontal.FlowMotion;timeBase=uint32(4294900000);total=int64([4294967290;4294967290]);
for k=1:400
    flow.Delta=single([1;-1]);total=total+int64([1;-1]);
    flow.Totals=uint32(mod(total,int64(4294967296)));
    flow.Info=uint32([k;300;400;mod(double(timeBase)+k*2500,4294967296)]);
    [p,v,~,height,status]=tracker(flow,imu,range,context);
end
expected=single(.5/385/.0025);assert(status(1)==1);
assert(all(abs(v-expected)<single(2e-5)));assert(all(p>single(.45)));
assert(abs(height-single(.5))<1e-6);
flow.Raw(1)=uint16(0);[~,~,~,~,status]=tracker(flow,imu,range,context);assert(status(1)==0);
flow.Raw(1)=uint16(100);
for k=401:440
    flow.Delta(:)=0;flow.Info=uint32([k;300;400;mod(double(timeBase)+k*2500,4294967296)]);
    [~,v,~,~,status]=tracker(flow,imu,range,context);
end
assert(status(1)==1&&norm(v)<single(1e-5));
range.Fresh=uint8(0);
for k=441:510
    flow.Info=uint32([k;300;400;mod(double(timeBase)+k*2500,4294967296)]);
    [~,~,~,~,status]=tracker(flow,imu,range,context);
end
assert(status(1)==0&&status(7)==4);
release(tracker);cases.FlowWrapVelocityAndValidity=true;
% 下限8 cmの内外で、観測可否と飛行補助の開始条件を独立して確認します。
for heightMm=[79 80 100]
    [flow,inertial,range,context,~,control]=horizontal.fixture();
    range.DistanceMm=int16(heightMm);tracker=horizontal.FlowMotion;command=horizontal.Command;
    for k=1:240
        flow.Info=uint32([k;300;400;k*2500]);
        [p,v,yaw,height,status,diagnostics]=tracker(flow,inertial,range,context);
        motion=struct('Position',p,'Velocity',v,'Heading',yaw,'Height',height,'Status',status,'Diagnostics',diagnostics);
        [~,active]=command(motion,zeros(2,1,'single'),control);
        assert(~active,'horizontal:LowHeightEngagement','Low-height desk observations must not engage flight assistance.');
    end
    assert(logical(status(1))==(heightMm>=80));
    if heightMm<80,assert(status(7)==4);end
    release(tracker);release(command);
end
cases.Height8cmBoundaryAndEngagement=true;
% 3. 時間変化する角速度を同じ区間に積分して回転成分を除去します。
tracker=horizontal.FlowMotion('XCountsPerRad',400,'YCountsPerRad',400);
[flow,imu,range,context]=horizontal.fixture();counts=zeros(2,1);last=0;
for k=1:320
    gyro=single(.2*sin(k*.05));imu.RawAngularRate=single([gyro;0;0]);
    imu.FilteredRate=single([0;gyro;0]);imu.CorrectedRate=imu.FilteredRate;
    delta=single([0; -400*double((last+gyro)*single(.5)*single(.0025))]);
    flow.Delta=delta;counts=counts+double(delta);flow.Totals=uint32(mod(round(counts),4294967296));
    % countは整数なので、専用の量子化累積を使います。
    if k==1,previous=zeros(2,1);end
    quantized=round(counts);flow.Delta=single(quantized-previous);previous=quantized;
    flow.Info=uint32([k;300;400;k*2500]);
    [~,v,~,~,status]=tracker(flow,imu,range,context);last=gyro;
end
assert(status(1)==1&&norm(v)<single(.055));release(tracker);
cases.TimeAlignedGyro=true;
% 4. 中立から移動・制動・新位置保持へ切り替え、欠測後は現在位置を捕捉します。
[~,~,~,~,motion,control]=horizontal.fixture();command=horizontal.Command('HealthyTimeS',.02,'RecoveryTimeS',.04);
manual=zeros(2,1,'single');
for k=1:20,[target,active,state,hold]=command(motion,manual,control);end
assert(active&&state==4);assert(norm(target)==0);
manual=single([.25;0]);
for k=1:60,motion.Position(2)=single(k*.005);[target,active,state,hold]=command(motion,manual,control);end
assert(active&&state==3&&target(2)>0&&abs(target(1))<1e-6);assert(isequal(hold,motion.Position));
manual(:)=0;
for k=1:90,motion.Position(2)=single(.4);[target,active,state,hold]=command(motion,manual,control);end
assert(active&&state==2&&norm(target)<.02&&abs(hold(2)-.4)<1e-6);
motion.Position(2)=single(.5);[target,~,~,~]=command(motion,manual,control);assert(target(2)<0);
motion.Status(1)=0;[~,active,state]=command(motion,manual,control);assert(~active&&state==1);
motion.Status(1)=1;motion.Position(2)=single(.8);
for k=1:40,[~,active,~,hold]=command(motion,manual,control);end
assert(active&&abs(hold(2)-.8)<1e-6);release(command);cases.MoveBrakeHoldAndRecovery=true;
% 5. PI制限・配分飽和・無効時の積分リセットとOFF時の値一致を確認します。
piController=horizontal.VelocityPI;
target=single([.3;.3]);
for k=1:400,[a,i,sat]=piController(target,motion,true,true);end
assert(norm(a)<=single(.600001)&&norm(i)<1e-6&&sat);
[a,i]=piController(target,motion,false,false);assert(norm(a)==0&&norm(i)==0);
release(piController);
selector=horizontal.SelectAttitude;manual=single([.125;-.25]);
[selected,blend]=selector(manual,zeros(2,1,'single'),motion,false,control);
assert(isequal(selected,manual)&&blend==0);
release(selector);cases.LimitsResetAndManualPassThrough=true;
report=struct('Passed',true,'Cases',cases,'PhysicalFlightTested',false);
file=fullfile(root,'build','horizontal_control','algorithm_verification.json');
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_ALGORITHM_VERIFICATION_PASSED\n');
end
