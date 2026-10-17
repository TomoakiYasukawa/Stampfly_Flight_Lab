function log = readRecordingHistory(filePath, rangeMode, maxPoints, expectedBuildID)
%READRECORDINGHISTORY 概要：MAT記録の状態・高度・速度を履歴画面用に読みます。
% 生フレームを読み込まず、状態遷移と時刻リセット前後を間引きから保護します。
% 最初の飛行はMode 2の開始を0秒とし、その前2秒を負の時刻で表示します。
arguments
    filePath (1,1) string
    rangeMode (1,1) string {mustBeMember(rangeMode,["firstFlight","all"])} = "firstFlight"
    maxPoints (1,1) double {mustBeInteger,mustBePositive} = 5000
    expectedBuildID (1,1) double {mustBeInteger,mustBeNonnegative} = 0
end
if ~isfile(filePath)
    error('imu:HistoryFileMissing','MAT file not found: %s',filePath);
end
meta = whos('-file',filePath);
names = string({meta.name});
tMeta = meta(names == "telemetry");
if ~isscalar(tMeta) || numel(tMeta.size) ~= 2 || tMeta.size(2) < 3 || ...
        ~ismember(tMeta.class,{'double','single'})
    error('imu:HistoryInvalidFile','No supported telemetry matrix: %s',filePath);
end
n = tMeta.size(1);
if n == 0
    error('imu:HistoryEmptyFile','The recording has no frames: %s',filePath);
end
m = matfile(filePath);
if ismember("info",names)
    info = m.info;
else
    info = struct();
end
if isfield(info,'Columns')
    columns = string(info.Columns);
else
    error('imu:HistoryInvalidFile','Missing StampFly column definitions: %s',filePath);
end
if numel(columns) ~= tMeta.size(2) || ~any(columns == "TimeSeconds")
    error('imu:HistoryInvalidFile','Unsupported StampFly columns: %s',filePath);
end
step = max(1,ceil(n/maxPoints));
baseRows = 1:step:n;
extraRows = n;
stateColumn = find(columns == "FlightState",1);
timeColumn = find(columns == "TimeSeconds",1);
allTime = double(m.telemetry(1:n,timeColumn));
allSequence=nan(n,1);allStates=nan(n,1);hostAll=nan(n,1);
sequenceColumn=find(columns=="Sequence",1);
if ~isempty(sequenceColumn),allSequence=double(m.telemetry(1:n,sequenceColumn));end
if ~isempty(stateColumn),allStates=double(m.telemetry(1:n,stateColumn));end
if ismember("hostElapsedSeconds",names)
    hMeta=meta(names=="hostElapsedSeconds");
    if isscalar(hMeta) && hMeta.size(1)>=n,hostAll=double(m.hostElapsedSeconds(1:n,1));end
end
[allDisplayTime,allBoot,accepted]=imu.recordingTimeline(allTime,allSequence,allStates,hostAll);
acceptedRows=find(accepted);
if isempty(acceptedRows),error('imu:HistoryEmptyTimeline','No advancing device timestamps.');end
boundaryIndices=find(diff(allBoot(acceptedRows))~=0)+1;
boundaries=acceptedRows(boundaryIndices);
extraRows=[extraRows acceptedRows(end) boundaries(:)' acceptedRows(boundaryIndices-1)'];
if step > 1 && ~isempty(stateColumn)
    % Keep short-lived state transitions even when long logs are thinned.
    allStates = double(m.telemetry(1:n,stateColumn));
    transitions = find(isfinite(allStates(2:end)) & ...
        allStates(2:end) ~= allStates(1:end-1)) + 1;
    extraRows = [extraRows transitions(:)' max(1,transitions(:)'-1)];
end
extraRows = setdiff(unique(extraRows),baseRows);
sample = double(m.telemetry(baseRows,1:tMeta.size(2)));
extraSample = zeros(numel(extraRows),tMeta.size(2));
for extraIndex = 1:numel(extraRows)
    extraSample(extraIndex,:) = double(m.telemetry( ...
        extraRows(extraIndex),1:tMeta.size(2)));
