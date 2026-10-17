classdef RecordingHistoryTest < matlab.unittest.TestCase
    % 状態番号の取り違え、負の直前時刻、再起動と測距欠落を記録ファイルで検証。
    properties
        Folder
    end
    methods (TestMethodSetup)
        function setup(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'config'),fullfile(root,'tests'));
            configure_stampfly_project();
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.Folder=string(fixture.Folder);
        end
    end
    methods (Test)
        function officialModesKeepPreRollAndDoNotCallTakeoffHover(testCase)
            file=testCase.record([10 11 12 13 14 15 16 17],[3 3 2 2 5 3 3 2]);
            log=imu.readRecordingHistory(file);
            testCase.verifyEqual(log.Time,[-2;-1;0;1;2;3;4]);
            testCase.verifyEqual(log.FlightState,[3;3;2;2;5;3;3]);
            testCase.verifyEqual(log.TimeZeroSource,'flight_mode');
            testCase.verifyEqual(log.StateCodes,[0 1 2 3 5]);
            testCase.verifyEqual(log.StateNames,{'初期化','800サンプル校正','飛行制御','待機','自動着陸'});
            testCase.verifyEqual(log.RecordingStopName,'待機復帰');
            testCase.verifyTrue(all(isnan(log.FilteredVerticalVelocityMps)), ...
                '固定PID版の重複値を別の速度フィルターと表示しない。');
        end
        function parkedOnlyFileUsesRecordingStart(testCase)
            file=testCase.record([1 1.1 1.2],[3 3 3]);
            log=imu.readRecordingHistory(file);
            testCase.verifyEqual(log.Time,[0;.1;.2],'AbsTol',.0011);
            testCase.verifyEqual(log.TimeZeroSource,'recording_start');
            testCase.verifyTrue(isnan(log.FlightMeanHeightCM));
        end
        function restartEndsFirstFlightAndBreaksAllView(testCase)
            file=testCase.record([10 11 12 12.02 .8 .82 4],[3 2 2 2 1 1 2]);
            first=imu.readRecordingHistory(file);
            testCase.verifyEqual(first.DeviceTimeSeconds,[10;11;12;12.02]);
            testCase.verifyEqual(first.RecordingStopName,'機体時刻リセット');
            full=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(full.BootSegment,[1;1;1;1;2;2;2]);
            testCase.verifyTrue(full.PlotBreakBefore(5));
            testCase.verifyTrue(all(diff(full.Time)>0));
        end
        function transitionSurvivesDecimation(testCase)
            time=10+(0:100)'*.02;mode=3*ones(size(time));mode(42)=2;mode(43)=5;
            file=testCase.record(time,mode);
            log=imu.readRecordingHistory(file,"all",10);
            testCase.verifyTrue(any(log.FlightState==2));
            testCase.verifyTrue(any(log.FlightState==5));
            testCase.verifyTrue(any(abs(log.DeviceTimeSeconds-time(41))<.0011));
        end
        function explicitlyMarkedLegacyKeepsItsOwnStateMeaning(testCase)
            file=testCase.record([10 11 12 13 14],[0 1 2 3 0],9999,'StampFlyHover-v1');
            log=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(log.StateNames,{'待機','離陸','ホバリング','着陸','非常停止'});
            testCase.verifyFalse(log.IsOfficialFixedPID);
        end
        function unrecognizedBuildDoesNotInventStateNames(testCase)
            file=testCase.record([10 11],[3 2],9999,'unknown');
            log=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(log.StateSchema,'unknown');
            testCase.verifyEqual(log.StateNames{4},'Mode 3');
        end
        function millisecondWrapIsNotReboot(testCase)
            file=testCase.record([2^32/1000-.1 .01 .03],[2 2 2]);
            log=imu.readRecordingHistory(file);
            testCase.verifyEqual(log.BootSegment,ones(3,1));
            testCase.verifyGreaterThan(log.DurationSeconds,.12);
            testCase.verifyLessThan(log.DurationSeconds,.14);
        end
        function heightSlopeUsesFreshTimestampsAndResetsAtGaps(testCase)
            t=(0:.02:1)';z=.1+.4*t;fresh=mod((0:numel(t)-1)',2)==0;
            v=imu.heightVelocity(t,z,true(size(t)),fresh);
            testCase.verifyEqual(v(isfinite(v)),repmat(.4,nnz(isfinite(v)),1),'AbsTol',1e-12);
            testCase.verifyTrue(all(isnan(v(~fresh))));
            t2=[t;2+(0:.02:.14)'];z2=[z;.9+.4*(0:.02:.14)'];
            v=imu.heightVelocity(t2,z2,true(size(t2)),true(size(t2)));
            testCase.verifyTrue(all(isnan(v(numel(t)+1:numel(t)+5))), ...
                '長い欠測を速度差分で接続しない。');
            valid=true(size(t));valid(21)=false;
            v=imu.heightVelocity(t,z,valid,true(size(t)));
            testCase.verifyTrue(all(isnan(v(21:25))));
        end
        function historyTiltProjectionMatchesLiveDefinition(testCase)
            file=testCase.record([1 1.1 1.2],[3 3 3]);
            saved=load(file,'telemetry','info');
            saved.telemetry(:,strcmp(saved.info.Columns,'ToFDistanceM'))=.5;
            q=official.eulerQuaternion(single([pi/6;0;0]));
            selected=ismember(saved.info.Columns,{'QuatW','QuatX','QuatY','QuatZ'});
            saved.telemetry(:,selected)=repmat(double(q'),3,1);
            telemetry=saved.telemetry;save(file,'telemetry','-append');
            log=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(log.CorrectedToFM,repmat(.5*cos(pi/6),3,1),'AbsTol',1e-6);
        end
        function delayedBaseDoesNotInventRestart(testCase)
            file=testCase.record([10 11 10 11.02 11.04],[2 2 2 2 2]);
            saved=load(file,'telemetry','info');
            saved.telemetry(3,strcmp(saved.info.Columns,'Sequence'))=saved.telemetry(1,2);
            telemetry=saved.telemetry;save(file,'telemetry','-append');
            log=imu.readRecordingHistory(file,"all");
            testCase.verifyEqual(log.DeviceTimeSeconds,[10;11;11.02;11.04],'AbsTol',.0011);
            testCase.verifyEqual(log.BootSegment,ones(4,1));
            testCase.verifyEqual(log.ExcludedDelayedOrDuplicateFrames,1);
            testCase.verifyEqual(log.RecordingStopReason,'manual_stop');
        end
        function restartConfirmationSurvivesHeavyDecimation(testCase)
            file=testCase.record([10 10.02 .8 .82 .84 .86 4],[2 2 1 1 1 1 2]);
            log=imu.readRecordingHistory(file,"all",2);
            testCase.verifyTrue(any(log.BootSegment==2));
            testCase.verifyTrue(any(abs(log.DeviceTimeSeconds-.8)<.0011));
            testCase.verifyTrue(any(log.PlotBreakBefore));
        end
        function sensorRevisionNamesReservedByteOnlyWhenDefined(testCase)
            file=testCase.record([1 1.02],[3 3]);
            saved=load(file,'info','telemetry');
            extensionTelemetry=nan(2,numel(saved.info.ExtensionColumns));
            extensionTelemetry(:,1)=2;
            extensionTelemetry(:,2:4)=saved.telemetry(:,[2 3 75]);
            extensionTelemetry(:,5)=[1801;1802];
            extensionTelemetry(:,strcmp(saved.info.ExtensionColumns,'Reserved'))=[9;6];
            save(file,'extensionTelemetry','-append');
            joined=imu.readExtendedTelemetry(file);
            testCase.verifyTrue(isnan(joined.ResetReason(1)));
            testCase.verifyEqual(joined.ResetReason(2),6);
            testCase.verifyEqual(joined.Reserved,[9;6]);
        end
    end
    methods (Access=private)
        function file=record(testCase,times,modes,buildID,schema)
            if nargin<4,buildID=1401;end
            if nargin<5,schema='StampFlyOfficial-v1';end
            writer=imu.MatRecordingWriter(testCase.Folder,struct('ExpectedBuildID',buildID,'FlightStateSchema',schema));
            packer=basic.ExtendedLogger50;packer.BuildID=uint32(buildID);
            testCase.addTeardown(@()release(packer));
            [raw,estimate,control,extra]=logging_fixture();
            for k=1:numel(times)
                raw.Time=single(times(k));control.Mode=uint8(modes(k));
                [frame,~,~]=packer(raw,estimate,control,extra);
                frame(7:10)=reshape(typecast(uint32(floor(double(times(k))*1000)),'uint8'),4,1);
                frame(end-1:end)=reshape(typecast(imu.crc16(frame(1:end-2)),'uint8'),2,1);
                writer.append(imu.decodeFrame(frame),frame);
            end
            writer.finish(0,0,struct('Reason','manual_stop'));file=writer.FilePath;
        end
    end
end
