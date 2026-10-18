classdef DataLoggerDisplayTest < matlab.unittest.TestCase
    % グラフと記録を公開インターフェースから確認する。USB接続は行わない。
    properties (TestParameter)
        ReceiveRate = struct('ToF25Hz',25,'Logger50Hz',50,'Control400Hz',400)
    end

    properties
        App
    end

    methods (TestMethodSetup)
        function createApp(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.CurrentFolderFixture(root));
            addpath(fullfile(root,'config'));
            configure_stampfly_project();
            testCase.App = DataLogger();
            testCase.App.UIFigure.Visible = 'off';
            testCase.App.ParallelEnabled=false;
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.setRecordingFolder(string(folder.Folder));
            testCase.assertTrue(testCase.App.waitForHistoryRead());
        end
    end

    methods (TestMethodTeardown)
        function closeApp(testCase)
            if isvalid(testCase.App),delete(testCase.App);end
        end
    end

    methods (Test)
        function automaticRecordingThroughAppKeepsAllHeaders(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.RecordingFolder=string(fixture.Folder);
            [raw,estimate,control,extra]=logging_fixture();
            packer=basic.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            times=[10 10.05 10.1 10.15 10.2 10.25 11.3];modes=uint8([3 3 2 2 5 3 3]);
            [~,~,~,~,motion]=horizontal.fixture();
            bytes=zeros(0,1,'uint8');
            for k=1:numel(times)
                raw.Time=single(times(k));control.Mode=modes(k);control.PreviousMode=modes(k);
                [base,commands,sensors]=packer(raw,estimate,control,extra);
                horizontalFrame=horizontal.packFrame(uint16(k-1),raw.Time,uint32(1401), ...
                    uint32(1801),zeros(24,1,'single'),motion);
                % テキスト・断片化・通常より先のSFIX/SFIHも自動記録へ渡ります。
                bytes=[bytes;uint8('SFTASK n=400').';uint8(10);horizontalFrame;sensors;commands;base]; %#ok<AGROW>
                if k==3
                    testCase.App.processBytes(bytes(1:23));
                    testCase.App.processBytes(bytes(24:end));bytes=zeros(0,1,'uint8');
                    status=testCase.App.recordingStatus();
                    testCase.verifyTrue(status.Active&&status.Automatic);
                    testCase.verifyEqual(string(testCase.App.RecordButton.Enable),"off");
                end
            end
            testCase.App.processBytes(bytes);
            status=testCase.App.recordingStatus();
            testCase.verifyFalse(status.Active);
            testCase.verifyNumElements(status.SavedFiles,1);
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            saved=load(status.LastFile,'telemetry','extensionTelemetry','info');
            testCase.verifyEqual(saved.telemetry(:,3),times','AbsTol',.0011);
            testCase.verifySize(saved.extensionTelemetry,[21 166]);
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'parked');
            testCase.verifyEqual(string(testCase.App.RecordButton.Enable),"on");
            joined=imu.readExtendedTelemetry(status.LastFile);
            testCase.verifyEqual(joined.FlightMode,double(modes(:)));
            testCase.verifyTrue(all(isfinite(joined.HorizontalVelocityXMps)));
        end

        function closingAppSavesFlightAndRemovesItsTimer(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.RecordingFolder=string(fixture.Folder);
            before=testCase.ownedTimers('StampFlyFlightRecorder');
            testCase.assertNumElements(before,1);
            [raw,estimate,control,extra]=logging_fixture();
            packer=basic.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            raw.Time=single(20);control.Mode=uint8(2);
            [base,commands,sensors]=packer(raw,estimate,control,extra);
            testCase.App.processBytes([sensors;commands;base]);
            state=testCase.App.recordingStatus();
            testCase.verifyTrue(state.Active);
            delete(testCase.App);
            saved=load(state.CurrentFile,'telemetry','info');
            testCase.verifySize(saved.telemetry,[1 80]);
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'app_closed');
            testCase.verifyTrue(saved.info.Complete);
            testCase.verifyFalse(any(isvalid(before)));
        end

        function appTimerSavesAfterTelemetryStops(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.RecordingFolder=string(fixture.Folder);
            [raw,estimate,control,extra]=logging_fixture();
            packer=basic.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            raw.Time=single(1);control.Mode=uint8(2);
            [base,commands,sensors]=packer(raw,estimate,control,extra);
            testCase.App.processBytes([sensors;commands;base]);
            state=testCase.App.recordingStatus();testCase.verifyTrue(state.Active);
            pollClock=tic;
            while state.Active&&toc(pollClock)<6
                pause(.1);state=testCase.App.recordingStatus();
            end
            testCase.verifyFalse(state.Active);
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            saved=load(state.LastFile,'info');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'telemetry_lost');
        end

        function horizontalStatusDoesNotAddPlotSamples(testCase)
            [~,~,~,~,motion]=horizontal.fixture();
            values=zeros(24,1,'single');
            values(3:6)=single([.1;-.2;.15;-.1]);
            values(15:17)=single([1;3;1]);values(21)=single(1);
            frame=horizontal.packFrame(uint16(0),single(1),uint32(1401),uint32(1801),values,motion);
            testCase.App.processBytes(frame(1:25));
            testCase.verifyEqual(testCase.App.HorizontalLabel.Text,'水平補助: 未受信');
            testCase.App.processBytes(frame(26:end));
            testCase.verifyTrue(contains(testCase.App.HorizontalLabel.Text,'移動'));
            testCase.verifyTrue(contains(testCase.App.HorizontalLabel.Text,'速度 X 0.10 / Y -0.20'));
            testCase.verifyTrue(contains(testCase.App.HorizontalLabel.Tooltip,'局所X=基準機首'));
            testCase.verifyEqual(testCase.App.FrameLabel.Text,'フレーム: 0');
            foreign=horizontal.packFrame(uint16(1),single(1.02),uint32(9999),uint32(1801),zeros(24,1,'single'),motion);
            testCase.App.processBytes(foreign);
            testCase.verifyTrue(contains(testCase.App.HorizontalLabel.Text,'移動'));
        end

        function historyUsesOfficialStatesAndShowsUnobservedEnd(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.RecordingFolder=string(fixture.Folder);
            [raw,estimate,control,extra]=logging_fixture();
            packer=basic.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            times=[10 10.1 10.2 10.3 10.4];modes=uint8([3 3 2 2 2]);
            for k=1:numel(times)
                raw.Time=single(times(k));control.Mode=modes(k);control.PreviousMode=modes(k);
                [base,commands,sensors]=packer(raw,estimate,control,extra);
                testCase.App.processBytes([sensors;commands;base]);
            end
            testCase.App.stopRecording();state=testCase.App.recordingStatus();
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            imu.RecordingHistoryView.refresh(testCase.App,state.LastFile);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            testCase.verifyEqual(testCase.App.HistoryStateAxes.YTick,0:4);
            testCase.verifyEqual(string(testCase.App.HistoryStateAxes.YTickLabel), ...
                ["初期化";"校正";"待機";"飛行制御";"着陸"]);
            testCase.verifyLessThan(testCase.App.HistoryHeightAxes.XLim(1),0);
            markers=findall(testCase.App.HistoryHeightAxes,'Type','constantline');
            names=string({markers.Label});
            testCase.verifyTrue(any(names=="待機"));
            testCase.verifyTrue(any(names=="飛行制御"));
            testCase.verifyFalse(any(names=="ホバリング"));
            testCase.verifyTrue(contains(testCase.App.HistoryStatusLabel.Text,'手動停止'));
            testCase.verifyEqual(testCase.App.HistorySummaryTable.Data{1,8},'手動停止');
            lines=findall(testCase.App.HistoryVerticalSpeedAxes,'Type','line');
            testCase.verifyFalse(any(string({lines.DisplayName})=="フィルター後"));
        end

        function chosenFolderIsUsedByRecorderAndHistory(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.setRecordingFolder(string(fixture.Folder));
            file=testCase.App.startRecording();
            [raw,estimate,control,extra]=logging_fixture();
            control.Mode=uint8(3);
            packer=basic.ExtendedLogger50;testCase.addTeardown(@()release(packer));
            [base,commands,sensors]=packer(raw,estimate,control,extra);
            testCase.App.processBytes([commands;sensors;base]);testCase.App.stopRecording();
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            testCase.verifyEqual(string(fileparts(file)),string(fixture.Folder));
            imu.RecordingHistoryView.refresh(testCase.App);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            testCase.verifyTrue(ismember(file,string(testCase.App.HistoryList.ItemsData)));
            testCase.verifyTrue(contains(testCase.App.HistoryFolderLabel.Text,fixture.Folder));
            testCase.verifyTrue(contains(testCase.App.HistoryDataLabel.Text,string(testCase.App.HistoryList.Items{1})));
            axes=[testCase.App.HistoryHeightAxes testCase.App.HistoryControlAxes ...
                testCase.App.HistoryValidityAxes testCase.App.HistoryXYAxes testCase.App.HistoryStateAxes];
            for ax=axes
                testCase.verifyEmpty(ax.Subtitle.String);
                testCase.verifyEqual(ax.UserData.SourceFiles,file);
            end
        end

        function historyShowsExactControlAndSeparatedFlagsAndXYEndpoints(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.App.setRecordingFolder(string(fixture.Folder));
            file=testCase.App.startRecording();
            [raw,estimate,control,extra]=logging_fixture();
            control.Mode=uint8(2);control.AltitudeEnabled=uint8(1);
            packer=basic.ExtendedLogger50;testCase.addTeardown(@()release(packer));
            for k=1:4
                raw.Time=single(10+k*.02);
                estimate.ControlDiagnostics(2)=single(.70);
                estimate.ControlDiagnostics(5)=single(3.7*(.70+k*.001));
                extra.Distance.PositionEN=single([k*.01;-k*.02]);
                [base,commands,sensors]=packer(raw,estimate,control,extra);
                testCase.App.processBytes([commands;sensors;base]);
            end
            testCase.App.stopRecording();imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.assertTrue(testCase.App.waitForRecordingSave());
            imu.RecordingHistoryView.refresh(testCase.App,file);
            testCase.assertTrue(testCase.App.waitForHistoryRead());
            effort=findall(testCase.App.HistoryControlAxes,'Type','line', ...
                'DisplayName','共通推力−基準（平滑化・制限後）');
            testCase.verifyNumElements(effort,1);
            testCase.verifyEqual(effort.YData,(1:4)*.001,'AbsTol',1e-6);
            for k=1:6
                flag=findall(testCase.App.HistoryValidityAxes,'Tag',sprintf('DiagnosticFlag%d',k));
                testCase.verifyNumElements(flag,1);
                y=flag.YData(isfinite(flag.YData));
                testCase.verifyGreaterThanOrEqual(y,repmat(3*(k-1),size(y)));
                testCase.verifyLessThanOrEqual(y,repmat(3*(k-1)+.7,size(y)));
            end
            first=findall(testCase.App.HistoryXYAxes,'Type','line','Tag','XYStart');
            last=findall(testCase.App.HistoryXYAxes,'Type','line','Tag','XYEnd');
            testCase.verifyEqual([first.XData first.YData],[0 0],'AbsTol',1e-7);
            testCase.verifyEqual([last.XData last.YData],[-.03 .06],'AbsTol',1e-6);
            testCase.verifyEqual(first.UserData.TimeSeconds,0,'AbsTol',1e-6);
            testCase.verifyEqual(last.UserData.TimeSeconds,.06,'AbsTol',.0011);
            testCase.verifyTrue(contains(first.DisplayName,'開始 0.00 s'));
            testCase.verifyTrue(contains(last.DisplayName,'終了 0.06 s'));
            testCase.verifyEqual(testCase.App.HistoryXYAxes.Legend.Location,'northwest');
        end

        function tofGraphUsesTiltProjectionNotKalmanHeight(testCase)
            [raw,estimate,control,extra]=logging_fixture();
            packer=official.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            raw.BottomMm=int16(500);
            estimate.Height=single(.5); % Intentionally equal to the slant range.
            angles=single([0 0 0;pi/6 0 0;0 pi/4 0;pi/6 pi/4 pi/3]);
            frames=zeros(190,4,'uint8');
            for k=1:4
                raw.Time=single(1+(k-1)/50);
                estimate.Angles=angles(k,:)';
                [frames(:,k),~,~]=packer(raw,estimate,control,extra);
            end
            testCase.App.processBytes(frames(:));drawnow;
            slant=findall(testCase.App.ToFAxes,'Type','line','DisplayName','斜距離');
            corrected=findall(testCase.App.ToFAxes,'Type','line','DisplayName','補正高さ');
            expected=.5*cos(double(angles(:,1))).*cos(double(angles(:,2)));
            testCase.verifyEqual(slant.YData,repmat(.5,1,4),'AbsTol',1e-7);
            testCase.verifyEqual(corrected.YData,expected','AbsTol',1e-6);
            testCase.verifyGreaterThan(slant.YData(3)-corrected.YData(3),.14);
        end

        function supplementalFramesKeepOnePlotSamplePerSequence(testCase)
            [raw,estimate,control,extra]=logging_fixture();
            packer=official.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            folder=string(fullfile(stampfly_project_root(),'build','tests','logger_display'));
            file=testCase.App.startRecording(folder);
            for k=1:101
                raw.Time=single(1+(k-1)/50);
                [base,commands,sensors]=packer(raw,estimate,control,extra);
                % A supplement may arrive before the base packet and in pieces.
                testCase.App.processBytes([sensors;commands(1:27)]);
                if k==101,pause(0.1);end % Let the final live redraw pass its 80 ms throttle.
                testCase.App.processBytes([commands(28:end);base]);
            end
            testCase.App.stopRecording();drawnow;
            [time,~]=testCase.accelLine();
            saved=load(file,'info','telemetry','extensionTelemetry');
            joined=imu.readExtendedTelemetry(file);
            testCase.verifyEqual(numel(time),101);
            testCase.verifyEqual(time(end),2,'AbsTol',.0011);
            testCase.verifyEqual(testCase.App.FrameLabel.Text,'フレーム: 101');
            testCase.verifyEqual(testCase.App.ErrorLabel.Text,'欠落: 0 / CRC: 0 / 対象外: 0');
            testCase.verifySize(saved.telemetry,[101 80]);
            testCase.verifySize(saved.extensionTelemetry,[202 166]);
            testCase.verifyEqual(saved.info.ExtensionFrames,202);
            testCase.verifyEqual(joined.AppliedPWMFR,repmat(100,101,1));
            testCase.verifyEqual(joined.FlowShutter16,repmat(8123,101,1));
        end

        function opticalFlowDistanceIsVisibleInMeters(testCase)
            [raw,estimate,control,extra]=logging_fixture();
            packer=official.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            frames=zeros(190,51,'uint8');
            for k=1:51
                raw.Time=single(1+(k-1)/50);
                extra.Distance.PositionEN=single([.004*(k-1);-.002*(k-1)]);
                extra.Distance.Used=uint8(1);
                extra.Distance.DeltaEN=single([.004;-.002]);
                [frames(:,k),~,~]=packer(raw,estimate,control,extra);
            end
            testCase.App.processBytes(frames(:));drawnow;
            plotted=findall(testCase.App.DroneAxes,'Type','line','Tag','GroundXYPath');
            testCase.verifyEqual(numel(plotted),1);
            testCase.verifyEqual(plotted.XData(end),-.2,'AbsTol',1e-6);
            testCase.verifyEqual(plotted.YData(end),.1,'AbsTol',1e-6);
            testCase.verifyGreaterThanOrEqual(numel(plotted.XData),51);
        end

        function mixedBuildsDoNotClearPlots(testCase)
            valid = testCase.frames(50,12,1401,44.729);
            foreign = testCase.frames(50,12,2026101202,1869.960);
            mixed = reshape([valid;foreign],[],1);

            testCase.App.processBytes(mixed);
            drawnow;
            [time,values] = testCase.accelLine();

            testCase.verifyGreaterThanOrEqual(time(end)-time(1),9.98);
            testCase.verifyLessThanOrEqual(time(end)-time(1),10.04);
            testCase.verifyTrue(all(diff(time)>=0));
            testCase.verifyEqual(values(end),0.25,'AbsTol',1e-6);
            testCase.verifyEqual(testCase.App.FrameLabel.Text,'フレーム: 601');
            testCase.verifyEqual(testCase.App.ErrorLabel.Text,'欠落: 0 / CRC: 0 / 対象外: 601');
            testCase.verifyEqual(diff(testCase.App.AccelAxes.XLim),10,'AbsTol',1e-10);
        end

        function tenSecondHistoryDoesNotDependOnReceiveRate(testCase,ReceiveRate)
            packets = testCase.frames(ReceiveRate,12,1401,1200);

            testCase.App.processBytes(packets(:));
            drawnow;
            [time,values] = testCase.accelLine();

            testCase.verifyGreaterThanOrEqual(time(end)-time(1),9.99);
            testCase.verifyLessThanOrEqual(time(end)-time(1),10+2/ReceiveRate);
            testCase.verifyTrue(all(isfinite(values)));
            testCase.verifyLessThanOrEqual(abs(time(end)-testCase.App.AccelAxes.XLim(2)),0.02);
            testCase.verifyGreaterThanOrEqual(nnz(time>=testCase.App.AccelAxes.XLim(1)),10*ReceiveRate);
        end

        function firstSampleStartsAtConnectionTime(testCase)
            packet = testCase.frames(50,0,1401,1870);

            testCase.App.processBytes(packet);
            drawnow;
            [time,~] = testCase.accelLine();

            testCase.verifyEqual(time,0,'AbsTol',1e-12);
            testCase.verifyEqual(testCase.App.AccelAxes.XLim,[0 10],'AbsTol',1e-12);
        end

        function rebootKeepsHistoryWithLineBreak(testCase)
            before = testCase.frames(50,6,1401,100);
            after = testCase.frames(50,2,1401,0);

            testCase.App.processBytes([before(:);after(:)]);
            drawnow;
            [time,values] = testCase.accelLine();

            testCase.verifyTrue(all(diff(time)>=0));
            testCase.verifyGreaterThan(time(end),8);
            testCase.verifyEqual(nnz(isnan(values)),1);
            testCase.verifyEqual(nnz(isfinite(values)),400, ...
                '再起動確定前の2件は表示を保留するが、生データは記録する。');
            testCase.verifyEqual(testCase.App.ErrorLabel.Text,'欠落: 0 / CRC: 0 / 対象外: 0');
        end
        function delayedBaseKeepsLiveAndRecordedFlightTogether(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            file=testCase.App.startRecording(string(fixture.Folder));
            packets=testCase.frames(50,1,1401,10);
            testCase.App.processBytes([packets(:);packets(:,1)]);
            testCase.App.processBytes(packets(:,end));
            testCase.App.stopRecording();drawnow;
            [time,values]=testCase.accelLine();
            testCase.verifyFalse(any(isnan(values)));
            testCase.verifyEqual(time(end),1,'AbsTol',.0011);
            saved=load(file,'telemetry');testCase.verifySize(saved.telemetry,[53 80]);
            log=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(log.BootSegment,ones(51,1));
            testCase.verifyEqual(log.ExcludedDelayedOrDuplicateFrames,2);
        end

        function partialPacketLeavesVisibleHistoryIntact(testCase)
            packets = testCase.frames(50,2,1401,0);
            last = packets(:,end);
            testCase.App.processBytes(packets(:,1:end-1));
            [before,~] = testCase.accelLine();

            testCase.App.processBytes(last(1:30));
            [during,~] = testCase.accelLine();
            pause(0.1);
            testCase.App.processBytes(last(31:end));
            drawnow;
            [after,~] = testCase.accelLine();

            testCase.verifyEqual(during,before,'AbsTol',1e-12);
            testCase.verifyEqual(numel(after),101);
            testCase.verifyEqual(after(end),2,'AbsTol',0.0011);
        end

        function foreignFramesAreExcludedFromRecording(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            folder = string(fullfile(root,'build','tests','logger_display'));
            own = testCase.frames(50,1,1401,44.729);
            other = testCase.frames(50,1,2026101202,1870);
            path = testCase.App.startRecording(folder);

            testCase.App.processBytes(reshape([own;other],[],1));
            testCase.App.stopRecording();
            saved = load(path,'telemetry','info','rawFrames');
            history = imu.readRecordingHistory(path,"all");

            testCase.verifyEqual(size(saved.telemetry,1),51);
            testCase.verifyTrue(all(saved.telemetry(:,75)==1401));
            testCase.verifyEqual(saved.telemetry(:,3), ...
                44.729+(0:50)'/50,'AbsTol',0.0011);
            testCase.verifyEqual(saved.info.Config.ExpectedBuildID,1401);
            testCase.verifyEqual(saved.rawFrames,own');
            testCase.verifyEqual(history.DurationSeconds,1,'AbsTol',0.0011);
            testCase.verifyEqual(history.ExpectedBuildID,1401);
        end

        function droppedAndCorruptPacketsAreCountedWithoutClearing(testCase)
            packets = testCase.frames(50,1,1401,0);
            corrupt = packets(:,11);
            corrupt(20) = bitxor(corrupt(20),uint8(1));
            bytes = [packets(:,1:10),corrupt,packets(:,13:end)];

            testCase.App.processBytes(bytes(:));
            drawnow;
            [time,~] = testCase.accelLine();

            testCase.verifyEqual(testCase.App.ErrorLabel.Text,'欠落: 2 / CRC: 1 / 対象外: 0');
            testCase.verifyEqual(numel(time),49);
            testCase.verifyEqual(time(end),1,'AbsTol',0.0011);
        end
    end

    methods (Access = private)
        function timers=ownedTimers(testCase,name)
            timers=timerfindall('Name',name);
            keep=false(size(timers));
            for k=1:numel(timers)
                callback=functions(timers(k).TimerFcn);
                keep(k)=isfield(callback,'workspace') && ~isempty(callback.workspace) && ...
                    isfield(callback.workspace{1},'app') && ...
                    isequal(callback.workspace{1}.app,testCase.App);
            end
            timers=timers(keep);
        end

        function [time,values] = accelLine(testCase)
            lines = findall(testCase.App.AccelAxes,'Type','line');
            line = lines(end);
            time = line.XData;
            values = line.YData;
        end
    end

    methods (Static,Access = private)
        function packets = frames(rate,duration,buildID,startTime)
            args = {uint16(0),0,single([0.25;-0.15;9.81]),single([0.01;0.02;-0.01]), ...
                uint8(1),single(0.3),uint8(1),uint8(0),single([NaN;NaN]), ...
                uint8(0),uint8(0),uint16(0),single([NaN;NaN]),uint8(0), ...
                single([NaN;NaN;NaN]),uint8(0),single([1;0;0;0]),uint8(1), ...
                single(0.3),uint8(1),single([NaN;NaN]),uint8([0;0;0;0]), ...
                uint8(0),uint8(3),uint16(0)};
            template = imu.packFlightTuningFrame(args{:},nan(32,1,'single'), ...
                uint32(buildID),single([0;0]),uint16(0),uint8(0));
            count = round(rate*duration)+1;
            packets = repmat(template,1,count);
            for k = 1:count
                packets(5:6,k) = reshape(typecast(uint16(mod(k-1,65536)),'uint8'),2,1);
                milliseconds = uint32(round(1000*(startTime+(k-1)/rate)));
                packets(7:10,k) = reshape(typecast(milliseconds,'uint8'),4,1);
                packets(189:190,k) = reshape(typecast(imu.crc16(packets(1:188,k)),'uint8'),2,1);
            end
        end
    end
end
