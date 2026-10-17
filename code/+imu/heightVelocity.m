function velocity=heightVelocity(time,height,valid,fresh,windowSeconds,maxGapSeconds)
%HEIGHTVELOCITY 概要：新しい測距の実時刻から高度の変化率[m/s]を求めます。
% 上昇が正。直前0.25秒の傾きを最小二乗で求める比較用の値です。
% センサー無効、時刻逆転、0.15秒超の欠測をまたいで差分を取りません。
% 独立した速度センサーではなく、窓長による遅れを持ちます。
arguments
    time (:,1) double
    height (:,1) double
    valid (:,1) logical
    fresh (:,1) logical
    windowSeconds (1,1) double {mustBePositive}=.25
    maxGapSeconds (1,1) double {mustBePositive}=.15
end
n=numel(time);
assert(numel(height)==n && numel(valid)==n && numel(fresh)==n,'imu:HeightVelocitySize','Input sizes differ.');
velocity=nan(n,1);buffer=zeros(0,1);lastFresh=NaN;
for k=1:n
    if ~valid(k) || ~isfinite(time(k)) || ~isfinite(height(k)) || height(k)<0
        buffer=zeros(0,1);lastFresh=NaN;continue;
    end
    if k>1 && time(k)<=time(k-1)
        buffer=zeros(0,1);lastFresh=NaN;
    end
    if ~fresh(k),continue;end
    if isfinite(lastFresh) && time(k)-lastFresh>maxGapSeconds
        buffer=zeros(0,1);
    end
    lastFresh=time(k);buffer(end+1,1)=k; %#ok<AGROW>
    buffer=buffer(time(buffer)>=time(k)-windowSeconds);
    if numel(buffer)<3 || time(buffer(end))-time(buffer(1))<.4*windowSeconds,continue;end
    tau=time(buffer)-mean(time(buffer));
    velocity(k)=sum(tau.*height(buffer))/sum(tau.^2);
end
end
