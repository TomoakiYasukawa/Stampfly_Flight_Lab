function log = readRecordingHistory(filePath, rangeMode, maxPoints, expectedBuildID)
%READRECORDINGHISTORY Read the columns needed by the history viewer.
% The file is read through matfile, so rawFrames are never loaded.
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
if step > 1 && ~isempty(stateColumn)
    % Keep short-lived state transitions even when long logs are thinned.
    allStates = double(m.telemetry(1:n,stateColumn));
    transitions = find(isfinite(allStates(2:end)) & ...
        allStates(2:end) ~= allStates(1:end-1)) + 1;
    extraRows = [extraRows transitions(:)'];
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
if ismember("hostElapsedSeconds",names)
    hMeta = meta(names == "hostElapsedSeconds");
    if isscalar(hMeta) && hMeta.size(1) >= n
        hostAll = double(m.hostElapsedSeconds(1:n,1));
        hostTime = hostAll(rows);
    else
        hostTime = nan(numel(rows),1);
    end
else
    hostTime = nan(numel(rows),1);
end
time = localDeviceTime(rawTime,hostTime,rows);

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

% A flight log can continue after the device restarts. Restrict the first
% flight to the first emergency/idle transition or device-clock reset.
if rangeMode == "firstFlight"
    first = find(state == 1,1);
    if isempty(first)
        first = find(state == 2 | state == 3,1);
    end
    if isempty(first)
        first = 1;
    end
    last = numel(rows);
    reset = find(diff(rawTime(first:end)) < -0.5,1);
    if ~isempty(reset)
        last = min(last,first+reset-1);
    end
    emergency = find(state(first:last) == 4,1);
    if ~isempty(emergency)
        k = first+emergency-1;
        afterSecond = find(time(k:last) >= time(k)+1,1);
        if ~isempty(afterSecond)
            last = min(last,k+afterSecond-1);
        end
    end
    idle = find(state(first+1:last) == 0,1);
    if ~isempty(idle)
        last = min(last,first+idle);
    end
    keep = first:last;
else
    keep = 1:numel(rows);
end
time = time(keep)-time(keep(1));
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
log.HeightM = height;
log.ToFM = tof;
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
hover = height(state == 2 & isfinite(height));
if isempty(hover)
    log.HoverMeanCM = NaN;
else
    log.HoverMeanCM = 100*mean(hover);
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
end

function time = localDeviceTime(rawTime,hostTime,rows)
% USB serial delivery is bursty. Host arrival times are used only to bridge
% a device reboot; within each boot segment the device clock is authoritative.
rawTime = rawTime(:);
hostTime = hostTime(:);
if all(isfinite(rawTime))
    reset = find(diff(rawTime) < -0.5);
    positive = diff(rawTime);
    positive = positive(positive > 0 & positive < 1);
    if isempty(positive)
        nominalStep = median(diff(rows))/50;
    else
        nominalStep = median(positive);
    end
    if ~isfinite(nominalStep) || nominalStep <= 0
        nominalStep = 0.02;
    end
    boundaries = [1;reset(:)+1;numel(rawTime)+1];
    time = zeros(numel(rawTime),1);
    for segment = 1:numel(boundaries)-1
        first = boundaries(segment);
        last = boundaries(segment+1)-1;
        if segment == 1
            offset = 0;
        else
            offset = time(first-1) + nominalStep;
            if all(isfinite(hostTime([first-1 first])))
                offset = time(first-1) + ...
                    max(nominalStep,hostTime(first)-hostTime(first-1));
            end
        end
        time(first:last) = offset + rawTime(first:last)-rawTime(first);
    end
    if all(diff(time) >= 0)
        return
    end
end
if all(isfinite(hostTime)) && all(diff(hostTime) >= 0)
    time = hostTime-hostTime(1);
else
    time = (rows(:)-rows(1))/50;
end
end

function value = localInfoNumber(info,name)
value = NaN;
if isfield(info,name) && isnumeric(info.(name)) && isscalar(info.(name))
    value = double(info.(name));
end
end
