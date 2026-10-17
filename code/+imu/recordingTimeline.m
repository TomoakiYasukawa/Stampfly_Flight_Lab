function [time,boot,accepted] = recordingTimeline(deviceTime,sequence,mode,hostTime)
%RECORDINGTIMELINE 概要：時刻と連番の進行を確認し、記録の起動区間を分けます。
% 単独の古いフレームは表示から除外しますが、保存済みの生データは変更しません。
% 初期化・校正の2フレーム、その他の3フレームで新しい時刻系を確認します。
deviceTime=double(deviceTime(:));sequence=double(sequence(:));mode=double(mode(:));
hostTime=double(hostTime(:));n=numel(deviceTime);
time=nan(n,1);boot=zeros(n,1);accepted=false(n,1);
last=0;segment=1;offset=0;clockOffset=0;period=2^32/1000;nominal=.02;
pending=[];pendingCount=0;pendingLast=0;
for k=1:n
    if ~isfinite(deviceTime(k)) || deviceTime(k)<0,continue;end
    current=deviceTime(k)+clockOffset;
    if last==0
        time(k)=0;boot(k)=segment;accepted(k)=true;last=k;continue
    end
    previous=deviceTime(last)+clockOffset;
    if deviceTime(last)>period-1 && deviceTime(k)<1
        clockOffset=clockOffset+period;current=deviceTime(k)+clockOffset;
    elseif clockOffset>0 && current>previous+period/2
        continue % 一周前に作成され、遅れて届いたフレーム。
    end
    if current<previous-.5
        pending(end+1)=k; %#ok<AGROW>
        if pendingCount>0 && deviceTime(k)>deviceTime(pendingLast) && ...
                advancing(sequence(k),sequence(pendingLast))
            pendingCount=pendingCount+1;
        else
            pendingCount=1;
        end
        pendingLast=k;needed=3;
        if ismember(mode(k),[0 1]) && deviceTime(k)<5,needed=2;end
        if pendingCount<needed,continue;end
        % 新起動の確定分だけを採用。途中の重複・逆行は表示しません。
        segment=segment+1;clockOffset=0;first=pending(end-pendingCount+1);
        gap=nominal;
        if all(isfinite(hostTime([last first])))
            gap=max(gap,hostTime(first)-hostTime(last));
        end
        offset=time(last)+gap-deviceTime(first);
        confirmed=pending(end-pendingCount+1:end);
        time(confirmed)=offset+deviceTime(confirmed);
        boot(confirmed)=segment;accepted(confirmed)=true;last=k;
        pending=[];pendingCount=0;pendingLast=0;continue
    end
    % 元の時刻系が続いた場合、保留した古いフレームを再起動と解釈しません。
    pending=[];pendingCount=0;pendingLast=0;
    if current<=previous || ~advancing(sequence(k),sequence(last)),continue;end
    elapsed=current-previous;
    if elapsed<1
        steps=mod(sequence(k)-sequence(last),65536);
        if isfinite(steps),nominal=elapsed/steps;end
    end
    time(k)=time(last)+elapsed;boot(k)=segment;accepted(k)=true;last=k;
end
end
function yes=advancing(current,previous)
% 連番を持たない旧形式は時刻の進行だけで判断します。
if ~isfinite(current) || ~isfinite(previous),yes=true;return;end
step=mod(current-previous,65536);yes=step>0 && step<32768;
end
