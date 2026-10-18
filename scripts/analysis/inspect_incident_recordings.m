function report=inspect_incident_recordings()
%INSPECT_INCIDENT_RECORDINGS 概要：保存済みの落下記録を読み、操縦入力と補助切替を照合。
% 通信ポートや機体を操作せず、欠落を補間しません。図と詳細値はbuild内に保存します。
root=stampfly_project_root();configure_stampfly_project();
folder=fullfile(root,'build','horizontal_control','fall_investigation');
names={'StampFly_20261017_125204_206.mat','StampFly_20261017_125358_399.mat', ...
    'StampFly_20261017_125503_794.mat'};
reports=cell(1,numel(names));
for k=1:numel(names)
    file=fullfile(root,'recordings',names{k});
    saved=load(file,'info','hostElapsedSeconds');
    data=imu.readExtendedTelemetry(string(file));
    host=nan(height(data),1);
    if isfield(saved,'hostElapsedSeconds'),host=saved.hostElapsedSeconds;end
    [~,boot,accepted]=imu.recordingTimeline(data.TimeSeconds,data.Sequence,data.FlightState,host);
    first=find(accepted & data.FlightState==2,1);assert(~isempty(first));
    start=data.TimeSeconds(first);
    data=data(accepted & boot==boot(first) & data.TimeSeconds>=start-2,:);
    data.ElapsedS=data.TimeSeconds-start;
    q=[data.QuatW data.QuatX data.QuatY data.QuatZ];
    data.EstRollDeg=atan2(2*(q(:,1).*q(:,2)+q(:,3).*q(:,4)),1-2*(q(:,2).^2+q(:,3).^2))*180/pi;
    data.EstPitchDeg=asin(max(-1,min(1,2*(q(:,1).*q(:,3)-q(:,4).*q(:,2)))))*180/pi;
    flight=data.FlightState==2;
    enabled=flight & isfinite(data.HorizontalEnabled) & data.HorizontalEnabled>.5;
    mixed=flight & isfinite(data.HorizontalBlend) & data.HorizontalBlend>0;
    controls=flight & isfinite(data.PilotPitch) & isfinite(data.PitchReferenceRad);
    large=find(controls & abs(data.PitchReferenceRad)>15*pi/180);
    h=imu.readRecordingHistory(string(file));
    item=struct('Recording',['recordings/' names{k}],'FlightFirstTimeS',start, ...
        'FlightLastElapsedS',max(data.ElapsedS(flight)),'MissingFrames',saved.info.MissingFrames, ...
        'CRCRejected',saved.info.CRCRejected,'HistoryStartsWithState',h.FlightState(1), ...
        'HistoryMinimumTimeS',min(h.Time),'HistoryStopReason',h.RecordingStopReason, ...
        'TimeZeroSource',h.TimeZeroSource,'HorizontalEnabledSamples',nnz(enabled), ...
        'HorizontalBlendPositiveSamples',nnz(mixed),'LargePitchRows',nnz(large), ...
        'Stats',struct(),'FinalObserved',struct());
    fields={'PilotRoll','PilotPitch','PilotYaw','PilotThrottle','UsedRoll','UsedPitch','UsedYaw','UsedThrottle', ...
        'PilotControlMode','PilotAltitudeMode','UsedControlMode','UsedAltitudeMode', ...
        'RollReferenceRad','PitchReferenceRad','YawRateReferenceRadps', ...
        'RollRateReferenceRadps','PitchRateReferenceRadps','RollControlEffort','PitchControlEffort','YawControlEffort', ...
        'EstRollDeg','EstPitchDeg','HorizontalBlend','HorizontalState','HorizontalEnabled', ...
        'HorizontalMeasurementValid','HorizontalRejectReason','FlowIntervalCoverage', ...
        'HorizontalVelocityXMps','HorizontalVelocityYMps','HorizontalRollTargetRad','HorizontalPitchTargetRad', ...
        'HeightControlEnabled','AltitudeEnabled','BaseThrottle','BaseDuty','VerticalPIOutput', ...
        'AppliedHeightCorrection','ThrottleBeforeLimit','ThrottleAfterLimit','ThrottleSaturated', ...
        'HeightM','ToFDistanceM','RawVerticalVelocityMps','VerticalAccelG','KalmanAccelBiasG', ...
        'OverGFlag','RangeFailureCounter','LowVoltageCounter','JoystickConnected','SamplePeriodS','MeasuredSamplePeriodS'};
    for j=1:numel(fields)
        if ~ismember(fields{j},data.Properties.VariableNames),continue;end
        values=data.(fields{j});mask=flight & isfinite(values);
        item.Stats.(fields{j})=stats(values(mask));
        last=find(mask,1,'last');
        if ~isempty(last),item.FinalObserved.(fields{j})=struct('ElapsedS',data.ElapsedS(last),'Value',values(last));end
    end
    enabledRows=find(enabled);
    if ~isempty(enabledRows)
        item.HorizontalEnabledFirstLastS=data.ElapsedS(enabledRows([1 end]))';
    else,item.HorizontalEnabledFirstLastS=[];end
    mixRows=find(mixed);
    if ~isempty(mixRows),item.PositiveBlendFirstLastS=data.ElapsedS(mixRows([1 end]))';
    else,item.PositiveBlendFirstLastS=[];end
    if ~isempty(large)
        item.LargePitchObservations=table2struct(data(large,{'ElapsedS','PilotPitch','UsedPitch', ...
            'PitchReferenceRad','HorizontalEnabled','HorizontalBlend','HorizontalPitchTargetRad'}));
    else,item.LargePitchObservations=[];end
    % 1. 姿勢目標、操縦入力、水平補助、推力・速度の相互関係を別々に表示します。
    fig=figure('Visible','off','Position',[40 40 1200 1050]);tiledlayout(fig,5,1,'TileSpacing','compact');
    nexttile;plot(data.ElapsedS,data.EstRollDeg,data.ElapsedS,data.EstPitchDeg, ...
        data.ElapsedS,data.RollReferenceRad*180/pi,data.ElapsedS,data.PitchReferenceRad*180/pi);
    ylabel('angle (deg)');legend('Roll estimate','Pitch estimate','Roll target','Pitch target','Location','eastoutside');grid on;
    title(names{k},'Interpreter','none');
    nexttile;plot(data.ElapsedS,data.PilotRoll,data.ElapsedS,data.PilotPitch, ...
        data.ElapsedS,data.PilotYaw,data.ElapsedS,data.PilotThrottle);
    ylabel('pilot input');legend('Roll','Pitch','Yaw','Throttle','Location','eastoutside');grid on;
    nexttile;stairs(data.ElapsedS,[data.HorizontalEnabled data.HorizontalBlend data.HorizontalState]);
    ylabel('assist');legend('Enabled','Blend','State','Location','eastoutside');grid on;
    nexttile;plot(data.ElapsedS,[data.BaseThrottle data.ThrottleAfterLimit data.AppliedHeightCorrection data.HeightControlEnabled]);
    ylabel('duty / flag');legend('Base throttle','Limited throttle','Height correction','Height enabled','Location','eastoutside');grid on;
    nexttile;plot(h.Time,[h.RawVerticalVelocityMps h.ToFVerticalVelocityMps]);
    ylabel('up velocity (m/s)');xlabel('time from Mode 2 (s)');legend('Kalman / PID input','Trailing ToF slope','Location','eastoutside');grid on;
    exportgraphics(fig,fullfile(folder,[names{k} '.controls.png']),'Resolution',120);close(fig);
    save(fullfile(folder,[names{k} '.controls.mat']),'data','item','h');
    % 2. 新版アプリの履歴表示を旧ログで描画し、表示ラベルと集計も照合します。
    app=DataLogger();cleanup=onCleanup(@()delete(app));app.UIFigure.Visible='on';
    app.MainTabs.SelectedTab=app.HistoryTab;
    imu.RecordingHistoryView.refresh(app,string(file));scroll(app.HistoryChartGrid,'top');drawnow;
    assert(isequal(app.HistoryStateAxes.YTick,[0 1 2 3 5]));
    assert(~contains(string(app.HistoryStatusLabel.Tooltip),'ホバリング開始'));
    assert(size(app.HistorySummaryTable.Data,2)==8);
    heightLines=findall(app.HistoryHeightAxes,'Type','line');
    assert(any(arrayfun(@(line)numel(line.YData)>100 && any(isfinite(line.YData)),heightLines)));
    velocityLines=findall(app.HistoryVerticalSpeedAxes,'Type','line');
    assert(any(arrayfun(@(line)numel(line.YData)>100 && any(isfinite(line.YData)),velocityLines)));
    pause(1);drawnow;
    exportapp(app.UIFigure,fullfile(folder,[names{k} '.history.png']));
    exportgraphics(app.HistoryHeightAxes,fullfile(folder,[names{k} '.history_height.png']),'Resolution',120);
    exportgraphics(app.HistoryVerticalSpeedAxes,fullfile(folder,[names{k} '.history_velocity.png']),'Resolution',120);
    exportgraphics(app.HistoryStateAxes,fullfile(folder,[names{k} '.history_state.png']),'Resolution',120);
    clear cleanup;
    reports{k}=item;
    fprintf('INCIDENT_FLIGHT_INSPECTED %s enabled=%d mixed=%d largePitch=%d\n',names{k},nnz(enabled),nnz(mixed),nnz(large));
end
report=struct('RecordedDataOnly',true,'InterpolationUsed',false,'SerialConnectionsOpened',0, ...
    'FlightCauseConfirmed',false,'CurrentAppReplayedAllThree',true, ...
    'HeightVelocityPlotValuesChecked',true,'RenderedWindowCaptureAvailable',false,'Recordings',{reports});
fid=fopen(stampfly_report_file('docs/incident_recording_replay.json'),'w','n','UTF-8');assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));fclose(fid);
fprintf('INCIDENT_RECORDING_REPLAY_COMPLETE\n');
end
function out=stats(values)
% 3. 欠落値を数値へ置き換えず、観測した数と範囲だけを要約します。
out=struct('Count',numel(values),'Min',NaN,'Max',NaN,'Mean',NaN);
if isempty(values),return;end
out.Min=min(values);out.Max=max(values);out.Mean=mean(values);
end
