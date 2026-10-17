classdef MatRecordingWriter < handle
    %MATRECORDINGWRITER Save every CRC-valid SFI frame in a growing MAT file.
    % The small in-memory batch keeps the UI responsive during long sessions.

    properties (SetAccess = private)
        FilePath (1,1) string
        Count (1,1) double = 0
        IsComplete (1,1) logical = false
    end

    properties (Access = private)
        MatFile
        Clock
        Capacity (1,1) double = 512
        Buffered (1,1) double = 0
        TelemetryBuffer double
        RawBuffer uint8
        LengthBuffer uint8
        HostTimeBuffer double
        ExtensionBuffer double
        ExtensionRawBuffer uint8
        ExtensionLengthBuffer uint8
        ExtensionHostTimeBuffer double
        ExtensionBuffered = 0
        ExtensionCount = 0
    end

    methods
        function obj = MatRecordingWriter(folder, config)
            arguments
                folder (1,1) string
                config (1,1) struct = struct()
            end
            if ~isfolder(folder)
                mkdir(folder);
            end
            assert(isfolder(folder), 'imu:RecordingFolder', ...
                'Could not create recording folder: %s', folder);
            stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
            base = fullfile(folder, "StampFly_" + stamp);
            candidate = base + ".mat";
            suffix = 2;
            while isfile(candidate)
                candidate = base + "_" + suffix + ".mat";
                suffix = suffix + 1;
            end
            obj.FilePath = candidate;
            obj.TelemetryBuffer = zeros(obj.Capacity, 80);
            obj.RawBuffer = zeros(obj.Capacity, 190, 'uint8');
            obj.LengthBuffer = zeros(obj.Capacity, 1, 'uint8');
            obj.HostTimeBuffer = zeros(obj.Capacity, 1);
            obj.ExtensionBuffer = zeros(obj.Capacity,166);
            obj.ExtensionRawBuffer = zeros(obj.Capacity,246,'uint8');
            obj.ExtensionLengthBuffer = zeros(obj.Capacity,1,'uint8');
            obj.ExtensionHostTimeBuffer = zeros(obj.Capacity,1);

            telemetry = zeros(0, 80);
            rawFrames = zeros(0, 190, 'uint8');
            frameLength = zeros(0, 1, 'uint8');
            hostElapsedSeconds = zeros(0, 1);
            extensionTelemetry=zeros(0,166);
            extensionFrames=zeros(0,246,'uint8');
            extensionFrameLength=zeros(0,1,'uint8');
            extensionHostElapsedSeconds=zeros(0,1);
            diagnosticNames = imu.flightDiagnosticNames();
            extensionNames = imu.extensionNames();
            stateSchema='unknown';
            if isfield(config,'FlightStateSchema')
                stateSchema=char(config.FlightStateSchema);
            elseif isfield(config,'ExpectedBuildID') && config.ExpectedBuildID==1401
                stateSchema='StampFlyOfficial-v1';
            end
            info = struct( ...
                'Format', 'StampFlyIMURecordingV8WithExtensions', ...
                'FlightStateSchema', stateSchema, ...
                'StartedAt', datetime('now'), ...
                'StoppedAt', NaT, ...
                'Complete', false, ...
                'ValidFrames', 0, ...
                'MissingFrames', 0, ...
                'CRCRejected', 0, ...
                'Config', config, ...
                'Columns', {{ ...
                    'Version','Sequence','TimeSeconds', ...
                    'AccelX','AccelY','AccelZ', ...
                    'GyroX','GyroY','GyroZ','IMUValid', ...
                    'ToFDistanceM','ToFValid','ToFRangeStatus', ...
                    'FlowDeltaX','FlowDeltaY','FlowQuality', ...
                    'FlowStatus','FlowShutter','XYX','XYY','FlowUsed', ...
                    'MagX_uT','MagY_uT','MagZ_uT','MagValid','MagFresh', ...
                    'QuatW','QuatX','QuatY','QuatZ', ...
                    'OrientationValid','HeightM','HeightValid', ...
                    'FlowDeltaEastM','FlowDeltaNorthM', ...
                    'MotorFR','MotorFL','MotorRR','MotorRL','MotorValid', ...
                    'FlightState','AcceptedCommandSequence', ...
                    diagnosticNames{:},'BuildID', ...
                    'MaxVerticalSpeedMps','LandingBaseThrottle', ...
                    'TuningAckSequence','TuningAckStatus','TuningNamespace'}}, ...
                'RawFrameNote', ...
                    'rawFrames rows are zero-padded to 190 bytes; use frameLength.', ...
                'ExtensionColumns',{{'Kind','Sequence','TimeSeconds','BuildID','FirmwareRevision',extensionNames{:}}}, ...
                'ExtensionFrames',0, ...
                'ExtensionNote','SFIX190 commands (Kind1), SFIY246 sensors (Kind2), SFIH182 horizontal (Kind3). Match by Sequence/TimeSeconds/BuildID. Missing fields are NaN.');
            save(obj.FilePath, 'telemetry', 'rawFrames', 'frameLength', ...
                'hostElapsedSeconds','extensionTelemetry','extensionFrames','extensionFrameLength', ...
                'extensionHostElapsedSeconds','info','-v7.3');
            obj.MatFile = matfile(obj.FilePath, 'Writable', true);
            obj.Clock = tic;
        end

        function append(obj, sample, rawFrame)
            assert(~obj.IsComplete, 'imu:RecordingComplete', ...
                'The recording is already complete.');
            rawFrame = uint8(rawFrame(:).');
            assert(numel(rawFrame) == 37 || numel(rawFrame) == 63 || ...
                numel(rawFrame) == 93 || numel(rawFrame) == 106 || ...
                numel(rawFrame) == 111 || numel(rawFrame) == 114 || ...
                numel(rawFrame) == 182 || numel(rawFrame) == 190, ...
                'imu:RecordingFrameLength', ...
                'Expected a supported SFI frame (37 to 190 bytes).');
            if obj.Buffered >= size(obj.TelemetryBuffer, 1)
                obj.growBuffers();
            end
            k = obj.Buffered + 1;
            obj.TelemetryBuffer(k,:) = [ ...
                double(sample.Version), double(sample.Sequence), ...
                double(sample.TimeSeconds), double(sample.Acceleration), ...
                double(sample.AngularVelocity), double(sample.IMUValid), ...
                double(sample.ToFDistanceM), double(sample.ToFValid), ...
                double(sample.ToFRangeStatus), double(sample.FlowDelta), ...
                double(sample.FlowQuality), double(sample.FlowStatus), ...
                double(sample.FlowShutter), double(sample.XYDisplacementM), ...
                double(sample.FlowUsed), ...
                double(sample.MagneticFieldUT),double(sample.MagValid), ...
                double(sample.MagFresh), ...
                double(sample.Orientation),double(sample.OrientationValid), ...
                double(sample.HeightM),double(sample.HeightValid), ...
                double(sample.FlowCorrectedDeltaENM), ...
                double(sample.MotorCommands),double(sample.MotorValid), ...
                double(sample.FlightState), ...
                double(sample.AcceptedCommandSequence), ...
                double(sample.Diagnostics),double(sample.BuildID), ...
                double(sample.AppliedHeightParameters9(8:9)), ...
                double(sample.TuningAckSequence),double(sample.TuningAckStatus), ...
                double(sample.TuningNamespace)];
            obj.RawBuffer(k,:) = 0;
            obj.RawBuffer(k,1:numel(rawFrame)) = rawFrame;
            obj.LengthBuffer(k) = uint8(numel(rawFrame));
            obj.HostTimeBuffer(k) = toc(obj.Clock);
            obj.Buffered = k;
            if obj.Buffered >= obj.Capacity
                obj.flush();
            end
        end

        function flush(obj)
            obj.flushExtensions();
            if obj.Buffered == 0
                return
            end
            n = obj.Buffered;
            first = obj.Count + 1;
            last = obj.Count + n;
            obj.MatFile.telemetry(first:last,1:80) = ...
                obj.TelemetryBuffer(1:n,:);
            obj.MatFile.rawFrames(first:last,1:190) = ...
                obj.RawBuffer(1:n,:);
            obj.MatFile.frameLength(first:last,1) = ...
                obj.LengthBuffer(1:n);
            obj.MatFile.hostElapsedSeconds(first:last,1) = ...
                obj.HostTimeBuffer(1:n);
            obj.Count = last;
            obj.Buffered = 0;
        end

        function path = finish(obj, missingFrames, crcRejected, stopDetails)
            arguments
                obj
                missingFrames (1,1) double {mustBeNonnegative}
                crcRejected (1,1) double {mustBeNonnegative}
                stopDetails (1,1) struct = struct()
            end
            if ~obj.IsComplete
                obj.flush();
                info = obj.MatFile.info;
                info.StoppedAt = datetime('now');
                info.Complete = true;
                info.ValidFrames = obj.Count;
                info.MissingFrames = missingFrames;
                info.CRCRejected = crcRejected;
                info.ExtensionFrames = obj.ExtensionCount;
                info.RecordingStop = stopDetails;
                obj.MatFile.info = info;
                obj.IsComplete = true;
            end
            path = obj.FilePath;
        end

        function n = bufferedCount(obj)
            n = obj.Count + obj.Buffered;
        end

        function appendExtension(obj,sample,rawFrame)
            assert(~obj.IsComplete,'imu:RecordingClosed','Recording is already complete.');
            assert(ismember(numel(rawFrame),[182 190 246]),'imu:RecordingExtensionLength');
            k=obj.ExtensionBuffered+1;
            obj.ExtensionBuffer(k,:)=[double(sample.Kind),double(sample.Sequence),sample.TimeSeconds, ...
                double(sample.BuildID),double(sample.FirmwareRevision),sample.Values];
            obj.ExtensionRawBuffer(k,:)=0;
            obj.ExtensionRawBuffer(k,1:numel(rawFrame))=uint8(rawFrame(:)).';
            obj.ExtensionLengthBuffer(k)=uint8(numel(rawFrame));
            obj.ExtensionHostTimeBuffer(k)=toc(obj.Clock);
            obj.ExtensionBuffered=k;
            if k>=obj.Capacity,obj.flushExtensions();end
        end
    end

    methods (Access = private)
        function flushExtensions(obj)
            n=obj.ExtensionBuffered;
            if n==0,return;end
            first=obj.ExtensionCount+1;last=obj.ExtensionCount+n;
            obj.MatFile.extensionTelemetry(first:last,1:166)=obj.ExtensionBuffer(1:n,:);
            obj.MatFile.extensionFrames(first:last,1:246)=obj.ExtensionRawBuffer(1:n,:);
            obj.MatFile.extensionFrameLength(first:last,1)=obj.ExtensionLengthBuffer(1:n);
            obj.MatFile.extensionHostElapsedSeconds(first:last,1)=obj.ExtensionHostTimeBuffer(1:n);
            obj.ExtensionCount=last;obj.ExtensionBuffered=0;
        end
        function growBuffers(obj)
            extra = obj.Capacity;
            obj.TelemetryBuffer(end+1:end+extra,:) = 0;
            obj.RawBuffer(end+1:end+extra,:) = uint8(0);
            obj.LengthBuffer(end+1:end+extra,1) = uint8(0);
            obj.HostTimeBuffer(end+1:end+extra,1) = 0;
        end
    end
end
