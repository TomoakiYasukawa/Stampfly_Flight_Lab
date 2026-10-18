classdef DataLogger < matlab.apps.App

    % Used to locate and load the app's XML configuration file
    properties (Access = public, Constant)
        AppConfigFilename = './DataLogger.xml'; % File path to the app configuration file containing component layout and settings
    end

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        RootGrid                        matlab.ui.container.GridLayout
        MainTabs                        matlab.ui.container.TabGroup
        MonitorTab                      matlab.ui.container.Tab
        MainGrid                        matlab.ui.container.GridLayout
        MonitorDataLabel                matlab.ui.control.Label
        MotionGrid                      matlab.ui.container.GridLayout
        HorizontalLabel                 matlab.ui.control.Label
        MotionLabel                     matlab.ui.control.Label
        ToFAxes                         matlab.ui.control.UIAxes
        LatestLabel                     matlab.ui.control.Label
        PlotGrid                        matlab.ui.container.GridLayout
        MagAxes                         matlab.ui.control.UIAxes
        MotorAxes                       matlab.ui.control.UIAxes
        GyroAxes                        matlab.ui.control.UIAxes
        AccelAxes                       matlab.ui.control.UIAxes
        ConfigGrid                      matlab.ui.container.GridLayout
        JoystickHelpLabel               matlab.ui.control.Label
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
        ControlSettingsSourceLabel      matlab.ui.control.Label
        FlightStateDetailLabel          matlab.ui.control.Label
        ControlSettingsStatusLabel      matlab.ui.control.Label
        ControlApplyButton              matlab.ui.control.Button
        ControlLoadButton               matlab.ui.control.Button
        ControlOpenButton               matlab.ui.control.Button
        ControlPIDDropDown              matlab.ui.control.DropDown
        HorizontalControlTable          matlab.ui.control.Table
        HorizontalControlTitleLabel     matlab.ui.control.Label
        ControlPIDTable                 matlab.ui.control.Table
        ControlPIDTitleLabel            matlab.ui.control.Label
        FlightHelpLabel                 matlab.ui.control.Label
        FlightTitleLabel                matlab.ui.control.Label
        HistoryTab                      matlab.ui.container.Tab
        HistoryRootGrid                 matlab.ui.container.GridLayout
        HistoryMainGrid                 matlab.ui.container.GridLayout
        HistoryDiagnosticHelpLabel      matlab.ui.control.Label
        HistoryDataLabel                matlab.ui.control.Label
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
        HistoryFolderLabel              matlab.ui.control.Label
        HistoryOpenFolderButton         matlab.ui.control.Button
        HistoryFolderButton             matlab.ui.control.Button
        HistoryStatusLabel              matlab.ui.control.Label
        HistoryList                     matlab.ui.control.ListBox
        HistoryRangeDropDown            matlab.ui.control.DropDown
        HistoryDeleteButton             matlab.ui.control.Button
        HistoryRefreshButton            matlab.ui.control.Button
        HistoryTitleLabel               matlab.ui.control.Label
    end

    properties (Access = private)
        AccelData = []
        AccelLines = []
        Activity = []
        AppPool = []
        ByteBuffer = []
        CRCErrorCount = 0
        CloseRequested = false
        Closing = false
        CompletedRecordingFiles = []
        Connecting = false
        ControlSnapshot = []
        DispatchingHistory = false
        DispatchingWrites = false
        DisplayTimer = []
        DrainingClose = false
        DrawClock = []
        FlightRecorder = []
        ForeignFrameCount = 0
        FrameCount = 0
        GroundTracker = []
        GyroData = []
        GyroLines = []
        HeightData = []
        HeightLine = []
        HistoryInteractionsReady = false
        HistoryReadTask = struct('Fcn', [], 'CompleteFcn', [], 'ProgressFcn', [], 'Future', [], 'Queue', [], 'Running', false, 'StopRequested', false, 'Generation', 0)
        HistoryRequest = 0
        HorizontalClock = []
        HorizontalSample = []
        InFlightJobs = {}
        Initializing = true
        LastFlightState = uint8(0)
        LastLedCommandClock = []
        LastReceivedClock = []
        LatestHeight = NaN
        LatestPosition = [NaN NaN NaN]
        LatestSample = []
        MagData = []
        MagLines = []
        MissingCount = 0
        ModelOperationActive = false
        MonitorSourceText = []
        MotorData = []
        MotorLines = []
        ParallelHasStarted = false
        ParallelRetryClock = []
        ParallelStarting = false
        ParsingBuffer = []
        ParsingOffset = 1
        PathEndLine = []
        PathLine = []
        PathStartLine = []
        PendingHistoryRender = []
        PendingHistoryRequest = []
        PendingRecordingFiles = []
        PlotDirty = false
        PlotTimeline = []
        PlotWindowSeconds = 10
        PoseView = []
        PrevSequence = []
        ProcessingBytes = false
        ReceivingBusy = false
        RecentTimes = []
        RecordStartCRCCount = []
        RecordStartMissingCount = []
        RecordingActive = []
        RecordingCleanupListener = []
        RecordingTimer = []
        RecordingViewState = ""
        RecordingWriteTask = struct('Fcn', [], 'CompleteFcn', [], 'ProgressFcn', [], 'Future', [], 'Queue', [], 'Running', false, 'StopRequested', false, 'Generation', 0)
        RecordingWriter = []
        RenderingHistory = false
        SerialDevice = []
        SerialTimer = []
        StartClock = []
        TimeAxes = []
        TimeData = []
        ToFData = []
        ToFLine = []
        UpdatingDisplay = false
        UseParallel = false
        WriteError = ""
        WriteQueue = {}
        XYData = []
    end

    properties (Access = public)
        AutoRecordingEnabled = true
        ExpectedBuildID = 1401
        HistoryCache = []
        ParallelEnabled = true
        PathAxes = []
        RecordingFolder = []
    end

    methods (Access = private)

        function abortClose(app,message)
        if ~isvalid(app),return;end
        app.Closing=false;app.CloseRequested=false;app.DrainingClose=false;
        app.Activity.finish('Closing');app.syncRecordingView();
        for taskTimer={app.SerialTimer,app.DisplayTimer}
            if ~isempty(taskTimer{1}) && isvalid(taskTimer{1}) && strcmp(taskTimer{1}.Running,'off'),start(taskTimer{1});end
        end
        if strlength(string(message))>0
            app.StatusLabel.Text='保存を再試行してから終了してください';
            uialert(app.UIFigure,char(message),'記録を保存できません');
        end
        end

        function adjustMonitorLimits(~,ax,values,minSpan)
            values=values(isfinite(values));if isempty(values),return;end
            low=min(values);high=max(values);padding=max(minSpan,.1*(high-low));
            bounds=[low-padding high+padding];current=ax.YLim;
            % Expand before data touches the edge; keep the padding as hysteresis
            % instead of following every tiny change of a sample extremum.
            if low<current(1)+.2*padding || high>current(2)-.2*padding || diff(current)>3*diff(bounds)
                ax.YLim=bounds;
            end
        end

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

        function applyControlSettings(app)
            if isempty(app.ControlSnapshot) || ~app.beginModelOperation('制御パラメータをモデルへ反映中...'),return;end
            cleanup=onCleanup(@()app.endModelOperation()); %#ok<NASGU>
            try
                settings=imu.ControlSettings.apply(app.ControlSnapshot, ...
                    app.ControlPIDTable.Data,cell2mat(app.HorizontalControlTable.Data(:,2)));
                if app.Closing || ~isgraphics(app.UIFigure),return;end
                app.ControlSnapshot=settings;app.ControlPIDTable.Data=settings.PIDValues;
                app.HorizontalControlTable.Data=[settings.HorizontalLabels(:),num2cell(settings.HorizontalValues)];
                if settings.ChangedParameterCount==0
                    app.ControlSettingsStatusLabel.Text='変更した係数はありません。';
                else
                    app.ControlSettingsStatusLabel.Text=sprintf('%d項目をモデルに反映しました（未保存）。現行係数は保存→再ビルド→書き込みで機体へ反映します。',settings.ChangedParameterCount);
                end
            catch err
                if ~app.Closing,app.ControlSettingsStatusLabel.Text=['反映できません: ' err.message];end
            end
        end

        function started=beginModelOperation(app,message)
            started=false;
            if app.ModelOperationActive || app.ParallelStarting || app.Closing || app.Initializing || isdeployed,return;end
            app.ModelOperationActive=true;
            app.ControlLoadButton.Enable='off';app.ControlApplyButton.Enable='off';app.ControlOpenButton.Enable='off';
            app.Activity.start('Model',message);drawnow limitrate nocallbacks;
            started=true;
        end

        function captureExtension(app,sample,frame)
            app.captureRecording(sample,frame);
        end

        function captureFrame(app,sample,frame)
            app.captureRecording(sample,frame);
        end

        function captureRecording(app,sample,frame)
        if isempty(app.FlightRecorder) || app.FlightRecorder.Folder~=string(app.RecordingFolder) ...
                || app.FlightRecorder.Enabled~=logical(app.AutoRecordingEnabled) ...
                || app.FlightRecorder.Config.ExpectedBuildID~=app.ExpectedBuildID
            app.ensureFlightRecorder();
        end
        app.FlightRecorder.accept(sample,frame,toc(app.StartClock),app.MissingCount,app.CRCErrorCount);
        end

        function cleanupFlightRecording(app)
            timers={app.RecordingTimer,app.SerialTimer,app.DisplayTimer};
            for k=1:numel(timers)
                if ~isempty(timers{k}) && isvalid(timers{k}),stop(timers{k});delete(timers{k});end
            end
            app.RecordingTimer=[];app.SerialTimer=[];app.DisplayTimer=[];
            if ~isempty(app.SerialDevice)
                try,configureCallback(app.SerialDevice,'off');delete(app.SerialDevice);catch,end
                app.SerialDevice=[];
            end
            if ~isempty(app.FlightRecorder) && ~isempty(app.FlightRecorder.Writer)
                app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'app_closed');
            end
            app.drainRecordingWrites();
            if ~isempty(app.Activity),delete(app.Activity);end
        end

        function connectReceiver(app)
            if app.Connecting || app.Closing,return;end
            app.Connecting=true;
            connectionCleanup=onCleanup(@()app.endConnection());
            app.disconnectReceiver();
            app.Activity.start('Connect','USB/受信機に接続中...');
            drawnow;
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
                % The scheduled receive pump drains all available bytes. A second
                % byte callback would queue more UI events during slow rendering.
                configureCallback(device,'off');
                write(device, uint8([double('PING') 10]), 'uint8');
                app.StatusLabel.Text = '接続中: ' + port;
            catch err
                app.StatusLabel.Text = '接続失敗: ' + string(err.message);
                app.SerialDevice = [];
                app.ConnectButton.Text = '接続';
            end
        end

        function createMonitorLegend(~,ax,names)
            legend(ax,names,'Location','northwest','AutoUpdate','off', ...
                'FontSize',10,'Interpreter','none');
        end

        function disconnectReceiver(app)
            if ~isempty(app.SerialDevice)
                device=app.SerialDevice;
                try,configureCallback(device,'off');catch,end
                try
                    count=device.NumBytesAvailable;
                    if count>0,bytes=uint8(read(device,count,'uint8'));app.ByteBuffer=[app.ByteBuffer;bytes(:)];end
                catch
                end
                app.SerialDevice=[];
                try,delete(device);catch,end
                if ~app.ModelOperationActive,app.processBytes(zeros(0,1,'uint8'));end
            end
            if ~isempty(app.FlightRecorder) && ~isempty(app.FlightRecorder.Writer)
                app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'disconnected');
            end
            if ~isempty(app.FlightRecorder),app.FlightRecorder.resetConnection();end
            app.ConnectButton.Text='接続';app.StatusLabel.Text='未接続';
            app.syncRecordingView();app.dispatchRecordingWrites();
        end

        function dispatchHistoryRead(app)
        if isempty(app.PendingHistoryRequest) || app.HistoryReadTask.Running || app.Closing ...
                || app.ParallelStarting || app.DispatchingHistory,return;end
        app.DispatchingHistory=true;
        cleanup=onCleanup(@()app.releaseBackgroundDispatch('History')); %#ok<NASGU>
        parallelReady=app.ensureParallelReady();
        if ~isvalid(app) || app.Closing || app.CloseRequested || isempty(app.PendingHistoryRequest),return;end
        request=app.PendingHistoryRequest;app.PendingHistoryRequest=[];
        try
            if parallelReady
                app.startBackground('HistoryReadTask',request);
            else
                app.Activity.start('History','履歴データを読み込み中...');
                drawnow limitrate nocallbacks;
                result=DataLogger.readHistoryFiles(request);
                app.historyReadCompleted(result,[],false);
            end
        catch err
            app.historyReadCompleted([],err,false);
        end
        end

        function dispatchRecordingWrites(app)
        if app.RecordingWriteTask.Running || strlength(app.WriteError)>0 || isempty(app.WriteQueue) ...
                || app.ParallelStarting || app.DispatchingWrites,return;end
        app.DispatchingWrites=true;
        cleanup=onCleanup(@()app.releaseBackgroundDispatch('Writes')); %#ok<NASGU>
        parallelReady=app.ensureParallelReady();
        if ~isvalid(app) || isempty(app.WriteQueue),return;end
        app.InFlightJobs=app.WriteQueue;app.WriteQueue=cell(0,1);
        app.Activity.start('Save','データ保存中...',false);
        try
            if parallelReady
                app.startBackground('RecordingWriteTask',app.InFlightJobs);
            else
                app.Activity.start('Save','データ保存中...');
                drawnow limitrate nocallbacks;
                result=imu.MatRecordingWriter.writeJobs(app.InFlightJobs);
                app.recordingWriteCompleted(result,[],false);
            end
        catch err
            app.recordingWriteCompleted([],err,false);
        end
        end

        function drainRecordingWrites(app)
            if app.RecordingWriteTask.Running && ~isempty(app.RecordingWriteTask.Future)
                wait(app.RecordingWriteTask.Future);
            end
            jobs=[app.InFlightJobs;app.WriteQueue];
            if ~isempty(jobs)
                result=imu.MatRecordingWriter.writeJobs(jobs);
                app.CompletedRecordingFiles=unique([app.CompletedRecordingFiles;result.CompletedFiles],'stable');
            end
            app.InFlightJobs=cell(0,1);app.WriteQueue=cell(0,1);
            app.PendingRecordingFiles=strings(0,1);app.WriteError="";
        end

        function endConnection(app)
        if ~isvalid(app),return;end
        app.Connecting=false;app.Activity.finish('Connect');
        if app.CloseRequested,app.closeApp([]);end
        end

        function endHistoryRender(app)
        if ~isvalid(app),return;end
        app.RenderingHistory=false;
        app.Activity.finish('HistoryRender');
        if app.CloseRequested,app.closeApp([]);end
        end

        function endLiveDisplay(app)
            if ~isvalid(app),return;end
            app.UpdatingDisplay=false;
            if app.CloseRequested,app.closeApp([]);end
        end

        function endModelOperation(app)
        if ~isvalid(app),return;end
        app.ModelOperationActive=false;app.Activity.finish('Model');
        if ~isgraphics(app.UIFigure),return;end
        app.ControlLoadButton.Enable='on';
        ready=~isempty(app.ControlSnapshot);
        app.ControlApplyButton.Enable=ready;app.ControlOpenButton.Enable=ready;
        if app.CloseRequested,app.closeApp([]);elseif app.Closing,app.finishClose();end
        end

        function endParallelStart(app)
        if ~isvalid(app),return;end
        app.ParallelStarting=false;
        app.Activity.finish('Parallel');
        if app.CloseRequested && ~app.Initializing && ~app.DispatchingHistory && ~app.DispatchingWrites
            app.closeApp([]);
        end
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
            app.FlightRecorder.WriteBatchFcn=@(job)app.queueRecordingJob(job);
        end

        function ready=ensureParallelReady(app)
        ready=false;
        if ~app.ParallelEnabled || app.ParallelStarting,return;end
        if ~isdeployed && ~license('test','Distrib_Computing_Toolbox')
            app.UseParallel=false;app.AppPool=[];return
        end
        try
            pool=gcp('nocreate');
            if ~isempty(pool) && isvalid(pool)
                if isa(pool,'parallel.ThreadPool')
                    app.UseParallel=false;app.AppPool=[];
                    app.StatusLabel.Tooltip='MAT記録にはプロセス型の並列プールが必要です。同期処理を使用します。';
                    return
                end
                app.AppPool=pool;app.UseParallel=true;app.ParallelHasStarted=true;
                ready=true;return
            end
        catch err
            app.UseParallel=false;app.AppPool=[];
            app.StatusLabel.Tooltip=['並列処理を使用できないため同期処理を使用します: ' err.message];
            return
        end
        app.UseParallel=false;app.AppPool=[];
        if ~isempty(app.ParallelRetryClock) && toc(app.ParallelRetryClock)<60,return;end
        app.ParallelStarting=true;
        cleanup=onCleanup(@()app.endParallelStart()); %#ok<NASGU>
        if app.ParallelHasStarted
            message='並列プールを再起動中... 完了までお待ちください。';
        else
            message='並列処理を準備中（初回は時間がかかります）';
        end
        app.Activity.start('Parallel',message);
        drawnow limitrate nocallbacks;
        try
            pool=parpool('Processes',2);
            app.AppPool=pool;app.UseParallel=true;app.ParallelHasStarted=true;
            app.ParallelRetryClock=[];ready=true;
            app.StatusLabel.Tooltip=sprintf('保存・履歴読込: プロセス型並列プール %dワーカー',pool.NumWorkers);
        catch err
            app.ParallelRetryClock=tic;
            app.StatusLabel.Tooltip=['並列処理を開始できないため同期処理を使用します: ' err.message];
        end
        end

        function finishClose(app)
        if ~isvalid(app) || ~app.Closing || app.Initializing || app.Connecting || app.ParallelStarting || app.DispatchingHistory || app.DispatchingWrites || app.ModelOperationActive ...
                || app.UpdatingDisplay || app.RenderingHistory || app.ProcessingBytes || app.DrainingClose,return;end
        if ~isempty(app.FlightRecorder) && ~isempty(app.FlightRecorder.Writer)
            app.abortClose(app.FlightRecorder.ErrorMessage);return
        end
        app.dispatchRecordingWrites();
        if ~isvalid(app),return;end
        if strlength(app.WriteError)>0,app.abortClose(app.WriteError);return;end
        if app.RecordingWriteTask.Running || ~isempty(app.WriteQueue),return;end
        app.cleanupBackground();delete(app);
        end

        function finishHistoryRead(app)
        if ~isvalid(app),return;end
        if isempty(app.PendingHistoryRequest) && ~app.HistoryReadTask.Running
            app.Activity.finish('History');
        end
        if app.Closing,app.finishClose();else,app.dispatchHistoryRead();end
        end

        function name=flightStateName(~,state)
            display=imu.flightStatePresentation();
            index=find(display.Codes==double(state),1);
            if isempty(index),name=sprintf('不明 (Mode %d)',state);else,name=display.Names{index};end
        end

        function historyReadCompleted(app,result,error,wasCancelled)
        if ~isvalid(app) || ~isgraphics(app.UIFigure),return;end
        cleanup=onCleanup(@()app.finishHistoryRead()); %#ok<NASGU>
        if app.Closing || wasCancelled,return;end
        if ~isempty(error)
            app.HistoryStatusLabel.Text=['履歴読込に失敗: ' error.message];
        elseif ~isempty(result) && result.Request.Generation==app.HistoryRequest
            app.HistoryCache=result;
            app.renderHistory(result.Logs,result.Errors);
        end
        end

        function initializeFlightRecorder(app)
            app.ensureFlightRecorder();
            app.RecordingTimer=timer('Name','StampFlyFlightRecorder', ...
                'ExecutionMode','fixedSpacing','Period',.25,'BusyMode','drop', ...
                'TimerFcn',@(~,~)app.pollFlightRecording());
            app.SerialTimer=timer('Name','StampFlyTelemetryPump', ...
                'ExecutionMode','fixedSpacing','Period',.02,'BusyMode','drop', ...
                'TimerFcn',@(~,~)app.pollTelemetry());
            app.DisplayTimer=timer('Name','StampFlyLiveDisplay', ...
                'ExecutionMode','fixedSpacing','Period',.1,'BusyMode','drop', ...
                'TimerFcn',@(~,~)app.refreshLiveDisplay(false));
            app.RecordingCleanupListener=addlistener(app.UIFigure,'ObjectBeingDestroyed', ...
                @(~,~)app.cleanupFlightRecording());
            start(app.RecordingTimer);start(app.SerialTimer);start(app.DisplayTimer);
            app.syncRecordingView();
        end

        function initializeParallel(app)
        app.ensureParallelReady();
        end

        function initializePlots(app)
                    axesList=[app.AccelAxes app.GyroAxes app.MagAxes app.MotorAxes app.ToFAxes app.DroneAxes];
                    for ax=axesList
                        grid(ax,'on');ax.FontSize=10;
                        ax.Subtitle.Interpreter='none';ax.Subtitle.FontSize=8;
                        ax.Title.Interpreter='none';
                        ax.Interactions=[];disableDefaultInteractivity(ax);
                        ax.Toolbar=[];ax.YLimMode='manual';
                    end
                    hold(app.AccelAxes,'on');hold(app.GyroAxes,'on');hold(app.MagAxes,'on');
                    app.AccelLines=gobjects(1,3);app.GyroLines=gobjects(1,3);app.MagLines=gobjects(1,3);
                    for k=1:3
                        app.AccelLines(k)=plot(app.AccelAxes,nan,nan);
                        app.GyroLines(k)=plot(app.GyroAxes,nan,nan);
                        app.MagLines(k)=plot(app.MagAxes,nan,nan);
                    end
                    app.createMonitorLegend(app.AccelAxes,{'X','Y','Z'});
                    app.createMonitorLegend(app.GyroAxes,{'X','Y','Z'});
                    app.createMonitorLegend(app.MagAxes,{'X','Y','Z'});
                    title(app.AccelAxes,'加速度');ylabel(app.AccelAxes,'加速度 [m/s²]');
                    title(app.GyroAxes,'ジャイロ');ylabel(app.GyroAxes,'角速度 [rad/s]');
                    title(app.MagAxes,'磁気');ylabel(app.MagAxes,'磁場 [µT]');
                    hold(app.MotorAxes,'on');app.MotorLines=gobjects(1,4);
                    for k=1:4,app.MotorLines(k)=plot(app.MotorAxes,nan,nan);end
                    app.createMonitorLegend(app.MotorAxes,{'FR','FL','RR','RL'});
                    title(app.MotorAxes,'モータースロットル');ylabel(app.MotorAxes,'指令 [0–255]');
                    ylim(app.MotorAxes,[0 255]);
                    hold(app.ToFAxes,'on');
                    app.ToFLine=plot(app.ToFAxes,nan,nan,'Color',[.35 .35 .35]);
                    app.HeightLine=plot(app.ToFAxes,nan,nan,'Color',[0 .45 .74],'LineWidth',1.8);
                    app.ToFLine.DisplayName='斜距離';app.HeightLine.DisplayName='補正高さ';
                app.createMonitorLegend(app.ToFAxes,{'斜距離','補正高さ'});
                    title(app.ToFAxes,'ToF高さ（斜距離 / 傾き補正）');ylabel(app.ToFAxes,'高さ [m]');
                    for ax=axesList(1:end-1)
                        xlabel(ax,'時間 [s]');xlim(ax,[0 10]);
                    end
                    app.PathAxes=app.DroneAxes;
                    for ax=axesList,ax.Subtitle.String='';end
                    app.TimeAxes=imu.LiveTimeAxes(axesList(1:5),{app.AccelLines,app.GyroLines,app.MagLines,app.MotorLines,[app.ToFLine app.HeightLine]},app.PlotWindowSeconds);
        end

        function loadControlSettings(app)
            if ~app.beginModelOperation('モデルの制御パラメータを読み込み中...'),return;end
            cleanup=onCleanup(@()app.endModelOperation()); %#ok<NASGU>
            try
                settings=imu.ControlSettings.read();
                if app.Closing || ~isgraphics(app.UIFigure),return;end
                app.ControlSnapshot=settings;app.ControlPIDTable.Data=settings.PIDValues;
                app.HorizontalControlTable.Data=[settings.HorizontalLabels(:),num2cell(settings.HorizontalValues)];
                app.ControlSettingsStatusLabel.Text='モデルの現在値を読み込みました。受信は継続中です。機体からの係数読出しではありません。';
                app.ControlSettingsSourceLabel.Text=['読込元: ' settings.ModelFile];
                app.ControlSettingsSourceLabel.Tooltip=settings.ModelFile;
            catch err
                if ~app.Closing,app.ControlSettingsStatusLabel.Text=['設定を読み込めません: ' err.message];end
            end
        end

        function onSerialData(app)
            if app.Closing || app.ReceivingBusy || isempty(app.SerialDevice),return;end
            app.ReceivingBusy=true;
            cleanup=onCleanup(@()app.releaseReceive()); %#ok<NASGU>
            try
                count=min(app.SerialDevice.NumBytesAvailable,65536);
                if count>0
                    bytes=read(app.SerialDevice,count,'uint8');
                    app.ByteBuffer=[app.ByteBuffer;uint8(bytes(:))];
                end
            catch err
                if isvalid(app) && isgraphics(app.UIFigure)
                    app.StatusLabel.Text='受信エラー: '+string(err.message);
                end
            end
        end

        function pollFlightRecording(app)
        if ~isvalid(app) || ~isgraphics(app.UIFigure),return;end
        if ~app.ModelOperationActive && ~app.Closing && ~isempty(app.FlightRecorder) && isempty(app.ByteBuffer)
            app.FlightRecorder.poll(toc(app.StartClock),app.MissingCount,app.CRCErrorCount);
        end
        app.refreshBackgroundResults();
        if ~isvalid(app),return;end
        app.syncRecordingView();app.dispatchRecordingWrites();
        if ~isvalid(app),return;end
        if ~app.Closing && ~app.UpdatingDisplay && ~app.RenderingHistory && app.MainTabs.SelectedTab==app.HistoryTab && ~isempty(app.PendingHistoryRender),app.prepareHistoryTab();end
        if ~isvalid(app),return;end
        app.Activity.update();
        if app.Closing,app.finishClose();end
        end

        function pollTelemetry(app)
        if ~isvalid(app) || app.Closing,return;end
        app.onSerialData();
        if app.ModelOperationActive || app.ProcessingBytes || app.UpdatingDisplay,return;end
        if ~isempty(app.ByteBuffer)
            budget=.015;
            if numel(app.ByteBuffer)>=4040,budget=.035;end
            if numel(app.ByteBuffer)>=16160,budget=.05;end
            if numel(app.ByteBuffer)>=65536,budget=.08;end
            app.processBytes(zeros(0,1,'uint8'),budget);
        end
        end

        function prepareHistoryTab(app)
            if app.Closing || app.UpdatingDisplay || app.RenderingHistory || app.ModelOperationActive,return;end
            if ~app.HistoryInteractionsReady
                app.RenderingHistory=true;
                app.Activity.start('HistoryRender','履歴グラフの操作を準備中...');
                setupCleanup=onCleanup(@()app.endHistoryRender()); %#ok<NASGU>
                drawnow limitrate nocallbacks;
                axesList=[app.HistoryHeightAxes app.HistoryVerticalSpeedAxes app.HistoryHeightErrorAxes ...
                    app.HistoryVelocityErrorAxes app.HistoryControlAxes app.HistoryThrottleAxes ...
                    app.HistoryMotorAxes app.HistoryValidityAxes app.HistoryXYAxes app.HistoryStateAxes];
                for ax=axesList
                    ax.InteractionsMode='auto';enableDefaultInteractivity(ax);axtoolbar(ax,'default');
                end
                app.HistoryInteractionsReady=true;
                clear setupCleanup;
                if ~isvalid(app) || app.Closing,return;end
            end
            % Re-submit list and folder text after this tab's web view is active.
            imu.RecordingHistoryView.refresh(app);
            if ~isvalid(app) || app.Closing,return;end
            if ~isempty(app.PendingHistoryRender)
                data=app.PendingHistoryRender;
                app.renderHistory(data.Logs,data.Errors);
            end
        end

        function queueRecordingJob(app,job)
            app.WriteQueue{end+1,1}=job;
            app.PendingRecordingFiles=unique([app.PendingRecordingFiles;string(job.FilePath)],'stable');
            if isfield(job,'Info') && (job.Initialize || job.Info.Complete)
                app.Activity.start('Save','データ保存中...',false);
            end
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
            app.XYData(end+1,:) = positionENU(1:2);
            if any(~isfinite(sample.XYDisplacementM)),app.XYData(end,:)=NaN;end
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

        function recordingWriteCompleted(app,result,error,wasCancelled)
        if ~isvalid(app) || ~isgraphics(app.UIFigure),return;end
        if wasCancelled || ~isempty(error)
            if wasCancelled,app.WriteError="保存が中断されました";
            else,app.WriteError=string(error.message);end
            app.Activity.finish('Save');app.syncRecordingView();
            if app.Closing,app.abortClose(app.WriteError);end
            return
        end
        app.CompletedRecordingFiles=unique([app.CompletedRecordingFiles;result.CompletedFiles],'stable');
        app.InFlightJobs=cell(0,1);
        remaining=strings(numel(app.WriteQueue),1);
        for k=1:numel(app.WriteQueue),remaining(k)=string(app.WriteQueue{k}.FilePath);end
        app.PendingRecordingFiles=unique(remaining,'stable');
        if isempty(remaining),app.Activity.finish('Save');end
        app.dispatchRecordingWrites();
        if ~isvalid(app),return;end
        app.syncRecordingView();
        if app.Closing,app.finishClose();end
        end

        function refreshBackgroundResults(app)
            % Completion listeners normally deliver these results. Also check from
            % the lightweight recording timer so a busy UI cannot leave a finished
            % save or history request waiting for its listener callback.
            for taskName={'RecordingWriteTask','HistoryReadTask'}
                if ~isvalid(app),return;end
                task=app.(taskName{1});
                if task.Running && ~isempty(task.Future) && strcmp(task.Future.State,'finished')
                    app.handleBackgroundComplete(taskName{1},task.Future,task.Generation);
                end
            end
        end

        function refreshHorizontalStatus(app)
            % 水平制御専用の局所XYを表示し、従来の東・北の軌跡とは区別します。
            if isempty(app.HorizontalSample)
                app.setMonitorText(app.HorizontalLabel,'水平補助: 未受信');
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
            app.setMonitorText(app.HorizontalLabel,sprintf(['水平補助: %s / 有効 %d / 観測 %d%s\n' ...
                '速度 X %.2f / Y %.2f → 目標 %.2f / %.2f m/s'], ...
                stateText,h(17)~=0,h(21)~=0,suffix,h(3:6)));
            app.HorizontalLabel.Tooltip = sprintf(['局所X=基準機首、Y=右。東・北の表示軌跡とは別の座標です。\n' ...
                '位置 %.3f / %.3f m、保持目標 %.3f / %.3f m、混合率 %.2f\n' ...
                '棄却理由 %.0f（0正常、1区間不整合・低品質、2フロー停止、3姿勢、4ToF、5IMU・時間、6速度外れ値）'], ...
                h(1:2),h(7:8),h(15),h(24));
        end

        function refreshLiveDisplay(app,force)
            if ~isvalid(app) || app.Closing || app.ParallelStarting || app.ModelOperationActive ...
                    || app.RenderingHistory || ~isgraphics(app.UIFigure),return;end
            if ~app.PlotDirty || app.UpdatingDisplay,return;end
            if ~force
                if strcmp(app.UIFigure.Visible,'off') || app.MainTabs.SelectedTab~=app.MonitorTab,return;end
                if app.ProcessingBytes,return;end
                % Drain receive work before presenting another frame.
                app.pollTelemetry();
                if ~isvalid(app) || app.Closing,return;end
                backlog=numel(app.ByteBuffer);
                if ~isempty(app.SerialDevice),backlog=backlog+app.SerialDevice.NumBytesAvailable;end
                if backlog>=4040,return;end
            end
            app.UpdatingDisplay=true;
            displayCleanup=onCleanup(@()app.endLiveDisplay()); %#ok<NASGU>
            app.setMonitorText(app.ErrorLabel,sprintf('欠落: %d / CRC: %d / 対象外: %d', ...
                app.MissingCount,app.CRCErrorCount,app.ForeignFrameCount));
            if ~isempty(app.LatestSample)
                app.updateFlightLink(app.LatestSample);
                app.refreshMonitor(app.LatestSample,app.LatestPosition,app.LatestHeight);
                app.updatePlots(force);
            end
            app.refreshHorizontalStatus();
            app.DrawClock=tic;app.PlotDirty=false;
            drawnow limitrate nocallbacks;
        end

        function refreshMonitor(app,sample,positionENU,heightNow)
            app.setMonitorText(app.StatusLabel,'受信中');
            app.setMonitorText(app.RateLabel,sprintf('受信: %d Hz',numel(app.RecentTimes)));
            app.setMonitorText(app.FrameLabel,sprintf('フレーム: %d', app.FrameCount));
            app.setMonitorText(app.ErrorLabel,sprintf('欠落: %d / CRC: %d / 対象外: %d', ...
                app.MissingCount, app.CRCErrorCount,app.ForeignFrameCount));
            app.setMonitorText(app.LatestLabel,sprintf(['a [m/s²] = %.2f, %.2f, %.2f    ' ...
                'ω [rad/s] = %.3f, %.3f, %.3f    IMU有効: %d'], ...
                double(sample.Acceleration), double(sample.AngularVelocity), ...
                sample.IMUValid));
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
                    xyCaption = '表示EN';
                    app.MotionLabel.Tooltip = sprintf('補正Δ E %.4f / N %.4f m', ...
                        imu.flowDisplaySign(sample.BuildID)*double(sample.FlowCorrectedDeltaENM));
                else
                    xyCaption = '相対XY';
                    app.MotionLabel.Tooltip = '';
                end
                app.setMonitorText(app.MotionLabel,sprintf(['ToF: %s / 高さ: %s    ' ...
                    '%s: %.3f, %.3f m    生Flow: %.0f, %.0f count    ' ...
                    '採用: %d / Q: %d'], ...
                    heightText,correctedText,xyCaption,positionENU(1:2), ...
                    double(sample.FlowDelta),sample.FlowUsed, ...
                    sample.FlowQuality));
            else
                app.setMonitorText(app.MotionLabel,'SFI1受信中: ToF・Flowデータなし');
            end
            if sample.Version >= 3
                app.PoseView.update(sample.Orientation, ...
                    sample.OrientationValid,positionENU,imu.flowDisplaySign(sample.BuildID));
            else
                app.PoseView.update([1 0 0 0],false);
            end
            if sample.BatteryValid
                if sample.BatteryVoltageV <= 3.34
                    app.setMonitorText(app.BatteryLabel,sprintf('電池 %.2f V / 要充電',double(sample.BatteryVoltageV)));
                    app.BatteryLabel.FontColor = [0.8 0.12 0.12];
                else
                    app.setMonitorText(app.BatteryLabel,sprintf('電池 %.2f V',double(sample.BatteryVoltageV)));
                    app.BatteryLabel.FontColor = [0.15 0.15 0.15];
                end
            else
                app.setMonitorText(app.BatteryLabel,'電池: 未取得');
                app.BatteryLabel.FontColor = [0.4 0.4 0.4];
            end
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

        function releaseBackgroundDispatch(app,kind)
        if ~isvalid(app),return;end
        if strcmp(kind,'History'),app.DispatchingHistory=false;else,app.DispatchingWrites=false;end
        if app.CloseRequested
            app.closeApp([]);
        elseif app.Closing
            app.finishClose();
        elseif strcmp(kind,'History') && ~isempty(app.PendingHistoryRequest) && ~app.HistoryReadTask.Running
            app.dispatchHistoryRead();
        end
        end

        function releaseProcessing(app)
        if ~isvalid(app),return;end
        app.restoreProcessingBuffer();app.ProcessingBytes=false;
        if app.CloseRequested,app.closeApp([]);end
        end

        function releaseReceive(app)
            if isvalid(app),app.ReceivingBusy=false;end
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
                    app.LatestSample=[];app.PlotDirty=false;
                    app.RateLabel.Text = '受信: 0 Hz';
                    app.FrameLabel.Text = 'フレーム: 0';
                    app.ErrorLabel.Text = '欠落: 0 / CRC: 0 / 対象外: 0';
                    app.FrameLabel.Tooltip = sprintf('対象 BuildID: %.0f',double(app.ExpectedBuildID));
                    app.LatestLabel.Text = '最新値: 受信待機中';
                    app.MotionLabel.Text = 'ToF・Optical flow: データを待機中';
                    app.MonitorSourceText='';app.MonitorDataLabel.Text='表示データ: ライブ受信待ち';
                    if ~isempty(app.PoseView), app.PoseView.reset(); end
                    for line = [app.PathStartLine app.PathEndLine app.AccelLines app.GyroLines app.ToFLine app.HeightLine ...
                            app.MagLines app.MotorLines app.PathLine]
                        if isgraphics(line)
                            if any(line==[app.PathLine app.PathStartLine app.PathEndLine])
            set(line,'XData',nan,'YData',nan,'ZData',nan);
        else
            set(line,'XData',nan,'YData',nan);
        end
                        end
                    end
                    if ~isempty(app.TimeAxes),app.TimeAxes.reset();end
        end

        function restoreProcessingBuffer(app)
        if ~isempty(app.ParsingBuffer)
            app.ByteBuffer=[app.ParsingBuffer(app.ParsingOffset:end);app.ByteBuffer];
        end
        app.ParsingBuffer=zeros(0,1,'uint8');app.ParsingOffset=1;
        end

        function retryRecordingWrites(app)
            if app.RecordingWriteTask.Running,return;end
            app.WriteQueue=[app.InFlightJobs;app.WriteQueue];app.InFlightJobs=cell(0,1);
            app.WriteError="";app.Activity.start('Save','データ保存を再試行中...');
            app.dispatchRecordingWrites();
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

        function setMonitorText(~,label,text)
            if ~strcmp(label.Text,text),label.Text=text;end
        end

        function syncRecordingView(app)
            if isempty(app.FlightRecorder),return;end
            recorder=app.FlightRecorder;
            app.RecordingWriter=recorder.Writer;app.RecordingActive=recorder.Active;
            path=recorder.LastPath;
            if recorder.Active,path=recorder.Writer.FilePath;end
            viewState=string(recorder.Status)+newline+string(recorder.ErrorMessage)+newline+path ...
                +newline+string(recorder.Active)+string(recorder.Automatic) ...
                +string(app.RecordingWriteTask.Running)+string(~isempty(app.WriteQueue))+newline+app.WriteError;
            if isequal(app.RecordingViewState,viewState),return;end
            app.RecordingViewState=viewState;
            app.setMonitorText(app.RecordingStatusLabel,char(recorder.Status));
            if strlength(recorder.ErrorMessage)>0
                app.setMonitorText(app.RecordButton,'保存再試行');app.RecordButton.Enable='on';
                app.RecordingStatusLabel.Tooltip=char(recorder.ErrorMessage);
            elseif recorder.Active
                app.RecordingStatusLabel.Tooltip=char(recorder.Writer.FilePath);
                if recorder.Automatic
                    app.setMonitorText(app.RecordButton,'自動記録中');app.RecordButton.Enable='off';
                else
                    app.setMonitorText(app.RecordButton,'記録停止');app.RecordButton.Enable='on';
                end
            else
                app.setMonitorText(app.RecordButton,'手動記録開始');app.RecordButton.Enable='on';
                app.RecordingStatusLabel.Tooltip=char(recorder.LastPath);
            end
            if strlength(app.WriteError)>0
                app.setMonitorText(app.RecordButton,'保存再試行');app.RecordButton.Enable='on';
                app.setMonitorText(app.RecordingStatusLabel,'記録エラー: 保存再試行が必要です');
                app.RecordingStatusLabel.Tooltip=char(app.WriteError);
            elseif ~recorder.Active && (app.RecordingWriteTask.Running || ~isempty(app.WriteQueue))
                app.setMonitorText(app.RecordButton,'保存中');app.RecordButton.Enable='off';
                app.setMonitorText(app.RecordingStatusLabel,'データ保存中...');
            end
        end

        function updateFlightLink(app,sample)
            if sample.Version >= 6
                app.LastFlightState=sample.FlightState;
                name=app.flightStateName(sample.FlightState);
                app.setMonitorText(app.FlightStateLabel,'飛行状態: '+string(name));
                app.setMonitorText(app.FlightStateDetailLabel,sprintf('受信した機体状態: %s (Mode %d) / 操作: JoyStick',name,sample.FlightState));
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

        function updatePlots(app,force)
            if isempty(app.TimeData),return;end
            if nargin<2,force=true;end
            for k=1:3
                set(app.AccelLines(k),'XData',app.TimeData,'YData',app.AccelData(:,k));
                set(app.GyroLines(k),'XData',app.TimeData,'YData',app.GyroData(:,k));
                set(app.MagLines(k),'XData',app.TimeData,'YData',app.MagData(:,k));
            end
            for k=1:4
                set(app.MotorLines(k),'XData',app.TimeData,'YData',app.MotorData(:,k));
            end
            app.adjustMonitorLimits(app.AccelAxes,app.AccelData(:),.25);
            app.adjustMonitorLimits(app.GyroAxes,app.GyroData(:),.02);
            app.adjustMonitorLimits(app.MagAxes,app.MagData(:),1);
            right=max(app.PlotWindowSeconds,app.TimeData(end));
            axesList=[app.AccelAxes app.GyroAxes app.MagAxes app.MotorAxes app.ToFAxes];
            app.TimeAxes.update(right,force);
            set(app.ToFLine,'XData',app.TimeData,'YData',app.ToFData);
            set(app.HeightLine,'XData',app.TimeData,'YData',app.HeightData);
            tofValues=[app.ToFData;app.HeightData];tofValues=tofValues(isfinite(tofValues));
            if ~isempty(tofValues)
                low=min(tofValues);high=max(tofValues);padding=max(.025,.1*(high-low));
                bottom=max(0,low-padding);bounds=[bottom max(high+padding,bottom+.05)];
                current=app.ToFAxes.YLim;
                if low<current(1)+.2*padding || high>current(2)-.2*padding || diff(current)>3*diff(bounds)
                    app.ToFAxes.YLim=bounds;
                end
            end
            if ~isempty(app.PoseView),app.PoseView.updatePath(app.XYData,app.HeightData);end
            source=sprintf('表示データ: ライブ %s / CH %d / BuildID %d / 直近 %.0f秒', ...
                string(app.PortDropDown.Value),app.ChannelField.Value,app.ExpectedBuildID,app.PlotWindowSeconds);
            if ~strcmp(app.MonitorSourceText,source)
                app.MonitorSourceText=source;app.MonitorDataLabel.Text=source;
                for ax=[axesList app.DroneAxes]
                    ax.Subtitle.String='';ax.UserData=struct('Source',source);
                end
            end
        end

    end

    methods (Access = public)

        function state=backgroundStatus(app)
        parallelReady=app.UseParallel && app.ParallelEnabled && ~isempty(app.AppPool) && isvalid(app.AppPool);
        historyActivity=~isempty(app.Activity) && ...
            (app.Activity.isActive('History') || app.Activity.isActive('HistoryRender'));
        state=struct('Parallel',parallelReady,'Pool',class(app.AppPool), ...
            'Saving',app.RecordingWriteTask.Running || ~isempty(app.WriteQueue) || app.DispatchingWrites, ...
            'ReadingHistory',app.HistoryReadTask.Running || ~isempty(app.PendingHistoryRequest) || app.DispatchingHistory, ...
            'RenderingHistory',app.RenderingHistory,'HistoryActivity',historyActivity, ...
            'ParallelStarting',app.ParallelStarting, ...
            'QueuedBytes',numel(app.ByteBuffer),'Frames',app.FrameCount, ...
            'ModelOperation',app.ModelOperationActive,'Closing',app.Closing);
        end

        function invalidateHistoryRead(app)
        app.HistoryRequest=app.HistoryRequest+1;
        app.PendingHistoryRequest=[];app.PendingHistoryRender=[];
        if app.HistoryReadTask.Running,app.cancelBackground('HistoryReadTask');end
        app.Activity.finish('History');
        end

        function processBytes(app, bytes, workBudget)
            if nargin<3,workBudget=Inf;end
            if ~isvalid(app) || (app.Closing && ~app.DrainingClose),return;end
            app.ByteBuffer=[app.ByteBuffer;uint8(bytes(:))];
            if app.ProcessingBytes || app.ModelOperationActive,return;end
            app.ProcessingBytes=true;
            processingCleanup=onCleanup(@()app.releaseProcessing()); %#ok<NASGU>
            processClock=tic;
            if isempty(app.PlotTimeline)
                app.resetData(); % 開いたままコードを更新した場合も表示状態を初期化する。
            end
            app.ParsingBuffer=app.ByteBuffer;app.ByteBuffer=zeros(0,1,'uint8');
            buffer=app.ParsingBuffer;app.ParsingOffset=1;
            offset=1;
            latestSample = [];
            latestPosition = [NaN NaN NaN];
            latestHeight = NaN;
            while numel(buffer)-offset+1 >= 4 && toc(processClock)<workBudget && (~app.Closing || app.DrainingClose)
                first = buffer(offset:offset+3);
                frameBytes = imu.frameLength(first);
                if frameBytes == 0
                    marks = find(buffer(offset:end-3) == uint8('S') & ...
                        buffer(offset+1:end-2) == uint8('F') & ...
                        buffer(offset+2:end-1) == uint8('I') & ...
                        (buffer(offset+3:end) == uint8('1') | ...
                         buffer(offset+3:end) == uint8('2') | ...
                         buffer(offset+3:end) == uint8('3') | ...
                         buffer(offset+3:end) == uint8('4') | ...
                         buffer(offset+3:end) == uint8('5') | ...
                         buffer(offset+3:end) == uint8('6') | ...
                         buffer(offset+3:end) == uint8('7') | ...
                         buffer(offset+3:end) == uint8('8') | ...
                     buffer(offset+3:end) == uint8('X') | ...
                     buffer(offset+3:end) == uint8('Y') | ...
                         buffer(offset+3:end) == uint8('H')),1);
                    lf = find(buffer(offset:end) == 10,1);
                    if ~isempty(lf) && (isempty(marks) || lf < marks(1))
                        line = strtrim(string(char(buffer(offset:offset+lf-2).')));
                        if startsWith(line,'READY,') || startsWith(line,'PONG,')
                            app.StatusLabel.Text = '受信機: CH ' + extractAfter(line,',');
                        elseif startsWith(line,'OK,')
                            app.StatusLabel.Text = '設定完了: CH ' + extractAfter(line,',');
                        elseif startsWith(line,'ERR,')
                            app.StatusLabel.Text = '受信機エラー: ' + line;
                        end
                        offset=offset+lf;app.ParsingOffset=offset;
                    elseif ~isempty(marks)
                        offset=offset+marks(1)-1;app.ParsingOffset=offset;
                    else
                        if numel(buffer)-offset+1 > 256
                            offset=numel(buffer)-3;app.ParsingOffset=offset;
                        end
                        break
                    end
                    continue
                end
                if numel(buffer)-offset+1 < frameBytes, break; end
                candidate = buffer(offset:offset+frameBytes-1);
                try
                    if ismember(first(4),uint8('XYH'))
                        sample = imu.decodeExtensionFrame(candidate);
                    else
                        sample = imu.decodeFrame(candidate);
                    end
                catch
                    app.CRCErrorCount = app.CRCErrorCount + 1;app.PlotDirty=true;
                    offset=offset+1;app.ParsingOffset=offset;
                    app.ErrorLabel.Text = sprintf('欠落: %d / CRC: %d', ...
                        app.MissingCount,app.CRCErrorCount);
                    continue
                end
                offset=offset+frameBytes;app.ParsingOffset=offset;
                if isfield(sample,'Kind')
                    if app.ExpectedBuildID==0 || double(sample.BuildID)==double(app.ExpectedBuildID)
                        app.captureExtension(sample,candidate);
                        if sample.Kind==3
                            app.HorizontalSample=sample;app.HorizontalClock=tic;app.PlotDirty=true;
                        end
                    end
                    continue
                end
                % 同じチャンネルの別ビルドを時刻・欠落・記録へ混ぜない。
                if sample.Version >= 7 && app.ExpectedBuildID ~= 0 && ...
                        double(sample.BuildID) ~= double(app.ExpectedBuildID)
                    app.ForeignFrameCount = app.ForeignFrameCount + 1;app.PlotDirty=true;
                    continue
                end
                [accepted,positionENU,heightNow] = app.recordSample(sample);
                app.captureFrame(sample,candidate);
                if accepted
                    latestSample = sample;
                    latestPosition = positionENU;
                    latestHeight = heightNow;
                    app.LastReceivedClock = tic;
                end
            end
            if ~isempty(latestSample)
                app.LatestSample=latestSample;app.LatestPosition=latestPosition;
                app.LatestHeight=latestHeight;app.PlotDirty=true;
                app.updateLedHeartbeat();
            end
            if isinf(workBudget),app.syncRecordingView();end
            app.dispatchRecordingWrites();
            app.restoreProcessingBuffer();
            if isinf(workBudget),app.refreshLiveDisplay(true);end
        end

        function paths=recordingFilesBusy(app)
            paths=app.PendingRecordingFiles;
            if ~isempty(app.FlightRecorder) && ~isempty(app.FlightRecorder.Writer)
                paths(end+1,1)=app.FlightRecorder.Writer.FilePath;
            end
            paths=unique(paths,'stable');
        end

        function state=recordingStatus(app)
            app.ensureFlightRecorder();r=app.FlightRecorder;
            file="";if ~isempty(r.Writer),file=r.Writer.FilePath;end
            state=struct('Active',r.Active,'Automatic',r.Automatic,'CurrentFile',file, ...
                'LastFile',r.LastPath,'SavedFiles',r.SavedPaths,'Status',r.Status,'Error',r.ErrorMessage, ...
                'Saving',app.RecordingWriteTask.Running || ~isempty(app.WriteQueue), ...
                'PendingFiles',app.PendingRecordingFiles,'WriteError',app.WriteError);
        end

        function renderHistory(app,logs,errors)
            if app.Closing || ~isgraphics(app.UIFigure),return;end
            generation=app.HistoryRequest;
            app.PendingHistoryRender=struct('Logs',{logs},'Errors',errors,'Generation',generation);
            % Reading hidden history must not compete with the visible live graphs.
            if app.RenderingHistory || app.UpdatingDisplay || app.ModelOperationActive,return;end
            if strcmp(app.UIFigure.Visible,'on') && app.MainTabs.SelectedTab~=app.HistoryTab
                app.HistoryStatusLabel.Text='履歴データ準備完了（履歴タブで表示）';
                return;
            end
            app.RenderingHistory=true;
            app.Activity.start('HistoryRender','履歴グラフを表示中...',false);
            cleanup=onCleanup(@()app.endHistoryRender()); %#ok<NASGU>
            drawnow limitrate nocallbacks;
            imu.RecordingHistoryView.render(app,logs,errors);
            if ~isempty(app.PendingHistoryRender) && app.PendingHistoryRender.Generation==generation
                app.PendingHistoryRender=[];
            end
        end

        function setRecordingFolder(app,folder)
            % 保存中のファイルは移動せず、次の記録から新しい保存先を使います。
            validateattributes(folder,{'char','string'},{'scalartext'});
            folder=string(folder);
            assert(isfolder(folder),'imu:RecordingFolder','保存先フォルダーが見つかりません。');
            app.RecordingFolder=folder;
            app.ensureFlightRecorder();
            app.HistoryList.UserData=struct('ExtraPaths',strings(0,1));
            imu.RecordingHistoryView.refresh(app);
            if app.FlightRecorder.Active
                app.HistoryStatusLabel.Text='保存先を変更しました。現在の記録は旧保存先、次の記録から適用します。';
            end
        end

        function startHistoryRead(app,paths,mode)
        if app.Closing,return;end
        app.HistoryRequest=app.HistoryRequest+1;app.PendingHistoryRender=[];
        paths=string(paths(:));
        request=struct('Paths',paths,'Mode',string(mode),'ExpectedBuildID',double(app.ExpectedBuildID), ...
            'Signature',imu.RecordingHistoryView.fileSignature(paths),'Generation',app.HistoryRequest);
        app.PendingHistoryRequest=request;
        app.HistoryStatusLabel.Text='履歴データを読み込み中...';
        app.Activity.start('History','履歴データを読み込み中...');
        app.dispatchHistoryRead();
        end

        function path=startRecording(app,outputFolder)
            if nargin<2,outputFolder="";end
            app.ensureFlightRecorder();
            path=app.FlightRecorder.startManual(outputFolder,app.MissingCount,app.CRCErrorCount);
            app.syncRecordingView();app.dispatchRecordingWrites();
            if ~isempty(app.LastReceivedClock) && toc(app.LastReceivedClock)<1
                app.sendLedState(uint8(2));
            end
        end

        function path=stopRecording(app)
            path="";
            if isempty(app.FlightRecorder),return;end
            path=app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'manual_stop');
            app.syncRecordingView();app.dispatchRecordingWrites();
            if strlength(path)>0,fprintf('RECORDED_MAT=%s\n',path);end
            if ~isempty(app.LastReceivedClock) && toc(app.LastReceivedClock)<1
                app.sendLedState(uint8(1));
            else
                app.sendLedState(uint8(0));
            end
        end

        function complete=waitForHistoryRead(app,timeoutSeconds)
            if nargin<2,timeoutSeconds=30;end
            clock=tic;
            while isvalid(app) && toc(clock)<timeoutSeconds && ...
                    (app.HistoryReadTask.Running || ~isempty(app.PendingHistoryRequest) || app.RenderingHistory)
                app.refreshBackgroundResults();
                if ~isvalid(app),complete=false;return;end
                pause(.01);
            end
            if isvalid(app),app.refreshBackgroundResults();end
            complete=isvalid(app) && ~app.HistoryReadTask.Running ...
                && isempty(app.PendingHistoryRequest) && ~app.RenderingHistory;
        end

        function complete=waitForRecordingSave(app,timeoutSeconds)
            if nargin<2,timeoutSeconds=30;end
            clock=tic;app.refreshBackgroundResults();
            if ~isvalid(app),complete=false;return;end
            app.dispatchRecordingWrites();
            while isvalid(app) && toc(clock)<timeoutSeconds && ...
                    (app.RecordingWriteTask.Running || ~isempty(app.WriteQueue)) && strlength(app.WriteError)==0
                app.refreshBackgroundResults();
                if ~isvalid(app),complete=false;return;end
                pause(.01);
            end
            if isvalid(app),app.refreshBackgroundResults();end
            complete=isvalid(app) && ~app.RecordingWriteTask.Running && isempty(app.WriteQueue) && strlength(app.WriteError)==0;
        end

    end

    methods (Static)

        function result=readHistoryFiles(request)
            logs=cell(0,1);errors=strings(0,1);
            for k=1:numel(request.Paths)
                try
                    logs{end+1,1}=imu.readRecordingHistory(request.Paths(k),request.Mode,5000,request.ExpectedBuildID);
                catch err
                    errors(end+1,1)=string(err.message);
                end
            end
            result=struct('Request',request,'Logs',{logs},'Errors',errors);
        end

        function result=writeRecordingJobs(jobs)
            result=imu.MatRecordingWriter.writeJobs(jobs);
        end

    end

    % Background task execution
    methods (Access = private)

        function cancelBackground(app, taskName)
        % cancelBackground  Cancel a running background task (no-op if idle).
            task = app.(taskName);
            hadFuture = ~isempty(task.Future);
            task.StopRequested = true;
            task.Running = false;
            app.(taskName) = task;
            if hadFuture
                cancel(task.Future);
            end
        end

        function cleanupBackground(app)
        % cleanupBackground  Cancel all background tasks (called on app close).
            if ~isempty(app.RecordingWriteTask.Future); cancel(app.RecordingWriteTask.Future); end
            if ~isempty(app.HistoryReadTask.Future); cancel(app.HistoryReadTask.Future); end
        end

        function handleBackgroundComplete(app, taskName, future, generation)
        % handleBackgroundComplete  Routes results/errors to the task's CompleteFcn.
            if ~isvalid(app); return; end
            if strcmp(taskName,'HistoryReadTask') && (app.UpdatingDisplay || app.RenderingHistory || app.ProcessingBytes || app.ModelOperationActive),return;end
        task = app.(taskName);
            if generation ~= task.Generation || ~task.Running || isempty(task.Future); return; end
            task.Running = false;
            task.Future = [];
            task.Queue = [];
            app.(taskName) = task;
            wasCancelled = task.StopRequested || ...
                (~isempty(future.Error) && ...
                 strcmp(future.Error.identifier, "parallel:fevalqueue:ExecutionCancelled"));
            try
                if wasCancelled
                    task.CompleteFcn([], [], true);
                elseif ~isempty(future.Error)
                    task.CompleteFcn([], future.Error, false);
                else
                    nOut = max(0, nargout(task.Fcn));
                    if nOut == 0
                        task.CompleteFcn([], [], false);
                    elseif nOut == 1
                        task.CompleteFcn(fetchOutputs(future), [], false);
                    else
                        results = cell(1, nOut);
                        [results{:}] = fetchOutputs(future);
                        task.CompleteFcn(results, [], false);
                    end
                end
            catch cbErr
                fprintf(2, 'Error in CompleteFcn for task ''%s'': %s\n', taskName, cbErr.getReport());
                if isvalid(app)
                    uialert(app.UIFigure, cbErr.message, 'Background Task Error');
                end
            end
        end

        function safeProgress(app, taskName, msg, generation)
        % safeProgress  Wraps progress callbacks so errors appear in Command Window.
            if ~isvalid(app); return; end
            task = app.(taskName);
            if generation ~= task.Generation; return; end
            if msg.Type == "Progress"
                if ~task.Running; return; end
                if isempty(task.ProgressFcn); return; end
                try
                    task.ProgressFcn(msg.Data);
                catch bgErr
                    fprintf(2, 'Progress callback error (disabling): %s\n', bgErr.getReport());
                    task.ProgressFcn = [];
                    app.(taskName) = task;
                end
            else
                app.handleBackgroundComplete(taskName, task.Future, generation);
            end
        end

        function startBackground(app, taskName, varargin)
        % startBackground  Launch a background task. Pass task arguments after the name.
        %   app.startBackground('TaskName', arg1, arg2, ...)
            task = app.(taskName);
            if task.Running
                error('Background work is already running. Cancel it first.');
            end
            task.Running = true;
            task.StopRequested = false;
            task.Generation = task.Generation + 1;
            generation = task.Generation;
            nOut = max(0, nargout(task.Fcn));
            if ~isempty(task.ProgressFcn)
                task.Queue = parallel.pool.DataQueue;
                afterEach(task.Queue, @(d) app.safeProgress(taskName, d, generation));
                queue = task.Queue;
                sendProgress = @(data) send(queue, struct(Type="Progress", Data={data}));
                task.Future = parfeval(app.AppPool, task.Fcn, nOut, varargin{:}, sendProgress);
                afterAll(task.Future, @(~) send(queue, struct(Type="Finished")), 0, 'PassFuture', true);
            else
                task.Future = parfeval(app.AppPool, task.Fcn, nOut, varargin{:});
                afterAll(task.Future, @(f) app.handleBackgroundComplete(taskName, f, generation), 0, 'PassFuture', true);
            end
            app.(taskName) = task;
        end

    end

    % Callbacks that handle component events
    methods

        % Code that executes after component creation
        function startupFcn(app)
            app.Activity=imu.AppActivity(app.UIFigure);
            app.RecordingWriteTask.Fcn=@DataLogger.writeRecordingJobs;
            app.RecordingWriteTask.CompleteFcn=@app.recordingWriteCompleted;
            app.HistoryReadTask.Fcn=@DataLogger.readHistoryFiles;
            app.HistoryReadTask.CompleteFcn=@app.historyReadCompleted;
            if ~isdeployed
                run(fullfile(fileparts(which('DataLogger')),'config','startup.m'));
            end
            imu.fitAppWindow(app.UIFigure);
            app.SerialDevice = [];
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
            app.PathLine = [];
            app.PathStartLine=[];app.PathEndLine=[];
            app.BaudField.Value = 921600;
            app.ChannelField.Value = 3;
            app.resetData();
            app.refreshPorts();
            app.initializePlots();
            for historyAxis=[app.HistoryHeightAxes app.HistoryVerticalSpeedAxes app.HistoryHeightErrorAxes ...
                    app.HistoryVelocityErrorAxes app.HistoryControlAxes app.HistoryThrottleAxes ...
                    app.HistoryMotorAxes app.HistoryValidityAxes app.HistoryXYAxes app.HistoryStateAxes]
                historyAxis.Interactions=[];disableDefaultInteractivity(historyAxis);
                historyAxis.Toolbar=[];
            end
            app.PoseView = imu.StampFlyPoseView(app.DroneAxes);
            app.TitleLabel.Text = 'StampFly_Lab — DataLogger';
            app.UIFigure.Name = 'StampFly_Lab — DataLogger';
            app.RecordingFolder="";
            if isdeployed
                app.RecordingFolder=string(fullfile(getenv('LOCALAPPDATA'),'StampFly','recordings'));
            end
            app.ControlSnapshot=[];
            app.AutoRecordingEnabled=true;
            app.initializeParallel();
            app.PathLine=app.PoseView.GroundPath;app.PathStartLine=app.PoseView.PathStart;app.PathEndLine=app.PoseView.PathEnd;
            app.initializeFlightRecorder();
            app.HistoryList.UserData=struct('ExtraPaths',strings(0,1));
            imu.RecordingHistoryView.refresh(app);
            app.ControlPIDTable.ColumnEditable=true(1,4);
            app.HorizontalControlTable.ColumnEditable=[false true];
            if isdeployed
                app.ControlLoadButton.Enable='off';app.ControlApplyButton.Enable='off';app.ControlOpenButton.Enable='off';
                app.ControlSettingsStatusLabel.Text='モデルの編集はMATLABとSimulinkで行ってください。';
            end
            app.Initializing=false;
            if app.CloseRequested,app.closeApp([]);end
        end

        % Close request function: UIFigure
        function closeApp(app, event)
            if app.Closing,return;end
            if app.Initializing || app.Connecting || app.ParallelStarting || app.DispatchingHistory || app.DispatchingWrites || app.ModelOperationActive || app.UpdatingDisplay || app.ProcessingBytes || app.RenderingHistory
                app.CloseRequested=true;
                app.Activity.start('Closing','処理の完了を待って終了します...');
                return
            end
            app.CloseRequested=false;app.Closing=true;
            app.Activity.start('Closing','記録データを保存して終了中...');
            if ~isempty(app.SerialTimer) && isvalid(app.SerialTimer),stop(app.SerialTimer);end
            if ~isempty(app.DisplayTimer) && isvalid(app.DisplayTimer),stop(app.DisplayTimer);end
            if ~isempty(app.SerialDevice)
                try
                    configureCallback(app.SerialDevice,'off');
                    count=app.SerialDevice.NumBytesAvailable;
                    if count>0,bytes=uint8(read(app.SerialDevice,count,'uint8'));app.ByteBuffer=[app.ByteBuffer;bytes(:)];end
                    delete(app.SerialDevice);
                catch
                end
                app.SerialDevice=[];
            end
            app.DrainingClose=true;
            app.processBytes(zeros(0,1,'uint8'));
            app.DrainingClose=false;
            if ~isempty(app.FlightRecorder) && ~isempty(app.FlightRecorder.Writer)
                app.FlightRecorder.stop(app.MissingCount,app.CRCErrorCount,'app_closed');
            end
            app.syncRecordingView();app.finishClose();
            if ~isvalid(app) || app.Closing,return;end
        end

        % Selection changed function: MainTabs
        function mainTabChanged(app, event)
            if ~isvalid(app) || app.Closing || app.MainTabs.SelectedTab~=app.HistoryTab,return;end
            app.prepareHistoryTab();
        end

        % Button pushed function: RefreshButton
        function refreshButtonPushed(app, event)
            app.refreshPorts();
        end

        % Button pushed function: ConnectButton
        function connectButtonPushed(app, event)
            if app.Connecting || app.Closing || app.Initializing,return;end
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
            if strlength(app.WriteError)>0
                app.retryRecordingWrites();
            elseif ~isempty(app.RecordingWriter)
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

        % Button pushed function: ControlOpenButton
        function controlOpenButtonPushed(app, event)
            if isempty(app.ControlSnapshot),return;end
            row=double(app.ControlPIDDropDown.Value);
            open_system(app.ControlSnapshot.PIDPaths{row});
        end

        % Button pushed function: ControlLoadButton
        function controlLoadButtonPushed(app, event)
            app.loadControlSettings();
        end

        % Button pushed function: ControlApplyButton
        function controlApplyButtonPushed(app, event)
            app.applyControlSettings();
        end

        % Button pushed function: HistoryRefreshButton
        function historyRefreshButtonPushed(app, event)
            imu.RecordingHistoryView.refresh(app);
        end

        % Button pushed function: HistoryDeleteButton
        function historyDeleteButtonPushed(app, event)
            imu.RecordingHistoryView.deleteSelected(app);
        end

        % Value changed function: HistoryRangeDropDown
        function historyRangeChanged(app, event)
            imu.RecordingHistoryView.show(app);
        end

        % Value changed function: HistoryList
        function historySelectionChanged(app, event)
            imu.RecordingHistoryView.show(app);
        end

        % Button pushed function: HistoryFolderButton
        function historyFolderButtonPushed(app, event)
            folder=imu.recordingFolder(app);
            if ~isfolder(folder),folder=fileparts(which('DataLogger'));end
            chosen=uigetdir(folder,'StampFly記録の保存先フォルダーを指定');
            if isequal(chosen,0),return;end
            app.setRecordingFolder(string(chosen));
        end

        % Button pushed function: HistoryOpenFolderButton
        function historyOpenFolderButtonPushed(app, event)
            folder=imu.recordingFolder(app);
            if ~isfolder(folder),mkdir(folder);end
            winopen(char(folder));
        end
    end

    % App creation
    methods (Access = public)

        % Construct app
        function app = DataLogger(varargin)
            app = app@matlab.apps.App(varargin{:});

            if nargout == 0
                clear app
            end
        end
    end
end