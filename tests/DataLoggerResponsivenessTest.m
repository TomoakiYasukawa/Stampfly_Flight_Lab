classdef DataLoggerResponsivenessTest < matlab.unittest.TestCase
    % Regression checks for queues, deletion, floor projection and shutdown.
    properties
        App
        Folder
    end
    methods (TestMethodSetup)
        function createApp(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(root));
            addpath(fullfile(root,'config'),fullfile(root,'tests'));
            configure_stampfly_project();
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.Folder=string(fixture.Folder);
            testCase.App=DataLogger();testCase.App.UIFigure.Visible='off';
            testCase.App.AutoRecordingEnabled=false;
            testCase.App.setRecordingFolder(testCase.Folder);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
        end
    end
    methods (TestMethodTeardown)
        function closeApp(testCase)
            if isvalid(testCase.App),delete(testCase.App);end
        end
    end
    methods (Test)
        function visibleMonitorDefersHistoryAndTabShowsLatestFolder(testCase)
            testCase.App.ParallelEnabled=false;
            file=testCase.record(5);
            testCase.App.UIFigure.Visible='on';
            testCase.App.MainTabs.SelectedTab=testCase.App.MonitorTab;
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            testCase.verifyNotEmpty(testCase.App.HistoryCache);
            testCase.verifyEmpty(testCase.App.HistorySummaryTable.Data);
            state=testCase.App.backgroundStatus();
            testCase.verifyFalse(state.HistoryActivity);
            testCase.verifyFalse(state.RenderingHistory);
            testCase.verifyTrue(contains(testCase.App.HistoryStatusLabel.Text,'準備完了'));
            testCase.App.MainTabs.SelectedTab=testCase.App.HistoryTab;
            testCase.App.mainTabChanged([]);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            testCase.verifyNotEmpty(testCase.App.HistorySummaryTable.Data);
            testCase.verifyEqual(testCase.App.HistoryHeightAxes.UserData.SourceFiles,file);
            testCase.verifyTrue(contains(testCase.App.HistoryFolderLabel.Text,testCase.Folder));
            testCase.verifyTrue(isgraphics(testCase.App.HistoryHeightAxes.Toolbar));
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.MainTabs.SelectedTab=testCase.App.MonitorTab;
            testCase.App.setRecordingFolder(string(fixture.Folder));
            testCase.App.MainTabs.SelectedTab=testCase.App.HistoryTab;
            testCase.App.mainTabChanged([]);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            testCase.verifyEmpty(testCase.App.HistorySummaryTable.Data);
            testCase.verifyTrue(contains(testCase.App.HistoryStatusLabel.Text,'MAT記録がありません'));
            state=testCase.App.backgroundStatus();testCase.verifyFalse(state.HistoryActivity);
        end

        function returningToCachedFileCancelsDifferentPendingRead(testCase)
            testCase.requireParallel();
            first=testCase.record(5);second=testCase.record(6);
            imu.RecordingHistoryView.refresh(testCase.App,first);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            imu.RecordingHistoryView.refresh(testCase.App,second);
            imu.RecordingHistoryView.refresh(testCase.App,first);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            pause(.1);
            testCase.verifyEqual(string(testCase.App.HistoryList.Value),first);
            testCase.verifyEqual(testCase.App.HistoryCache.Request.Paths,first);
            testCase.verifyEqual(testCase.App.HistoryHeightAxes.UserData.SourceFiles,first);
            [~,name,ext]=fileparts(first);
            testCase.verifyTrue(contains(testCase.App.HistoryDataLabel.Text,string(name)+ext));
        end

        function completedSaveIsReconciledWhenListenerIsDelayed(testCase)
            testCase.requireParallel();
            timers=testCase.ownedTimers();stop(timers);
            [packets,~,~,~,~]=testCase.packets(121);
            file=testCase.App.startRecording();testCase.App.processBytes(packets(:));
            testCase.App.stopRecording();
            % Wait for the worker without flushing its UI completion listener.
            % The public save wait must reconcile the finished future itself.
            warningState=warning('off','MATLAB:structOnObject');
            cleanup=onCleanup(@()warning(warningState)); %#ok<NASGU>
            state=struct(testCase.App);
            if ~isempty(state.RecordingWriteTask.Future),wait(state.RecordingWriteTask.Future);end
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            saved=load(file,'telemetry','info');
            testCase.verifySize(saved.telemetry,[121 80]);
            testCase.verifyTrue(saved.info.Complete);
            testCase.verifyEmpty(testCase.App.recordingFilesBusy());
            drawnow;
            state=testCase.App.backgroundStatus();
            testCase.verifyFalse(state.Saving);
        end
        function backgroundSaveKeepsEveryRawPacket(testCase)
            testCase.requireParallel();
            [packets,base,extensions,rawExtensions,lengths]=testCase.packets(601);
            file=testCase.App.startRecording();
            testCase.App.processBytes(packets(:),.015);
            testCase.App.processBytes(zeros(0,1,'uint8'));
            testCase.App.stopRecording();
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            saved=load(file,'telemetry','rawFrames','extensionTelemetry','extensionFrames', ...
                'extensionFrameLength','info');
            testCase.verifySize(saved.telemetry,[601 80]);
            testCase.verifyEqual(saved.rawFrames,base');
            testCase.verifyEqual(saved.extensionTelemetry,extensions,'AbsTol',0);
            testCase.verifyEqual(saved.extensionFrames,rawExtensions);
            testCase.verifyEqual(saved.extensionFrameLength,lengths);
            testCase.verifyTrue(saved.info.Complete);
            testCase.verifyEqual(saved.info.ExtensionFrames,1803);
            testCase.verifyEmpty(testCase.App.recordingFilesBusy());
        end

        function deleteAffectsSelectedFilesOnly(testCase)
            testCase.App.ParallelEnabled=false;
            selected=testCase.record(4);
            keep=testCase.record(5);
            second=testCase.record(6);
            imu.RecordingHistoryView.refresh(testCase.App);
            testCase.App.HistoryList.Value=cellstr([selected;second]);
            deleted=imu.RecordingHistoryView.deleteSelected(testCase.App);
            testCase.verifyEqual(sort(deleted),sort([selected;second]));
            testCase.verifyFalse(isfile(selected));testCase.verifyFalse(isfile(second));
            testCase.verifyTrue(isfile(keep));
            testCase.verifyEqual(string(testCase.App.HistoryList.ItemsData),keep);
        end

        function deletingMiddleContinuesWithOlderFiles(testCase)
            testCase.App.ParallelEnabled=false;
            for k=1:4,testCase.record(3+k);end
            imu.RecordingHistoryView.refresh(testCase.App);
            order=string(testCase.App.HistoryList.ItemsData);order=order(:);
            testCase.App.HistoryList.Value=cellstr(order(2));
            imu.RecordingHistoryView.deleteSelected(testCase.App);
            testCase.verifyEqual(string(testCase.App.HistoryList.Value),order(3));
            testCase.verifyTrue(contains(testCase.App.HistoryDataLabel.Text,string(testCase.App.HistoryList.Items{2})));
            imu.RecordingHistoryView.deleteSelected(testCase.App);
            testCase.verifyEqual(string(testCase.App.HistoryList.Value),order(4));
            imu.RecordingHistoryView.deleteSelected(testCase.App);
            testCase.verifyEqual(string(testCase.App.HistoryList.Value),order(1));
            imu.RecordingHistoryView.deleteSelected(testCase.App);
            state=testCase.App.backgroundStatus();
            testCase.verifyEqual(string(testCase.App.HistoryList.Enable),"off");
            testCase.verifyFalse(state.HistoryActivity);
            testCase.verifyFalse(state.RenderingHistory);
        end

        function emptyFolderFinishesActivityAndStillAcceptsRefresh(testCase)
            testCase.App.ParallelEnabled=false;
            testCase.record(4);
            imu.RecordingHistoryView.refresh(testCase.App);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.setRecordingFolder(string(fixture.Folder));
            testCase.App.historyRefreshButtonPushed([]);
            testCase.assertTrue(testCase.App.waitForHistoryRead(2));
            state=testCase.App.backgroundStatus();
            testCase.verifyFalse(state.HistoryActivity);
            testCase.verifyFalse(state.RenderingHistory);
            testCase.verifyFalse(state.ReadingHistory);
            testCase.verifyEmpty(testCase.App.HistorySummaryTable.Data);
            testCase.verifyTrue(contains(testCase.App.HistoryStatusLabel.Text,'MAT記録がありません'));
            testCase.App.closeApp([]);
            testCase.verifyFalse(isvalid(testCase.App));
        end

        function invalidMatFinishesActivityAndCanReturnToGoodFile(testCase)
            testCase.App.ParallelEnabled=false;
            file=testCase.record(4);
            unrelated=42;invalid=fullfile(testCase.Folder,'unrelated.mat'); %#ok<NASGU>
            save(invalid,'unrelated');
            imu.RecordingHistoryView.refresh(testCase.App,invalid);
            state=testCase.App.backgroundStatus();
            testCase.verifyFalse(state.HistoryActivity);
            testCase.verifyFalse(state.RenderingHistory);
            testCase.verifyTrue(contains(testCase.App.HistoryStatusLabel.Text,'読めません'));
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.verifyNotEmpty(testCase.App.HistorySummaryTable.Data);
        end

        function emptyFolderCancelsOldReadWithoutRestoringOldGraph(testCase)
            testCase.requireParallel();
            file=testCase.record(101);
            imu.RecordingHistoryView.refresh(testCase.App,file);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.setRecordingFolder(string(fixture.Folder));
            drawnow;pause(.1);
            testCase.assertTrue(testCase.App.waitForHistoryRead(2));
            state=testCase.App.backgroundStatus();
            testCase.verifyFalse(state.HistoryActivity);
            testCase.verifyEmpty(testCase.App.HistorySummaryTable.Data);
            testCase.verifyEqual(string(testCase.App.HistoryList.Enable),"off");
        end

        function poolRestartsForHistoryAndSaveAfterItHasClosed(testCase)
            testCase.requireParallel();
            file=testCase.record(5);
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            pool=gcp('nocreate');delete(pool);
            state=testCase.App.backgroundStatus();testCase.verifyFalse(state.Parallel);
            testCase.App.HistoryCache=[];
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.assertTrue(testCase.App.waitForHistoryRead(60));
            state=testCase.App.backgroundStatus();testCase.verifyTrue(state.Parallel);
            testCase.verifyNotEmpty(testCase.App.HistorySummaryTable.Data);
            pool=gcp('nocreate');delete(pool);
            next=testCase.record(6);
            saved=load(next,'info','telemetry');
            testCase.verifyTrue(saved.info.Complete);
            testCase.verifySize(saved.telemetry,[6 80]);
            state=testCase.App.backgroundStatus();testCase.verifyTrue(state.Parallel);
            testCase.verifyFalse(state.ParallelStarting);
        end

        function activeRecordingCannotBeDeleted(testCase)
            testCase.App.ParallelEnabled=false;
            [packets,~,~,~,~]=testCase.packets(4);
            file=testCase.App.startRecording();testCase.App.processBytes(packets(:));
            imu.RecordingHistoryView.refresh(testCase.App,file);
            deleted=imu.RecordingHistoryView.deleteSelected(testCase.App);
            testCase.verifyEmpty(deleted);testCase.verifyTrue(isfile(file));
            testCase.verifyTrue(contains(testCase.App.HistoryStatusLabel.Tooltip,'保存中'));
            testCase.App.stopRecording();
        end

        function pendingSaveIsProtectedAndRefreshRemainsCallable(testCase)
            testCase.requireParallel();
            [packets,~,~,~,~]=testCase.packets(101);
            file=testCase.App.startRecording();
            testCase.App.processBytes(packets(:));testCase.App.stopRecording();
            busy=testCase.App.recordingFilesBusy();
            testCase.verifyTrue(ismember(file,busy));
            testCase.App.HistoryList.Items={char(file)};
            testCase.App.HistoryList.ItemsData={char(file)};
            testCase.App.HistoryList.Value={char(file)};testCase.App.HistoryList.Enable='on';
            deleted=imu.RecordingHistoryView.deleteSelected(testCase.App);
            testCase.verifyEmpty(deleted);
            testCase.App.historyRefreshButtonPushed([]);
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            testCase.App.historyRefreshButtonPushed([]);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            testCase.verifyTrue(isfile(file));
            testCase.verifyNumElements(testCase.App.HistorySummaryTable.Data(:,1),1);
        end

        function closeWaitsForSaveAndRemovesAllTimers(testCase)
            testCase.requireParallel();
            [packets,~,~,~,~]=testCase.packets(101);
            file=testCase.App.startRecording();testCase.App.processBytes(packets(:));
            timers=testCase.ownedTimers();
            testCase.assertNumElements(timers,3);
            testCase.App.closeApp([]);
            testCase.waitForClose();
            testCase.verifyFalse(isvalid(testCase.App));
            testCase.verifyFalse(any(isvalid(timers)));
            saved=load(file,'telemetry','info');
            testCase.verifySize(saved.telemetry,[101 80]);
            testCase.verifyTrue(saved.info.Complete);
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'app_closed');
        end

        function cacheReloadsWhenFileContentsChange(testCase)
            testCase.App.ParallelEnabled=false;
            file=testCase.record(4);
            imu.RecordingHistoryView.refresh(testCase.App,file);
            before=testCase.App.HistoryCache;
            saved=load(file,'telemetry');telemetry=[saved.telemetry;saved.telemetry(end,:)];
            telemetry(end,2:3)=telemetry(end,2:3)+[1 .02];
            save(file,'telemetry','-append');
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.verifyNotEqual(before.Request.Signature,testCase.App.HistoryCache.Request.Signature);
            testCase.verifyGreaterThan(testCase.App.HistoryCache.Logs{1}.DeviceTimeSeconds(end), ...
                before.Logs{1}.DeviceTimeSeconds(end));
        end

        function monitorUsesFourColumnsAndFloorProjection(testCase)
            testCase.App.ParallelEnabled=false;
            [packets,~,~,~,~]=testCase.packets(4);
            testCase.App.processBytes(packets(:));
            path=findall(testCase.App.DroneAxes,'Tag','GroundXYPath');
            last=findall(testCase.App.DroneAxes,'Tag','XYEnd');
            testCase.verifyEqual([testCase.App.AccelAxes.Layout.Column ...
                testCase.App.GyroAxes.Layout.Column testCase.App.MagAxes.Layout.Column ...
                testCase.App.MotorAxes.Layout.Column],1:4);
            testCase.verifyEqual(testCase.App.DroneAxes.Layout.Row,5);
            testCase.verifyEqual(testCase.App.MotionGrid.Layout.Column,1);
            testCase.verifyEqual(path.XData(end),-.03,'AbsTol',1e-6);
            testCase.verifyEqual(path.YData(end),.015,'AbsTol',1e-6);
            testCase.verifyEqual(path.ZData,.001*ones(size(path.ZData)),'AbsTol',1e-12);
            testCase.verifyEqual([last.XData last.YData],[-.03 .015],'AbsTol',1e-6);
            testCase.verifyFalse(isprop(testCase.App,'HistoryAddButton'));
        end

        function physicalDirectionsMatchMonitorAndHistoryAndRawData(testCase)
            testCase.App.ParallelEnabled=false;
            [raw,estimate,control,extra]=logging_fixture();
            control.Mode=uint8(3);raw.BottomMm=int16(350);
            estimate.Angles=single([0;0;-pi]);
            % Hand-checked source axes: forward=-N, right=-E.
            source=[0 0;0 -.02;0 .02;-.02 0;.02 0];
            file=testCase.App.startRecording();
            packer=basic.ExtendedLogger50;testCase.addTeardown(@()release(packer));
            packets=zeros(190,size(source,1),'uint8');
            for k=1:size(source,1)
                raw.Time=single(10+(k-1)*.02);
                extra.Distance.PositionEN=single(source(k,:)');
                extra.Distance.Used=uint8(1);
                [packets(:,k),~,~]=packer(raw,estimate,control,extra);
            end
            testCase.App.processBytes(packets(:));
            testCase.App.stopRecording();
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            path=findall(testCase.App.DroneAxes,'Tag','GroundXYPath');
            testCase.verifyEqual([path.XData(:) path.YData(:)],-source,'AbsTol',1e-7);
            transform=findall(testCase.App.DroneAxes,'Type','hgtransform');
            testCase.assertNumElements(transform,1);
            testCase.verifyEqual(transform.Matrix, ...
                [-1 0 0 -.02;0 0 1 0;0 1 0 .35;0 0 0 1],'AbsTol',1e-7);
            testCase.verifyTrue(contains(testCase.App.MotionLabel.Text,'表示EN: -0.020'));
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            history=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(history.XYM,-source,'AbsTol',1e-7);
            saved=load(file,'telemetry','rawFrames','info');
            columns=ismember(saved.info.Columns,{'XYX','XYY'});
            testCase.verifyEqual(saved.telemetry(:,columns),source,'AbsTol',1e-7);
            testCase.verifyEqual(saved.rawFrames,packets');
        end

        function repeatedModelReloadDoesNotLoseQueuedPackets(testCase)
            testCase.App.ParallelEnabled=false;
            [packets,~,~,~,~]=testCase.packets(4);
            testCase.App.processBytes(packets(:,1));
            testCase.App.processBytes(packets(:,2:end),0);
            before=testCase.App.backgroundStatus();
            testCase.App.controlLoadButtonPushed([]);
            testCase.App.processBytes(zeros(0,1,'uint8'));
            after=testCase.App.backgroundStatus();
            testCase.verifyGreaterThan(before.QueuedBytes,0);
            testCase.verifyEqual(after.Frames,4);
            testCase.verifyEqual(after.QueuedBytes,0);
            testCase.verifySize(testCase.App.ControlPIDTable.Data,[7 4]);
            testCase.verifyEqual(string(testCase.App.ControlLoadButton.Enable),"on");
            testCase.verifyFalse(after.ModelOperation);
        end

        function historyLegendsSurviveRefreshAndFileSelection(testCase)
            testCase.App.ParallelEnabled=false;
            first=testCase.record(5);second=testCase.record(6);
            imu.RecordingHistoryView.refresh(testCase.App,first);
            axesList=[testCase.App.HistoryHeightAxes testCase.App.HistoryVerticalSpeedAxes ...
                testCase.App.HistoryControlAxes testCase.App.HistoryMotorAxes testCase.App.HistoryXYAxes];
            expected=cell(1,numel(axesList));
            for k=1:numel(axesList)
                expected{k}=string(axesList(k).Legend.String);
                testCase.verifyNotEmpty(expected{k});
            end
            testCase.App.renderHistory(testCase.App.HistoryCache.Logs,testCase.App.HistoryCache.Errors);
            for k=1:numel(axesList)
                testCase.verifyEqual(string(axesList(k).Legend.String),expected{k});
                testCase.verifyEqual(string(axesList(k).Legend.Visible),"on");
            end
            testCase.App.HistoryList.Value=cellstr([first;second]);
            testCase.App.historySelectionChanged([]);
            comparison=string(testCase.App.HistoryHeightAxes.Legend.String);
            testCase.verifyTrue(any(startsWith(comparison,"1: ")));
            testCase.verifyTrue(any(startsWith(comparison,"2: ")));
            testCase.App.HistoryList.Value=cellstr(second);
            testCase.App.historySelectionChanged([]);
            for k=1:numel(axesList)
                testCase.verifyNotEmpty(axesList(k).Legend.String);
                testCase.verifyEqual(string(axesList(k).Legend.Visible),"on");
            end
        end

        function monitorLegendsRemainAttachedToTheirAxes(testCase)
            axesList=[testCase.App.AccelAxes testCase.App.GyroAxes testCase.App.MagAxes ...
                testCase.App.MotorAxes testCase.App.ToFAxes];
            expected={{'X','Y','Z'},{'X','Y','Z'},{'X','Y','Z'}, ...
                {'FR','FL','RR','RL'},{'斜距離','補正高さ'}};
            for k=1:numel(axesList)
                testCase.verifyEqual(axesList(k).Legend.String,expected{k});
                testCase.verifyEqual(axesList(k).Legend.Location,'northwest');
            end
        end
    end
    methods (Access=private)
        function timers=ownedTimers(testCase)
            timers=[timerfindall('Name','StampFlyFlightRecorder'); ...
                timerfindall('Name','StampFlyTelemetryPump');timerfindall('Name','StampFlyLiveDisplay')];
            keep=false(size(timers));
            for k=1:numel(timers)
                callback=functions(timers(k).TimerFcn);
                keep(k)=isfield(callback,'workspace') && ~isempty(callback.workspace) && ...
                    isfield(callback.workspace{1},'app') && ...
                    isequal(callback.workspace{1}.app,testCase.App);
            end
            timers=timers(keep);
        end

        function requireParallel(testCase)
            state=testCase.App.backgroundStatus();
            testCase.assumeTrue(state.Parallel,'Parallel Computing Toolbox not available.');
        end
        function file=record(testCase,count)
            packets=testCase.packets(count);
            file=testCase.App.startRecording();testCase.App.processBytes(packets(:));
            testCase.App.stopRecording();
            testCase.assertTrue(testCase.App.waitForRecordingSave());
        end
        function waitForClose(testCase)
            clock=tic;
            while isvalid(testCase.App)&&toc(clock)<30,drawnow;pause(.02);end
        end
    end
    methods (Static,Access=private)
        function [packets,base,extensions,rawExtensions,lengths]=packets(count)
            [raw,estimate,control,extra]=logging_fixture();control.Mode=uint8(3);
            packer=basic.ExtendedLogger50;cleanup=onCleanup(@()release(packer)); %#ok<NASGU>
            [~,~,~,~,motion]=horizontal.fixture();
            packets=zeros(808,count,'uint8');base=zeros(190,count,'uint8');
            extensions=nan(3*count,166);rawExtensions=zeros(3*count,246,'uint8');
            lengths=repmat(uint8([246;190;182]),count,1);
            for k=1:count
                raw.Time=single(10+(k-1)*.02);
                extra.Distance.PositionEN=single([.01*(k-1);-.005*(k-1)]);
                [base(:,k),commands,sensors]=packer(raw,estimate,control,extra);
                horizontalFrame=horizontal.packFrame(uint16(k-1),raw.Time,uint32(1401), ...
                    uint32(1801),zeros(24,1,'single'),motion);
                packets(:,k)=[sensors;commands;horizontalFrame;base(:,k)];
                frames={sensors,commands,horizontalFrame};
                for j=1:3
                    row=3*(k-1)+j;s=imu.decodeExtensionFrame(frames{j});
                    extensions(row,:)=[double(s.Kind) double(s.Sequence) s.TimeSeconds ...
                        double(s.BuildID) double(s.FirmwareRevision) s.Values];
                    rawExtensions(row,1:numel(frames{j}))=frames{j};
                end
            end
        end
    end
end
