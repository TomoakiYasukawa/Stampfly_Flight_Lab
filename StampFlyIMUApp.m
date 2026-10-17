classdef StampFlyIMUApp < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './StampFlyIMUApp.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        RootGrid                        matlab.ui.container.GridLayout
        MainTabs                        matlab.ui.container.TabGroup
        MonitorTab                      matlab.ui.container.Tab
        MainGrid                        matlab.ui.container.GridLayout
        AttitudeGrid                    matlab.ui.container.GridLayout
        AttitudeLabel                   matlab.ui.control.Label
        MagAxes                         matlab.ui.control.UIAxes
        MotionGrid                      matlab.ui.container.GridLayout
        HorizontalLabel                 matlab.ui.control.Label
        MotionLabel                     matlab.ui.control.Label
        PathAxes                        matlab.ui.control.UIAxes
        ToFAxes                         matlab.ui.control.UIAxes
        LatestLabel                     matlab.ui.control.Label
        PlotGrid                        matlab.ui.container.GridLayout
        MotorAxes                       matlab.ui.control.UIAxes
        GyroAxes                        matlab.ui.control.UIAxes
        AccelAxes                       matlab.ui.control.UIAxes
        ConfigGrid                      matlab.ui.container.GridLayout
        RecordButton                    matlab.ui.control.Button
        RecordingStatusLabel            matlab.ui.control.Label
        ProtocolLabel                   matlab.ui.control.Label
        ApplyButton                     matlab.ui.control.Button
        ConnectButton                   matlab.ui.control.Button
        ChannelField                    matlab.ui.control.NumericEditField
        ChannelLabel                    matlab.ui.control.Label
        BaudField                       matlab.ui.control.NumericEditField
        BaudLabel                       matlab.ui.control.Label
        RefreshButton                   matlab.ui.control.Button
        PortDropDown                    matlab.ui.control.DropDown
        PortLabel                       matlab.ui.control.Label
        TakeoffButton                   matlab.ui.control.Button
        LandingButton                   matlab.ui.control.Button
        EmergencyButton                 matlab.ui.control.Button
        ResetEmergencyButton            matlab.ui.control.Button
        HeaderGrid                      matlab.ui.container.GridLayout
        BatteryLabel                    matlab.ui.control.Label
        FlightStateLabel                matlab.ui.control.Label
        ErrorLabel                      matlab.ui.control.Label
        FrameLabel                      matlab.ui.control.Label
        RateLabel                       matlab.ui.control.Label
        StatusLabel                     matlab.ui.control.Label
        TitleLabel                      matlab.ui.control.Label
        DroneAxes                       matlab.ui.control.UIAxes
        FlightTab                       matlab.ui.container.Tab
        FlightGrid                      matlab.ui.container.GridLayout
        HeightAppliedLabel              matlab.ui.control.Label
        HeightTuningStatusLabel         matlab.ui.control.Label
        HeightApplyButton               matlab.ui.control.Button
        HeightLandingBaseField          matlab.ui.control.NumericEditField
        HeightLandingBaseLabel          matlab.ui.control.Label
        HeightMaxSpeedField             matlab.ui.control.NumericEditField
        HeightMaxSpeedLabel             matlab.ui.control.Label
        HeightHoverBaseField            matlab.ui.control.NumericEditField
        HeightHoverBaseLabel            matlab.ui.control.Label
        HeightLiftBaseField             matlab.ui.control.NumericEditField
        HeightLiftBaseLabel             matlab.ui.control.Label
        HeightMaxCorrectionField        matlab.ui.control.NumericEditField
        HeightMaxCorrectionLabel        matlab.ui.control.Label
        HeightFilterTimeField           matlab.ui.control.NumericEditField
        HeightFilterTimeLabel           matlab.ui.control.Label
        HeightKiVelField                matlab.ui.control.NumericEditField
        HeightKiVelLabel                matlab.ui.control.Label
        HeightKpVelField                matlab.ui.control.NumericEditField
        HeightKpVelLabel                matlab.ui.control.Label
        HeightKpPosField                matlab.ui.control.NumericEditField
        HeightKpPosLabel                matlab.ui.control.Label
        HeightTuningTitleLabel          matlab.ui.control.Label
        FlightCommandStatusLabel        matlab.ui.control.Label
        FlightStateDetailLabel          matlab.ui.control.Label
        FlightHelpLabel                 matlab.ui.control.Label
        LandSpeedField                  matlab.ui.control.NumericEditField
        LandSpeedLabel                  matlab.ui.control.Label
        HoverHeightField                matlab.ui.control.NumericEditField
        HoverHeightLabel                matlab.ui.control.Label
        ClimbSpeedField                 matlab.ui.control.NumericEditField
        ClimbSpeedLabel                 matlab.ui.control.Label
        FlightTitleLabel                matlab.ui.control.Label
        HistoryTab                      matlab.ui.container.Tab
        HistoryRootGrid                 matlab.ui.container.GridLayout
        HistoryMainGrid                 matlab.ui.container.GridLayout
        HistorySummaryTable             matlab.ui.control.Table
        HistoryChartGrid                matlab.ui.container.GridLayout
        HistoryStateAxes                matlab.ui.control.UIAxes
        HistoryXYAxes                   matlab.ui.control.UIAxes
        HistoryValidityAxes             matlab.ui.control.UIAxes
        HistoryMotorAxes                matlab.ui.control.UIAxes
        HistoryThrottleAxes             matlab.ui.control.UIAxes
        HistoryControlAxes              matlab.ui.control.UIAxes
        HistoryVelocityErrorAxes        matlab.ui.control.UIAxes
        HistoryHeightErrorAxes          matlab.ui.control.UIAxes
        HistoryVerticalSpeedAxes        matlab.ui.control.UIAxes
        HistoryHeightAxes               matlab.ui.control.UIAxes
        HistorySidebarGrid              matlab.ui.container.GridLayout
        HistoryStatusLabel              matlab.ui.control.Label
        HistoryList                     matlab.ui.control.ListBox
        HistoryRangeDropDown            matlab.ui.control.DropDown
        HistoryAddButton                matlab.ui.control.Button
        HistoryRefreshButton            matlab.ui.control.Button
        HistoryTitleLabel               matlab.ui.control.Label
    end

    properties (Access = private)
        AccelData
        AccelLines
        ByteBuffer
        CRCErrorCount = 0
        DrawClock
        FlightCommandSequence = 'uint16(0)'
        FlightRecorder
        ForeignFrameCount = 0
        FrameCount = 0
        GroundTracker
        GyroData
        GyroLines
        HasTuningTelemetry = ""
        HeightData
        HeightLine
        HorizontalClock = [  ]
        HorizontalSample = [  ]
        LastFlightHeartbeatClock = '[]'
        LastFlightSendClock = '[]'
        LastFlightState = 'uint8(0)'
        LastLedCommandClock
        LastReceivedClock
        LastTuningSendClock = ""
        MagData
        MagLines
        MissingCount = 0
        MotorData
        MotorLines
        PathLine
        PendingFlightOperation = 'uint8(0)'
        PendingFlightRetries = '0'
        PendingFlightSequence = 'NaN'
        PendingTuningRetries = ""
        PendingTuningSequence = ""
        PendingTuningValues = ""
        PlotTimeline
        PlotWindowSeconds = 10
        PoseView
        PrevSequence
        RecentTimes
        RecordStartCRCCount
        RecordStartMissingCount
        RecordingActive
        RecordingCleanupListener
        RecordingTimer
        RecordingWriter
        SerialDevice
        StartClock
        TimeData
        ToFData
        ToFLine
        TuningCommandSequence = ""
        XYData
    end

    properties (Access = public)
        AutoRecordingEnabled = true
        ExpectedBuildID = 1401
        RecordingFolder
    end

    methods (Access = private)

        function applyChannel(app)
            if isempty(app.SerialDevice)
                app.StatusLabel.Text = '先にCOMポートへ接続してください';
                return
            end
            channel = round(app.ChannelField.Value);
            command = uint8([double(sprintf('CH=%d',channel)) 10]);
            write(app.SerialDevice, command, 'uint8');
            app.StatusLabel.Text = sprintf('CH %d の設定を送信', channel);
        end

        function captureExtension(app,sample,frame)
            app.captureRecording(sample,frame);
        end

        function captureFrame(app,sample,frame)
            app.captureRecording(sample,frame);
        end

        function captureRecording(app,sample,frame)
            app.ensureFlightRecorder();
            app.FlightRecorder.accept(sample,frame,toc(app.StartClock),app.MissingCount,app.CRCErrorCount);
            app.syncRecordingView();
        end

        function cleanupFlightRecording(app)
            if ~isempty(app.RecordingTimer) && isvalid(app.RecordingTimer)
                stop(app.RecordingTimer);delete(app.RecordingTimer);
            end
            app.RecordingTimer=[];
            if ~isempty(app.FlightRecorder) && ~isempty(app.FlightRecorder.Writer)
                app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'app_closed');
            end
        end

        function connectReceiver(app)
            app.disconnectReceiver();
            try
                port = string(app.PortDropDown.Value);
                baud = round(app.BaudField.Value);
                device = serialport(port, baud, 'Timeout', 0.2);
                configureTerminator(device, 'LF');
                warmupClock = tic;
                while toc(warmupClock) < 0.8
                    count = device.NumBytesAvailable;
                    if count > 0
                        read(device,count,'uint8');
                    else
                        pause(0.01);
                    end
                end
                flush(device);
                app.SerialDevice = device;
                app.ConnectButton.Text = '切断';
                app.resetData();
                configureCallback(device, 'byte', 37, @(~,~)app.onSerialData());
                write(device, uint8([double('PING') 10]), 'uint8');
                app.StatusLabel.Text = '接続中: ' + port;
            catch err
                app.StatusLabel.Text = '接続失敗: ' + string(err.message);
                app.SerialDevice = [];
                app.ConnectButton.Text = '接続';
            end
        end

        function disconnectReceiver(app)
            if ~isempty(app.RecordingWriter)
            app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'disconnected');
                app.syncRecordingView();
        end
        if ~isempty(app.SerialDevice)
            app.sendLedState(uint8(0));
                try
                    configureCallback(app.SerialDevice, 'off');
                catch
                end
                try
                    delete(app.SerialDevice);
                catch
                end
            end
            app.SerialDevice = [];
            if ~isempty(app.FlightRecorder),app.FlightRecorder.resetConnection();end
            app.ConnectButton.Text = '接続';
            app.LastFlightHeartbeatClock = [];
            app.PendingFlightSequence = NaN;
                    app.PendingTuningSequence = NaN;
                    app.HasTuningTelemetry = false;
                    app.HeightApplyButton.Enable = 'off';
                    app.HeightTuningStatusLabel.Text = '設定: 機体の接続待ち';
            app.StatusLabel.Text = '未接続';
        end

        function ensureFlightRecorder(app)
            % 受信機の設定だけを保存し、飛行・モーター指令は送らない。
            config=struct('Port',string(app.PortDropDown.Value),'BaudRate',app.BaudField.Value, ...
                'RadioChannel',app.ChannelField.Value,'ExpectedBuildID',app.ExpectedBuildID);
            if isempty(app.FlightRecorder)
                app.FlightRecorder=imu.FlightRecorder(app.RecordingFolder,config);
            end
            app.FlightRecorder.Config=config;
            if strlength(string(app.RecordingFolder))>0
                app.FlightRecorder.Folder=string(app.RecordingFolder);
            end
            app.FlightRecorder.Enabled=logical(app.AutoRecordingEnabled);
        end

        function name = flightStateName(~,state)
            name=imu.flightStateName(state);
        end

        function initializeFlightRecorder(app)
            app.ensureFlightRecorder();
            app.RecordingTimer=timer('Name','StampFlyFlightRecorder', ...
                'ExecutionMode','fixedSpacing','Period',.25,'BusyMode','drop', ...
                'TimerFcn',@(~,~)app.pollFlightRecording());
            % delete(app)やウィンドウ終了でもタイマー・未確定記録を片付ける。
            app.RecordingCleanupListener=addlistener(app.UIFigure,'ObjectBeingDestroyed', ...
                @(~,~)app.cleanupFlightRecording());
            start(app.RecordingTimer);
            app.syncRecordingView();
        end

        function initializePlots(app)
            hold(app.AccelAxes, 'on');
            hold(app.GyroAxes, 'on');
            for k = 1:3
                app.AccelLines(k) = plot(app.AccelAxes, nan, nan);
                app.GyroLines(k) = plot(app.GyroAxes, nan, nan);
            end
            legend(app.AccelAxes, {'X','Y','Z'}, 'Location','northeast');
            legend(app.GyroAxes, {'X','Y','Z'}, 'Location','northeast');
            grid(app.AccelAxes, 'on');
            grid(app.GyroAxes, 'on');
            xlim(app.AccelAxes, [0 10]);
            xlim(app.GyroAxes, [0 10]);
            hold(app.ToFAxes,'on');
            hold(app.PathAxes,'on');
            app.ToFLine = plot(app.ToFAxes,nan,nan,'Color',[0.35 0.35 0.35]);
            app.HeightLine = plot(app.ToFAxes,nan,nan, ...
                'Color',[0.00 0.45 0.74],'LineWidth',1.8);
            legend(app.ToFAxes,[app.ToFLine app.HeightLine], ...
                {'斜距離','補正高さ'},'Location','northeast');
            title(app.ToFAxes,'ToF / 補正高さ');
            ylabel(app.ToFAxes,'距離・高さ [m]');
            app.PathLine = plot(app.PathAxes,nan,nan);
            grid(app.ToFAxes,'on');
            grid(app.PathAxes,'on');
            xlim(app.ToFAxes,[0 10]);
            xlim(app.PathAxes,[-0.05 0.05]);
            ylim(app.PathAxes,[-0.05 0.05]);
            hold(app.MagAxes,'on');
            for k = 1:3
                app.MagLines(k) = plot(app.MagAxes,nan,nan);
            end
            legend(app.MagAxes,{'X','Y','Z'},'Location','northeast');
            grid(app.MagAxes,'on');
            xlabel(app.MagAxes,'時間 [s]');
            ylabel(app.MagAxes,'磁気 [uT]');
            title(app.MagAxes,'BMM150 磁気');
            xlim(app.MagAxes,[0 10]);
            hold(app.MotorAxes,'on');
            app.MotorLines = gobjects(1,4);
            for k = 1:4
                app.MotorLines(k) = plot(app.MotorAxes,nan,nan);
            end
            legend(app.MotorAxes,{'FR','FL','RR','RL'},'Location','northeast');
            title(app.MotorAxes,'モーター指令');
            ylabel(app.MotorAxes,'指令 [0-255]');
            grid(app.MotorAxes,'on');
            xlim(app.MotorAxes,[0 10]);
            ylim(app.MotorAxes,[0 255]);
        end

        function onSerialData(app)
            if isempty(app.SerialDevice), return; end
            try
                count = app.SerialDevice.NumBytesAvailable;
                if count == 0, return; end
                bytes = read(app.SerialDevice, count, 'uint8');
                app.processBytes(bytes);
            catch err
                app.StatusLabel.Text = '受信エラー: ' + string(err.message);
            end
        end

        function pollFlightRecording(app)
            if isempty(app.FlightRecorder) || ~isgraphics(app.UIFigure),return;end
            app.FlightRecorder.poll(toc(app.StartClock),app.MissingCount,app.CRCErrorCount);
            app.syncRecordingView();
        end

        function values = readHeightTuning(app)
            values = single([app.HeightKpPosField.Value; app.HeightKpVelField.Value; ...
                app.HeightKiVelField.Value; app.HeightFilterTimeField.Value; ...
                app.HeightMaxCorrectionField.Value; app.HeightLiftBaseField.Value; ...
                app.HeightHoverBaseField.Value; app.HeightMaxSpeedField.Value; ...
                app.HeightLandingBaseField.Value]);
        end

        function [accepted,positionENU,heightNow] = recordSample(app, sample)
            nowSeconds = toc(app.StartClock);
            [time,restarted,accepted] = app.PlotTimeline.advance( ...
                sample.TimeSeconds,sample.Sequence,nowSeconds,sample.FlightState);
            positionENU = [NaN NaN NaN];
            heightNow = NaN;
            if ~accepted, return; end
            if restarted
                app.PrevSequence = NaN;
                app.GroundTracker.reset();
                % 再起動前後を線で結ばず、直近の履歴は残す。
                app.TimeData(end+1,1) = time;
                app.AccelData(end+1,:) = NaN;
                app.GyroData(end+1,:) = NaN;
                app.ToFData(end+1,1) = NaN;
                app.HeightData(end+1,1) = NaN;
                app.XYData(end+1,:) = NaN;
                app.MagData(end+1,:) = NaN;
                app.MotorData(end+1,:) = NaN;
            end
            if ~isnan(app.PrevSequence)
                gap = mod(double(sample.Sequence) - app.PrevSequence, 65536);
                if gap > 1 && gap < 32768
                    app.MissingCount = app.MissingCount + gap - 1;
                end
            end
            app.PrevSequence = double(sample.Sequence);
            app.FrameCount = app.FrameCount + 1;
            app.TimeData(end+1,1) = time;
            app.AccelData(end+1,:) = double(sample.Acceleration);
            app.GyroData(end+1,:) = double(sample.AngularVelocity);
            app.ToFData(end+1,1) = double(sample.ToFDistanceM);
            if ~sample.ToFValid, app.ToFData(end,1) = NaN; end
            [positionENU,heightNow] = app.GroundTracker.update(sample);
            app.HeightData(end+1,1) = heightNow;
            app.XYData(end+1,:) = double(sample.XYDisplacementM);
            app.MagData(end+1,:) = double(sample.MagneticFieldUT);
            app.MotorData(end+1,:) = double(sample.MotorCommands);
            if ~sample.MagValid, app.MagData(end,:) = NaN; end
            % 受信レートに依存せず10秒を保持し、左端をまたぐ1点も残す。
            first = find(app.TimeData >= time-app.PlotWindowSeconds,1);
            keep = max(1,first-1):numel(app.TimeData);
            app.TimeData = app.TimeData(keep);
            app.AccelData = app.AccelData(keep,:);
            app.GyroData = app.GyroData(keep,:);
            app.ToFData = app.ToFData(keep,:);
            app.HeightData = app.HeightData(keep,:);
            app.XYData = app.XYData(keep,:);
            app.MagData = app.MagData(keep,:);
            app.MotorData = app.MotorData(keep,:);
            app.RecentTimes(end+1,1) = nowSeconds;
            app.RecentTimes = app.RecentTimes(app.RecentTimes >= nowSeconds-1);
        end

        function refreshHorizontalStatus(app)
            % 水平制御専用の局所XYを表示し、従来の東・北の軌跡とは区別します。
            if isempty(app.HorizontalSample)
                app.HorizontalLabel.Text = '水平補助: 未受信';
                return
            end
            h = app.HorizontalSample.Values(122:161);
            states = {'手動','準備・復帰待ち','位置保持','移動','減速'};
            state = round(h(16));
            if ~isfinite(state) || state < 0 || state > 4
                stateText = '状態不明';
            else
                stateText = states{state+1};
            end
            stale = isempty(app.HorizontalClock) || toc(app.HorizontalClock) > .5;
            suffix = '';if stale,suffix = ' / 更新停止';end
            app.HorizontalLabel.Text = sprintf(['水平補助: %s / 有効 %d / 観測 %d%s\n' ...
                '速度 X %.2f / Y %.2f → 目標 %.2f / %.2f m/s'], ...
                stateText,h(17)~=0,h(21)~=0,suffix,h(3:6));
            app.HorizontalLabel.Tooltip = sprintf(['局所X=基準機首、Y=右。東・北の表示軌跡とは別の座標です。\n' ...
                '位置 %.3f / %.3f m、保持目標 %.3f / %.3f m、混合率 %.2f\n' ...
                '棄却理由 %.0f（0正常、1区間不整合・低品質、2フロー停止、3姿勢、4ToF、5IMU・時間、6速度外れ値）'], ...
                h(1:2),h(7:8),h(15),h(24));
        end

        function refreshMonitor(app,sample,positionENU,heightNow)
            app.StatusLabel.Text = '受信中';
            app.RateLabel.Text = sprintf('受信: %d Hz',numel(app.RecentTimes));
            app.FrameLabel.Text = sprintf('フレーム: %d', app.FrameCount);
            app.ErrorLabel.Text = sprintf('欠落: %d / CRC: %d / 対象外: %d', ...
                app.MissingCount, app.CRCErrorCount,app.ForeignFrameCount);
            app.LatestLabel.Text = sprintf(['a [m/s²] = %.2f, %.2f, %.2f    ' ...
                'ω [rad/s] = %.3f, %.3f, %.3f    IMU有効: %d'], ...
                double(sample.Acceleration), double(sample.AngularVelocity), ...
                sample.IMUValid);
            if sample.Version >= 2
                if sample.ToFValid
                    heightText = sprintf('%.3f m',double(sample.ToFDistanceM));
                else
                    heightText = sprintf('無効 (状態 %d)',sample.ToFRangeStatus);
                end
                if isfinite(heightNow)
                    correctedText = sprintf('%.3f m',heightNow);
                else
                    correctedText = '無効';
                end
                if sample.Version >= 4
                    xyCaption = '補正EN';
                    title(app.PathAxes,'補正XY軌跡 (東・北)');
                    xlabel(app.PathAxes,'東 E [m]');
                    ylabel(app.PathAxes,'北 N [m]');
                    app.MotionLabel.Tooltip = sprintf('補正Δ E %.4f / N %.4f m', ...
                        double(sample.FlowCorrectedDeltaENM));
                else
                    xyCaption = '相対XY';
                    app.MotionLabel.Tooltip = '';
                end
                app.MotionLabel.Text = sprintf(['ToF: %s / 高さ: %s    ' ...
                    '%s: %.3f, %.3f m    生Flow: %.0f, %.0f count    ' ...
                    'Flow読取: %d / Flow採用: %d / Q: %d / 露光: %d'], ...
                    heightText,correctedText,xyCaption,double(sample.XYDisplacementM), ...
                    double(sample.FlowDelta),sample.FlowStatus, ...
                    sample.FlowUsed, ...
                    sample.FlowQuality,sample.FlowShutter);
            else
                app.MotionLabel.Text = 'SFI1受信中: ToF・Flowデータなし';
            end
            if sample.Version >= 3
                app.AttitudeLabel.Text = sprintf([ ...
                    'BMM150 [uT]: %.1f, %.1f, %.1f    ' ...
                    '読取: %d / 新規: %d    姿勢有効: %d'], ...
                    double(sample.MagneticFieldUT),sample.MagValid, ...
                    sample.MagFresh,sample.OrientationValid);
                app.PoseView.update(sample.Orientation, ...
                    sample.OrientationValid,positionENU);
            else
                app.AttitudeLabel.Text = 'SFI1/SFI2: 磁気・姿勢データなし';
                app.PoseView.update([1 0 0 0],false);
            end
            if sample.BatteryValid
                if sample.BatteryVoltageV <= 3.34
                    app.BatteryLabel.Text = sprintf('電池 %.2f V / 要充電',double(sample.BatteryVoltageV));
                    app.BatteryLabel.FontColor = [0.8 0.12 0.12];
                else
                    app.BatteryLabel.Text = sprintf('電池 %.2f V',double(sample.BatteryVoltageV));
                    app.BatteryLabel.FontColor = [0.15 0.15 0.15];
                end
            else
                app.BatteryLabel.Text = '電池: 未取得';
                app.BatteryLabel.FontColor = [0.4 0.4 0.4];
            end
            app.refreshHorizontalStatus();
        end

        function refreshPorts(app)
            selected = string(app.PortDropDown.Value);
            ports = string(serialportlist('available'));
            ports = unique([ports(:); 'COM9'], 'stable');
            app.PortDropDown.Items = cellstr(ports);
            if any(strcmpi(ports, selected))
                app.PortDropDown.Value = char(selected);
            else
                app.PortDropDown.Value = 'COM9';
            end
        end

        function resetData(app)
            app.ByteBuffer = zeros(0,1,'uint8');
            app.HorizontalSample = [];app.HorizontalClock = [];
            app.HorizontalLabel.Text = '水平補助: 未受信';
            if isempty(app.PlotTimeline)
                app.PlotTimeline = imu.LivePlotTimeline();
            else
                app.PlotTimeline.reset();
            end
            app.ForeignFrameCount = 0;
            app.FlightStateLabel.Text = '飛行状態: 未受信';
            app.FlightStateDetailLabel.Text = '機体状態: 未受信';
                    app.PendingTuningSequence = NaN;
                    app.LastTuningSendClock = [];
                    app.HasTuningTelemetry = false;
                    app.HeightApplyButton.Enable = 'off';
                    app.HeightTuningStatusLabel.Text = '設定: 機体の接続待ち';
                    app.HeightAppliedLabel.Text = '機体の適用値: 未受信';
            app.BatteryLabel.Text = '電池: 未取得';
            app.BatteryLabel.FontColor = [0.4 0.4 0.4];
            app.TimeData = zeros(0,1);
            app.AccelData = zeros(0,3);
            app.GyroData = zeros(0,3);
            app.ToFData = zeros(0,1);
            app.HeightData = zeros(0,1);
            app.XYData = zeros(0,2);
            app.MagData = zeros(0,3);
            app.MotorData = zeros(0,4);
            if ~isempty(app.GroundTracker), app.GroundTracker.reset(); end
            app.PrevSequence = NaN;
            app.RecentTimes = zeros(0,1);
            app.FrameCount = 0;
            app.CRCErrorCount = 0;
            app.MissingCount = 0;
            app.StartClock = tic;
            app.DrawClock = [];
            app.RateLabel.Text = '受信: 0 Hz';
            app.FrameLabel.Text = 'フレーム: 0';
            app.ErrorLabel.Text = '欠落: 0 / CRC: 0 / 対象外: 0';
            app.FrameLabel.Tooltip = sprintf('対象 BuildID: %.0f',double(app.ExpectedBuildID));
            app.LatestLabel.Text = '最新値: 受信待機中';
            app.MotionLabel.Text = 'ToF・Optical flow: データを待機中';
            app.AttitudeLabel.Text = '磁気・姿勢: データ待機中';
            if ~isempty(app.PoseView), app.PoseView.reset(); end
            for line = [app.AccelLines app.GyroLines app.ToFLine app.HeightLine ...
                    app.MagLines app.MotorLines app.PathLine]
                if isgraphics(line)
                    set(line,'XData',nan,'YData',nan);
                end
            end
        end

        function sendFlightCommand(app,~)
            app.FlightCommandStatusLabel.Text = '公式 JoyStick で操作します。実出力は機体モデルの設定に従います。';
        end

        function sendHeightTuning(app)
            app.HeightTuningStatusLabel.Text = '公式 PID の係数を固定して比較中';
        end

        function sendLedState(app, mode)
            if isempty(app.SerialDevice)
                return
            end
            try
                command = uint8([double(sprintf('LED=%d',mode)) 10]);
                write(app.SerialDevice,command,'uint8');
                app.LastLedCommandClock = tic;
            catch err
                app.StatusLabel.Text = 'LED指令エラー: ' + string(err.message);
            end
        end

        function syncRecordingView(app)
            if isempty(app.FlightRecorder),return;end
            recorder=app.FlightRecorder;
            app.RecordingWriter=recorder.Writer;app.RecordingActive=recorder.Active;
            app.RecordingStatusLabel.Text=char(recorder.Status);
            if strlength(recorder.ErrorMessage)>0
                app.RecordButton.Text='保存再試行';app.RecordButton.Enable='on';
                app.RecordingStatusLabel.Tooltip=char(recorder.ErrorMessage);
            elseif recorder.Active
                app.RecordingStatusLabel.Tooltip=char(recorder.Writer.FilePath);
                if recorder.Automatic
                    app.RecordButton.Text='自動記録中';app.RecordButton.Enable='off';
                else
                    app.RecordButton.Text='記録停止';app.RecordButton.Enable='on';
                end
            else
                app.RecordButton.Text='手動記録開始';app.RecordButton.Enable='on';
                app.RecordingStatusLabel.Tooltip=char(recorder.LastPath);
            end
        end

        function updateFlightLink(app,sample)
            if sample.Version >= 6
                if isnan(app.PendingFlightSequence)
                    app.FlightCommandSequence = sample.AcceptedCommandSequence;
                end
                app.LastFlightState = sample.FlightState;
                name = app.flightStateName(sample.FlightState);
                app.FlightStateLabel.Text = '飛行状態: ' + string(name);
                app.FlightStateDetailLabel.Text = sprintf('公式状態: %s    操作: JoyStick',name);
                if ~isnan(app.PendingFlightSequence) && double(sample.AcceptedCommandSequence) == app.PendingFlightSequence
                    app.FlightCommandStatusLabel.Text = sprintf('機体が指令 %d を受理',app.PendingFlightSequence);
                    app.PendingFlightSequence = NaN;
                end
            end
        end

        function updateLedHeartbeat(app)
            if isempty(app.LastLedCommandClock) || ...
                    toc(app.LastLedCommandClock) >= 0.5
                mode = uint8(1);
                if app.RecordingActive
                    mode = uint8(2);
                end
                app.sendLedState(mode);
            end
        end

        function updatePlots(app)
            if isempty(app.TimeData), return; end
            for k = 1:3
                set(app.AccelLines(k),'XData',app.TimeData,'YData',app.AccelData(:,k));
                set(app.GyroLines(k),'XData',app.TimeData,'YData',app.GyroData(:,k));
            end
            for k = 1:4
                set(app.MotorLines(k),'XData',app.TimeData,'YData',app.MotorData(:,k));
            end
            right = max(app.PlotWindowSeconds, app.TimeData(end));
            xlim(app.AccelAxes, [right-app.PlotWindowSeconds right]);
            xlim(app.GyroAxes, [right-app.PlotWindowSeconds right]);
            xlim(app.MotorAxes, [right-app.PlotWindowSeconds right]);
            set(app.ToFLine,'XData',app.TimeData,'YData',app.ToFData);
            set(app.HeightLine,'XData',app.TimeData,'YData',app.HeightData);
            xlim(app.ToFAxes,[right-app.PlotWindowSeconds right]);
            tofValues = [app.ToFData;app.HeightData];
            tofValues = tofValues(isfinite(tofValues));
            if ~isempty(tofValues)
                low = min(tofValues);
                high = max(tofValues);
                padding = max(0.025,0.1*(high-low));
                bottom = max(0,low-padding);
                ylim(app.ToFAxes,[bottom max(high+padding,bottom+0.05)]);
            end
            for k = 1:3
                set(app.MagLines(k),'XData',app.TimeData,'YData',app.MagData(:,k));
            end
            xlim(app.MagAxes,[right-app.PlotWindowSeconds right]);
            valid = all(isfinite(app.XYData),2);
            xy = app.XYData(valid,:);
            set(app.PathLine,'XData',xy(:,1),'YData',xy(:,2));
            if ~isempty(xy)
                low = min(xy,[],1);
                high = max(xy,[],1);
                radius = max(0.05,0.6*max(high-low));
                center = (low+high)/2;
                xlim(app.PathAxes,center(1)+[-radius radius]);
                ylim(app.PathAxes,center(2)+[-radius radius]);
            end
        end

        function updateTuningLink(app,~)
            app.HeightApplyButton.Enable = 'off';
            app.HeightTuningStatusLabel.Text = '公式 PID 固定 / ベンチ検証';
            app.HeightAppliedLabel.Text = '高度 PID: 0.38 / 10 / 0.5 / 0.125    速度 PID: 0.08 / 0.95 / 0.08 / 0.125';
        end

    end

    methods (Access = public)

        function processBytes(app, bytes)
            if isempty(app.PlotTimeline)
                app.resetData(); % 開いたままコードを更新した場合も表示状態を初期化する。
            end
            app.ByteBuffer = [app.ByteBuffer; uint8(bytes(:))];
            latestSample = [];
            latestPosition = [NaN NaN NaN];
            latestHeight = NaN;
            while numel(app.ByteBuffer) >= 4
                first = app.ByteBuffer(1:4);
                frameBytes = imu.frameLength(first);
                if frameBytes == 0
                    marks = find(app.ByteBuffer(1:end-3) == uint8('S') & ...
                        app.ByteBuffer(2:end-2) == uint8('F') & ...
                        app.ByteBuffer(3:end-1) == uint8('I') & ...
                        (app.ByteBuffer(4:end) == uint8('1') | ...
                         app.ByteBuffer(4:end) == uint8('2') | ...
                         app.ByteBuffer(4:end) == uint8('3') | ...
                         app.ByteBuffer(4:end) == uint8('4') | ...
                         app.ByteBuffer(4:end) == uint8('5') | ...
                         app.ByteBuffer(4:end) == uint8('6') | ...
                         app.ByteBuffer(4:end) == uint8('7') | ...
                         app.ByteBuffer(4:end) == uint8('8') | ...
                     app.ByteBuffer(4:end) == uint8('X') | ...
                     app.ByteBuffer(4:end) == uint8('Y') | ...
                         app.ByteBuffer(4:end) == uint8('H')),1);
                    lf = find(app.ByteBuffer == 10,1);
                    if ~isempty(lf) && (isempty(marks) || lf < marks(1))
                        line = strtrim(string(char(app.ByteBuffer(1:lf-1).')));
                        if startsWith(line,'READY,') || startsWith(line,'PONG,')
                            app.StatusLabel.Text = '受信機: CH ' + extractAfter(line,',');
                        elseif startsWith(line,'OK,')
                            app.StatusLabel.Text = '設定完了: CH ' + extractAfter(line,',');
                        elseif startsWith(line,'TUNEACK,')
                            if ~isnan(app.PendingTuningSequence) && ...
                                    str2double(extractAfter(line,',')) == app.PendingTuningSequence
                                app.HeightTuningStatusLabel.Text = '受信機が送信: ' + ...
                                    extractAfter(line,',') + ' / 機体確認待ち';
                            end
                        elseif startsWith(line,'CTLACK,')
                            if ~isnan(app.PendingFlightSequence)
                                app.FlightCommandStatusLabel.Text = '受信機が送信: ' + extractAfter(line,',') + ' / 機体確認待ち';
                            end
                        elseif startsWith(line,'ERR,')
                            app.StatusLabel.Text = '受信機エラー: ' + line;
                        end
                        app.ByteBuffer(1:lf) = [];
                    elseif ~isempty(marks)
                        app.ByteBuffer(1:marks(1)-1) = [];
                    else
                        if numel(app.ByteBuffer) > 256
                            app.ByteBuffer = app.ByteBuffer(end-3:end);
                        end
                        break
                    end
                    continue
                end
                if numel(app.ByteBuffer) < frameBytes, break; end
                candidate = app.ByteBuffer(1:frameBytes);
                try
                    if ismember(first(4),uint8('XYH'))
                        sample = imu.decodeExtensionFrame(candidate);
                    else
                        sample = imu.decodeFrame(candidate);
                    end
                catch
                    app.CRCErrorCount = app.CRCErrorCount + 1;
                    app.ByteBuffer(1) = [];
                    app.ErrorLabel.Text = sprintf('欠落: %d / CRC: %d', ...
                        app.MissingCount,app.CRCErrorCount);
                    continue
                end
                app.ByteBuffer(1:frameBytes) = [];
                if isfield(sample,'Kind')
                    if app.ExpectedBuildID==0 || double(sample.BuildID)==double(app.ExpectedBuildID)
                        app.captureExtension(sample,candidate);
                        if sample.Kind==3
                            app.HorizontalSample=sample;app.HorizontalClock=tic;
                            app.refreshHorizontalStatus();
                        end
                    end
                    continue
                end
                % 同じチャンネルの別ビルドを時刻・欠落・記録へ混ぜない。
                if sample.Version >= 7 && app.ExpectedBuildID ~= 0 && ...
                        double(sample.BuildID) ~= double(app.ExpectedBuildID)
                    app.ForeignFrameCount = app.ForeignFrameCount + 1;
                    continue
                end
                [accepted,positionENU,heightNow] = app.recordSample(sample);
                    app.captureFrame(sample,candidate); % CRC正常の生データを描画条件によらず保存する。
                if accepted
            % 採用した最新サンプルを描画用に保持する。
                    latestSample = sample;
                    latestPosition = positionENU;
                    latestHeight = heightNow;
                    app.LastReceivedClock = tic;
                end
            end
            % バイト列の処理を終えてから1回描画する。描画中の再入も抑える。
            if ~isempty(latestSample)
                app.updateLedHeartbeat();
            end
            if isempty(app.DrawClock) || toc(app.DrawClock) >= 0.08
                app.ErrorLabel.Text = sprintf('欠落: %d / CRC: %d / 対象外: %d', ...
                    app.MissingCount,app.CRCErrorCount,app.ForeignFrameCount);
                if ~isempty(latestSample)
                    app.updateFlightLink(latestSample);
                    app.updateTuningLink(latestSample);
                    app.refreshMonitor(latestSample,latestPosition,latestHeight);
                    app.updatePlots();
                    app.DrawClock = tic;
                    drawnow limitrate nocallbacks;
                end
            end
        end

        function state=recordingStatus(app)
            % 保存状態とファイル名を、機器に触れずプログラムから確認する。
            app.ensureFlightRecorder();r=app.FlightRecorder;
            file="";if ~isempty(r.Writer),file=r.Writer.FilePath;end
            state=struct('Active',r.Active,'Automatic',r.Automatic,'CurrentFile',file, ...
                'LastFile',r.LastPath,'SavedFiles',r.SavedPaths,'Status',r.Status,'Error',r.ErrorMessage);
        end

        function path=startRecording(app,outputFolder)
            if nargin<2,outputFolder="";end
            app.ensureFlightRecorder();
            path=app.FlightRecorder.startManual(outputFolder,app.MissingCount,app.CRCErrorCount);
            app.syncRecordingView();
            if ~isempty(app.LastReceivedClock) && toc(app.LastReceivedClock)<1
                app.sendLedState(uint8(2));
            end
        end

        function path=stopRecording(app)
            path="";
            if isempty(app.FlightRecorder),return;end
            path=app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'manual_stop');
            app.syncRecordingView();
            if strlength(path)>0,fprintf('RECORDED_MAT=%s\n',path);end
            if ~isempty(app.LastReceivedClock) && toc(app.LastReceivedClock)<1
                app.sendLedState(uint8(1));
            else
                app.sendLedState(uint8(0));
            end
        end

    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            run(fullfile(fileparts(which('StampFlyIMUApp')),'config','startup.m'));
            imu.fitAppWindow(app.UIFigure);
            app.SerialDevice = [];
            app.FlightCommandSequence = uint16(0);
                        app.TuningCommandSequence = uint16(0);
                        app.PendingTuningSequence = NaN;
                        app.PendingTuningValues = single(zeros(9,1));
                        app.PendingTuningRetries = 0;
                        app.LastTuningSendClock = [];
                        app.HasTuningTelemetry = false;
                        app.HeightApplyButton.Enable = 'off';
                        app.HeightTuningStatusLabel.Text = '設定: 機体の接続待ち';
            app.PendingFlightSequence = NaN;
            app.PendingFlightRetries = 0;
            app.LastFlightSendClock = [];
            app.LastFlightHeartbeatClock = [];
            app.FlightCommandStatusLabel.Text = '指令: 未送信';
            app.FlightStateDetailLabel.Text = '機体状態: 未受信';
            app.RecordingWriter = [];
            app.RecordingActive = false;
            app.RecordStartMissingCount = 0;
            app.RecordStartCRCCount = 0;
            app.LastLedCommandClock = [];
            app.LastReceivedClock = [];
            app.RecordingStatusLabel.Text = '記録: 停止中';
            app.AccelLines = gobjects(1,3);
            app.GyroLines = gobjects(1,3);
            app.MagLines = gobjects(1,3);
            app.PoseView = [];
            app.GroundTracker = imu.FlatGroundPoseTracker();
            app.ToFLine = gobjects(1,1);
            app.HeightLine = gobjects(1,1);
            app.PathLine = gobjects(1,1);
            app.BaudField.Value = 921600;
            app.ChannelField.Value = 3;
            app.resetData();
            app.refreshPorts();
            app.initializePlots();
            app.PoseView = imu.StampFlyPoseView(app.DroneAxes);
            imu.RecordingHistoryView.refresh(app);
            app.TitleLabel.Text = 'StampFly 公式制御 400 Hz ロガー';
            app.UIFigure.Name = 'StampFly Official 400 Hz';
            app.TakeoffButton.Enable = 'off';
            app.LandingButton.Enable = 'off';
            app.EmergencyButton.Enable = 'off';
            app.ResetEmergencyButton.Enable = 'off';
            app.HeightApplyButton.Enable = 'off';
            app.FlightHelpLabel.Text = '離着陸と操縦は公式 JoyStick で行います。実モーター出力は機体に書き込んだモデルの設定に従います。';
            title(app.MotorAxes,'モーター指令');
            app.RecordingFolder="";
            app.AutoRecordingEnabled=true;
            app.initializeFlightRecorder();
        end

        % Close request function: UIFigure
        function closeApp(app, event)
            app.cleanupFlightRecording();
            app.disconnectReceiver();
            if ~isempty(app.RecordingWriter)
                uialert(app.UIFigure, ...
                    'MATファイルの保存に失敗しました。保存再試行を押してください。', ...
                    '記録を保存できません');
                return
            end
            delete(app);
        end

        % Button pushed function: ResetEmergencyButton
        function resetEmergencyButtonPushed(app, event)
            app.sendFlightCommand(uint8(4));
        end

        % Button pushed function: EmergencyButton
        function emergencyButtonPushed(app, event)
            app.sendFlightCommand(uint8(3));
        end

        % Button pushed function: LandingButton
        function landingButtonPushed(app, event)
            app.sendFlightCommand(uint8(2));
        end

        % Button pushed function: TakeoffButton
        function takeoffButtonPushed(app, event)
            app.sendFlightCommand(uint8(1));
        end

        % Button pushed function: RefreshButton
        function refreshButtonPushed(app, event)
            app.refreshPorts();
        end

        % Button pushed function: ConnectButton
        function connectButtonPushed(app, event)
            if isempty(app.SerialDevice)
                app.connectReceiver();
            else
                app.disconnectReceiver();
            end
        end

        % Button pushed function: ApplyButton
        function applyButtonPushed(app, event)
            app.applyChannel();
        end

        % Button pushed function: RecordButton
        function recordButtonPushed(app, event)
            if ~isempty(app.RecordingWriter)
                app.stopRecording();
            elseif isempty(app.SerialDevice)
                app.RecordingStatusLabel.Text='先にCOMポートへ接続してください';
            else
                try
                    app.startRecording();
                catch err
                    app.RecordingStatusLabel.Text='記録開始失敗';
                    app.RecordingStatusLabel.Tooltip=err.message;
                    uialert(app.UIFigure,err.message,'記録開始失敗');
                end
            end
        end

        % Button pushed function: HeightApplyButton
        function heightApplyButtonPushed(app, event)
            app.sendHeightTuning();
        end

        % Button pushed function: HistoryRefreshButton
        function historyRefreshButtonPushed(app, event)
            imu.RecordingHistoryView.refresh(app);
        end

        % Button pushed function: HistoryAddButton
        function historyAddButtonPushed(app, event)
            imu.RecordingHistoryView.addFile(app);
        end

        % Value changed function: HistoryRangeDropDown
        function historyRangeChanged(app, event)
            imu.RecordingHistoryView.show(app);
        end

        % Value changed function: HistoryList
        function historySelectionChanged(app, event)
            imu.RecordingHistoryView.show(app);
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = StampFlyIMUApp(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end