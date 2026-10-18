function report=verify_imu_health()
%VERIFY_IMU_HEALTH 読出し成功と更新の違い、短い再読出し・停止・故障を確認。
% 実センサーを使わず、新しい水平推定クラスの入力契約を検証します。
[flow,inertial,range,context]=horizontal.fixture();
tracker=horizontal.FlowMotion;
for k=1:400
    flow.Info=uint32([k;300;400;k*2500]);
    inertial.Fresh=uint8(mod(k,40)~=0);inertial.ReadValid=uint8(1);
    [~,~,~,~,status]=tracker(flow,inertial,range,context);
    if k>16,assert(status(1)==1,'horizontal:RepeatedIMU','A bounded repeated register read must remain usable.');end
end
% APIの読出し失敗は、Freshの値にかかわらず直ちに無効にします。
inertial.ReadValid=uint8(0);inertial.Fresh=uint8(1);
flow.Info=uint32([401;300;400;401*2500]);
[~,~,~,~,status]=tracker(flow,inertial,range,context);assert(status(1)==0&&status(7)==5);
inertial.ReadValid=uint8(1);inertial.Fresh=uint8(1);
for k=402:424
    flow.Info=uint32([k;300;400;k*2500]);[~,~,~,~,status]=tracker(flow,inertial,range,context);
end
assert(status(1)==1);
% 更新が7.5 msを超えて止まった場合は、数値が有限でも棄却します。
inertial.Fresh=uint8(0);
for k=425:430
    flow.Info=uint32([k;300;400;k*2500]);[~,~,~,~,status]=tracker(flow,inertial,range,context);
end
assert(status(1)==0&&status(7)==5);release(tracker);
% 実機の2.5 ms揺らぎを模した更新で、中立から補助を開始できることを確認。
tracker=horizontal.FlowMotion;command=horizontal.Command;
[flow,inertial,range,context,~,control]=horizontal.fixture();
active=false;enabledCount=0;
for k=1:1200
    flow.Info=uint32([k;300;400;k*2500]);inertial.Fresh=uint8(mod(k,40)~=0);
    [p,v,yaw,height,status,diagnostics]=tracker(flow,inertial,range,context);
    motion=struct('Position',p,'Velocity',v,'Heading',yaw,'Height',height,'Status',status,'Diagnostics',diagnostics);
    [~,active]=command(motion,zeros(2,1,'single'),control);
    if k>400,enabledCount=enabledCount+double(active);end
end
assert(active&&enabledCount==800);release(tracker);release(command);
report=struct('Passed',true,'BoundedRepeatedReadsAccepted',true,'ReadFailureRejectedImmediately',true, ...
    'StaleGyroRejected',true,'AssistCanEngage',true);
fid=fopen(stampfly_report_file('docs/horizontal_imu_health_verification.json'),'w','n','UTF-8');
assert(fid>=0);fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('HORIZONTAL_IMU_HEALTH_VERIFICATION_PASSED\n');
end
