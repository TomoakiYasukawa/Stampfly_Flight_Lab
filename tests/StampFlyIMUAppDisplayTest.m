classdef StampFlyIMUAppDisplayTest < matlab.unittest.TestCase
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
            testCase.App = StampFlyIMUApp();
            testCase.App.UIFigure.Visible = 'off';
            testCase.addTeardown(@()delete(testCase.App));
        end
    end

    methods (Test)
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
            testCase.verifySize(saved.extensionTelemetry,[202 126]);
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
            plotted=findall(testCase.App.PathAxes,'Type','line');
            testCase.verifyEqual(numel(plotted),1);
            testCase.verifyEqual(plotted.XData(end),.2,'AbsTol',1e-6);
            testCase.verifyEqual(plotted.YData(end),-.1,'AbsTol',1e-6);
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
            testCase.verifyEqual(nnz(isfinite(values)),402);
            testCase.verifyEqual(testCase.App.ErrorLabel.Text,'欠落: 0 / CRC: 0 / 対象外: 0');
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