end
[rows,order] = sort([baseRows extraRows]);
sample = [sample;extraSample];
sample = sample(order,:);
selectedTimeline=accepted(rows);sample=sample(selectedTimeline,:);rows=rows(selectedTimeline);
buildColumn = find(columns == "BuildID",1);
if expectedBuildID == 0 && isfield(info,'Config') && ...
        isfield(info.Config,'ExpectedBuildID')
    expectedBuildID = double(info.Config.ExpectedBuildID);
end
foreignFrames = 0;
if expectedBuildID ~= 0 && ~isempty(buildColumn)
    % 過去に別ビルドが混在した記録も、対象の時刻・値だけを表示する。
    versionColumn = find(columns == "Version",1);
    selectedBuild = sample(:,buildColumn) == expectedBuildID;
    if ~isempty(versionColumn)
        selectedBuild = selectedBuild | sample(:,versionColumn) < 7;
    end
    foreignFrames = nnz(~selectedBuild);
    sample = sample(selectedBuild,:);
    rows = rows(selectedBuild);
    if isempty(rows)
        error('imu:HistoryBuildMissing','No frames for BuildID %.0f: %s', ...
            expectedBuildID,filePath);
    end
end

    function values = col(name)
        columnIndex = find(columns == name,1);
        if isempty(columnIndex) || columnIndex > size(sample,2)
            values = nan(numel(rows),1);
        else
            values = sample(:,columnIndex);
        end
    end

rawTime = col("TimeSeconds");
if all(~isfinite(rawTime))
    rawTime = sample(:,3);
end
time=allDisplayTime(rows);boot=allBoot(rows);
schema=localStateSchema(info,expectedBuildID,col("BuildID"));
states=imu.flightStateDefinition(schema);

height = col("HeightM");
heightValid = col("HeightValid");
height(isfinite(heightValid) & heightValid < 0.5) = NaN;
tof = col("ToFDistanceM");
tofValid = col("ToFValid");
tof(isfinite(tofValid) & tofValid < 0.5) = NaN;
xy = [col("XYX") col("XYY")];
motors = [col("MotorFR") col("MotorFL") col("MotorRR") col("MotorRL")];
motorValid = col("MotorValid");
motors(isfinite(motorValid) & motorValid < 0.5,:) = NaN;
state = col("FlightState");
q=[col("QuatW") col("QuatX") col("QuatY") col("QuatZ")];
orientationValid=col("OrientationValid")>.5;
correctedToF=nan(numel(rows),1);
for k=1:numel(rows)
    [value,valid]=imu.correctToFHeight(tof(k),isfinite(tof(k)),q(k,:),orientationValid(k));
    if valid,correctedToF(k)=value;end
end
fresh=col("ToFFresh")>.5;
slope=imu.heightVelocity(rawTime,correctedToF,isfinite(correctedToF),fresh);
stopReason='unknown';
if isfield(info,'RecordingStop') && isfield(info.RecordingStop,'Reason')
    stopReason=char(info.RecordingStop.Reason);
end

% 状態番号はStateflowの定義で解釈し、待機や校正を離陸と扱いません。
if rangeMode == "firstFlight"
    flight=find(ismember(state,states.FlightCodes),1);
    if isempty(flight)
        keep=1:numel(rows);anchor=1;zeroSource='recording_start';
    else
        anchor=flight;zeroSource='flight_mode';
        first=find(boot==boot(flight) & time>=time(flight)-2,1);
        last=find(boot==boot(flight),1,'last');
        if last<numel(rows),stopReason='firmware_restart';end
        parked=find(state(flight+1:last)==states.ParkedCode,1);
        if ~isempty(parked)
            parked=flight+parked;
            next=find(ismember(state(parked+1:last),states.FlightCodes),1);
            if ~isempty(next),last=min(last,parked+next-1);end
            post=find(time(parked:last)>=time(parked)+1,1);
            if ~isempty(post),last=min(last,parked+post-1);end
            stopReason='parked';
        end
        keep=first:last;
    end
else
    keep = 1:numel(rows);anchor=1;zeroSource='recording_start';
end
time = time(keep)-time(anchor);
rawTime=rawTime(keep);boot=boot(keep);
height = height(keep);
tof = tof(keep);
xy = xy(keep,:);
motors = motors(keep,:);
state = state(keep);

