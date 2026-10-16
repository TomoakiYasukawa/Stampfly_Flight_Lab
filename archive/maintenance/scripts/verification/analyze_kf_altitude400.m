function report=analyze_kf_altitude400()
%ANALYZE_KF_ALTITUDE400 Compare both single implementations to double equations.
% Uses saved component traces only; no model or hardware is operated.
root=stampfly_project_root();folder=fullfile(root,'build','kf400','tests');
component=jsondecode(fileread(fullfile(root,'docs','history','kf_altitude_verification.json')));
cases={'BootWaitFlyLandRelaunch','StartActiveVariableDt','HeldToFAndAcceleration','ResetDuringHold'};
report=struct('ModelSHA256',component.ModelSHA256,'SourceModelSHA256',component.SourceModelSHA256, ...
    'Reference','Double precision original predict/correct equations and update schedule', ...
    'Cases',struct);
for c=1:numel(cases)
    f=load(fullfile(folder,[cases{c} '.mat']),'out','t','data');
    n=numel(f.t);reference=zeros(n,3);state=zeros(3,1);P=100*eye(3);
    output=zeros(3,1);first=false;previousMode=uint8(0);
    for j=1:n
        mode=f.data{3}(j);h=double(f.data{4}(j));
        if f.data{5}(j),P=100*eye(3);output(:)=0;end
        if mode==uint8(3)&&mode~=previousMode,first=false;end
        if mode>uint8(1)
            if first
                A=[1 0 -h;h 1 0;0 0 1-double(single(.01))*h];
                predicted=A*state+[h;0;0]*double(f.data{2}(j));
                prior=A*P*A'+diag([double(single(.01))*h*h,0,h*h]);
                gain=prior(:,2)/(prior(2,2)+double(single(.004*.004)));
                state=predicted+gain*(double(f.data{1}(j))-predicted(2));
                P=prior-gain*prior(2,:);output=state;
            else
                first=true;
            end
        end
        previousMode=mode;reference(j,:)=output([2 1 3]);
    end
    result=struct('Samples',n,'OldMaximumReferenceErrors',zeros(1,3), ...
        'NewMaximumReferenceErrors',zeros(1,3),'OldReferenceRMSE',zeros(1,3), ...
        'NewReferenceRMSE',zeros(1,3),'PeakDifferenceTime',zeros(1,3), ...
        'OldAtPeak',zeros(1,3),'NewAtPeak',zeros(1,3),'ReferenceAtPeak',zeros(1,3));
    for k=1:3
        a=double(squeeze(f.out.yout{2*k-1}.Values.Data));
        b=double(squeeze(f.out.yout{2*k}.Values.Data));
        result.OldMaximumReferenceErrors(k)=max(abs(a-reference(:,k)));
        result.NewMaximumReferenceErrors(k)=max(abs(b-reference(:,k)));
        result.OldReferenceRMSE(k)=sqrt(mean((a-reference(:,k)).^2));
        result.NewReferenceRMSE(k)=sqrt(mean((b-reference(:,k)).^2));
        [~,j]=max(abs(a-b));result.PeakDifferenceTime(k)=f.t(j);
        result.OldAtPeak(k)=a(j);result.NewAtPeak(k)=b(j);result.ReferenceAtPeak(k)=reference(j,k);
    end
    report.Cases.(cases{c})=result;
    fprintf('KF400_DOUBLE_REFERENCE: %s old=%s new=%s\n',cases{c}, ...
        mat2str(result.OldMaximumReferenceErrors,9),mat2str(result.NewMaximumReferenceErrors,9));
end
fid=fopen(fullfile(root,'docs','history','kf_altitude_numerics.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
end