[~,base,ext] = fileparts(filePath);
log = struct();
log.FilePath = filePath;
log.Name = string(base) + string(ext);
log.Time = time;
log.DeviceTimeSeconds=rawTime;
log.BootSegment=boot;
log.TimeZeroSource=zeroSource;
log.StateSchema=states.Schema;
log.StateCodes=states.Codes;
log.StateNames=states.Names;
log.StateColors=states.Colors;
log.RecordingStopReason=stopReason;
log.RecordingStopName=imu.recordingStopName(stopReason);
log.RestartReasonName='未記録';
if strcmp(stopReason,'firmware_restart') && isfield(info,'RecordingStop') && ...
        isfield(info.RecordingStop,'NewBoot') && isfield(info.RecordingStop.NewBoot,'ResetReason')
    value=info.RecordingStop.NewBoot.ResetReason;
    if isfinite(value),log.RestartReasonName=imu.resetReasonName(value);end
end
log.Complete=isfield(info,'Complete') && info.Complete;
log.HeightM = height;
log.ToFM = tof;
log.CorrectedToFM=correctedToF(keep);
log.ToFVerticalVelocityMps=slope(keep);
log.XYM = xy;
log.Motors = motors;
log.FlightState = state;
log.ToFValid = tofValid(keep);
log.HeightValid = heightValid(keep);
log.OrientationValid = col("OrientationValid");
log.OrientationValid = log.OrientationValid(keep);
diagnosticFields = ["ToFFresh", "ZReferenceM", "ZErrorM", ...
    "VerticalVelocityReferenceMps", "RawVerticalVelocityMps", ...
    "FilteredVerticalVelocityMps", "VerticalVelocityErrorMps", ...
    "BaseThrottle", "VerticalPIOutput", "VerticalPTerm", ...
    "VerticalIResidual", "AppliedHeightCorrection", ...
    "ThrottleBeforeLimit", "ThrottleAfterLimit", ...
    "HeightControlEnabled", "ThrottleSaturated"];
for field = diagnosticFields
    values = col(field);
    log.(field) = values(keep);
end
log.TotalFrames = n;
log.DisplayedFrames = numel(keep);
log.IsDecimated = step > 1;
log.DurationSeconds = time(end)-time(1);
flightHeights=height(ismember(state,states.FlightCodes) & isfinite(height));
if isempty(flightHeights)
    log.FlightMeanHeightCM=NaN;
else
    log.FlightMeanHeightCM=100*mean(flightHeights);
end
validHeight = height(isfinite(height));
if isempty(validHeight)
    log.HeightRangeCM = [NaN NaN];
else
    log.HeightRangeCM = 100*[min(validHeight) max(validHeight)];
end
log.MissingFrames = localInfoNumber(info,'MissingFrames');
log.CRCRejected = localInfoNumber(info,'CRCRejected');
log.ExpectedBuildID = expectedBuildID;
log.ExcludedOtherBuildPoints = foreignFrames;
log.ExcludedDelayedOrDuplicateFrames=nnz(~accepted);
% 再起動や長い欠測を線で結ばず、未観測の落下を補間して描きません。
gaps=[false;diff(boot)~=0 | diff(rawTime)<=0 | diff(rawTime)>.15*max(1,step)];
log.PlotBreakBefore=gaps;
log.IsOfficialFixedPID=strcmp(states.Schema,'StampFlyOfficial-v1');
if log.IsOfficialFixedPID
    % 旧列名FilteredVerticalVelocityMpsはこのロガーではKalman速度と同じ値。
    % 固定PID版はKalman速度を直接使用するため、複製した列を別のLPFとして表示しません。
    log.FilteredVerticalVelocityMps(:)=NaN;
end
end

function schema=localStateSchema(info,expectedBuildID,buildIDs)
% 旧ログはBuildID 1401の公式版だけを既知として補完します。
schema='unknown';
if isfield(info,'FlightStateSchema') && ~strcmp(info.FlightStateSchema,'unknown')
    schema=char(info.FlightStateSchema);
elseif isfield(info,'Config') && isfield(info.Config,'FlightStateSchema')
    schema=char(info.Config.FlightStateSchema);
elseif expectedBuildID==1401 || any(buildIDs==1401)
    schema='StampFlyOfficial-v1';
end
end

function value = localInfoNumber(info,name)
value = NaN;
if isfield(info,name) && isnumeric(info.(name)) && isscalar(info.(name))
    value = double(info.(name));
end
end
