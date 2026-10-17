classdef FlightRecorderTest < matlab.unittest.TestCase
    % 自動記録の開始/保存境界をCRC付きパケットで確認。機器への接続は行わない。
    properties
        Folder
        Recorder
        Packer
        Sequence=uint16(0)
    end
    methods (TestMethodSetup)
        function setupRecorder(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'config'),fullfile(root,'tests'));
            configure_stampfly_project();
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.Folder=string(fixture.Folder);
            testCase.Recorder=imu.FlightRecorder(testCase.Folder,struct('ExpectedBuildID',1401));
            testCase.Packer=basic.ExtendedLogger50;
            testCase.addTeardown(@()release(testCase.Packer));
            testCase.Sequence=uint16(0);
        end
    end
    methods (Test)
        function takeoffLandingAndNextFlight(testCase)
            r=testCase.Recorder;
            testCase.accept(10,3);
            testCase.accept(11,3);
            testCase.accept(12,2);
            testCase.verifyTrue(r.Active&&r.Automatic);
            testCase.accept(13,2);
            testCase.accept(14,5);
            testCase.verifyTrue(r.Active);
            testCase.accept(15,3);
            testCase.accept(15.5,3);
            testCase.verifyTrue(r.Active);
            testCase.accept(16,3);
            testCase.verifyFalse(r.Active);
            saved=load(r.LastPath,'telemetry','info');
            testCase.verifyEqual(saved.telemetry(:,3),[10;11;12;13;14;15;15.5;16]);
            testCase.verifyTrue(saved.info.Config.Recording.Automatic);
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'parked');
            testCase.accept(16.1,2);
            testCase.accept(17,3);
            testCase.accept(18,3);
            testCase.verifyNumElements(r.SavedPaths,2);
            testCase.verifyNotEqual(r.SavedPaths(1),r.SavedPaths(2));
        end
        function supplementsBeforeBaseAreRetained(testCase)
            r=testCase.Recorder;
            [base,commands,sensors]=testCase.frames(20,3);
            r.accept(imu.decodeExtensionFrame(sensors),sensors,20,0,0);
            r.accept(imu.decodeExtensionFrame(commands),commands,20,0,0);
            r.accept(imu.decodeFrame(base),base,20,0,0);
            [base,commands,sensors]=testCase.frames(21,2);
            r.accept(imu.decodeExtensionFrame(sensors),sensors,21,0,0);
            r.accept(imu.decodeExtensionFrame(commands),commands,21,0,0);
            testCase.verifyTrue(r.Active,'SFIXで通常フレームより早く開始する。');
            r.accept(imu.decodeFrame(base),base,21,0,0);
            r.stop(0,0,'manual_stop');
            saved=load(r.LastPath,'extensionTelemetry','rawFrames','info');
            testCase.verifySize(saved.rawFrames,[2 190]);
            testCase.verifySize(saved.extensionTelemetry,[4 166]);
            testCase.verifyEqual(saved.info.ExtensionFrames,4);
        end
        function alreadyFlyingOnConnectIsRecorded(testCase)
            testCase.accept(100,2);
            testCase.verifyTrue(testCase.Recorder.Active);
            testCase.Recorder.stop(0,0,'disconnected');
            saved=load(testCase.Recorder.LastPath,'telemetry','info');
            testCase.verifySize(saved.telemetry,[1 80]);
            testCase.verifyEqual(saved.info.Config.Recording.Trigger,'connected_midflight');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'disconnected');
        end
        function lossPollPersistsReceivedData(testCase)
            testCase.accept(30,2);
            testCase.Recorder.poll(31.9,4,2);
            testCase.verifyTrue(testCase.Recorder.Active);
            testCase.Recorder.poll(32.1,4,2);
            saved=load(testCase.Recorder.LastPath,'info','telemetry');
            testCase.verifyFalse(testCase.Recorder.Active);
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'telemetry_lost');
            testCase.verifyEqual(saved.info.MissingFrames,4);
            testCase.verifyEqual(saved.info.CRCRejected,2);
            testCase.verifySize(saved.telemetry,[1 80]);
        end
        function rebootClosesFlightWithoutCallingItLanding(testCase)
            testCase.accept(100,2);
            testCase.accept(101,2);
            testCase.accept(.1,1);
            testCase.verifyTrue(testCase.Recorder.Active,'単独の時刻逆転では分割しない。');
            testCase.accept(.12,1);
            saved=load(testCase.Recorder.LastPath,'info');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'firmware_restart');
            testCase.verifyFalse(testCase.Recorder.Active);
            testCase.accept(3,2);
            testCase.verifyTrue(testCase.Recorder.Active);
            testCase.Recorder.stop(0,0,'app_closed');
        end
        function shortTurnaroundStillMakesSeparateFiles(testCase)
            testCase.accept(10,2);
            testCase.accept(11,3);
            testCase.accept(11.1,2);
            testCase.verifyTrue(testCase.Recorder.Active);
            testCase.verifyNumElements(testCase.Recorder.SavedPaths,1);
            first=load(testCase.Recorder.LastPath,'info');
            testCase.verifyEqual(first.info.RecordingStop.Reason,'parked_next_takeoff');
            testCase.Recorder.stop(0,0,'app_closed');
            testCase.verifyNumElements(testCase.Recorder.SavedPaths,2);
        end
        function manualRecordingKeepsWaitingData(testCase)
            r=testCase.Recorder;
            r.startManual(testCase.Folder,2,1);
            testCase.accept(1,3);
            testCase.accept(2,3);
            testCase.verifyTrue(r.Active);
            testCase.verifyFalse(r.Automatic);
            r.stop(5,2,'manual_stop');
            saved=load(r.LastPath,'telemetry','info');
            testCase.verifySize(saved.telemetry,[2 80]);
            testCase.verifyEqual(saved.info.MissingFrames,3);
            testCase.verifyEqual(saved.info.CRCRejected,1);
        end
        function foreignFlightDoesNotStartRecording(testCase)
            [base,~,~]=testCase.frames(1,2);
            base(177:180)=reshape(typecast(uint32(9999),'uint8'),4,1);
            base(189:190)=reshape(typecast(imu.crc16(base(1:188)),'uint8'),2,1);
            testCase.Recorder.accept(imu.decodeFrame(base),base,1,0,0);
            testCase.verifyFalse(testCase.Recorder.Active);
            testCase.verifyEmpty(testCase.Recorder.SavedPaths);
        end
        function oldSupplementCannotReopenFinishedFlight(testCase)
            [~,old,~]=testCase.frames(1,2);
            testCase.accept(1,2);
            testCase.accept(2,3);
            testCase.accept(3,3);
            testCase.Recorder.accept(imu.decodeExtensionFrame(old),old,3.1,0,0);
            testCase.verifyFalse(testCase.Recorder.Active);
        end
        function oldSupplementDoesNotSplitActiveFlight(testCase)
            [~,old,~]=testCase.frames(10,2);
            testCase.accept(10,2);
            testCase.accept(11,2);
            testCase.Recorder.accept(imu.decodeExtensionFrame(old),old,11.1,0,0);
            testCase.verifyTrue(testCase.Recorder.Active);
            testCase.verifyEmpty(testCase.Recorder.SavedPaths);
            testCase.Recorder.stop(0,0,'app_closed');
            saved=load(testCase.Recorder.LastPath,'info','extensionTelemetry');
            testCase.verifySize(saved.extensionTelemetry,[1 166]);
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'app_closed');
        end
        function rebootSupplementWaitsForBaseConfirmation(testCase)
            testCase.accept(100,2);
            [base,commands,sensors]=testCase.frames(.1,1);
            r=testCase.Recorder;
            r.accept(imu.decodeExtensionFrame(sensors),sensors,101,0,0);
            r.accept(imu.decodeExtensionFrame(commands),commands,101,0,0);
            testCase.verifyTrue(r.Active);
            r.accept(imu.decodeFrame(base),base,101,0,0);
            testCase.verifyTrue(r.Active);
            [base2,commands2,sensors2]=testCase.frames(.12,1);
            r.accept(imu.decodeExtensionFrame(sensors2),sensors2,101.02,0,0);
            r.accept(imu.decodeExtensionFrame(commands2),commands2,101.02,0,0);
            r.accept(imu.decodeFrame(base2),base2,101.02,0,0);
            testCase.verifyFalse(r.Active);
            saved=load(r.LastPath,'info','extensionTelemetry','telemetry');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'firmware_restart');
            testCase.verifyEmpty(saved.extensionTelemetry,'新しい起動の補足を前の飛行に混ぜない。');
            testCase.verifyEqual(saved.telemetry(:,3),100);
        end
        function millisecondClockWrapKeepsOneFlight(testCase)
            testCase.accept(2^32/1000-.02,2);
            testCase.accept(.001,2);
            testCase.verifyTrue(testCase.Recorder.Active);
            testCase.verifyEmpty(testCase.Recorder.SavedPaths);
            testCase.accept(.1,3);
            testCase.accept(1.2,3);
            testCase.verifyNumElements(testCase.Recorder.SavedPaths,1);
            saved=load(testCase.Recorder.LastPath,'info','telemetry');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'parked');
            testCase.verifySize(saved.telemetry,[4 80]);
        end
        function finalSupplementGroupWaitsForBase(testCase)
            testCase.accept(1,2);testCase.accept(2,3);
            [base,commands,sensors]=testCase.frames(3,3);
            r=testCase.Recorder;
            r.accept(imu.decodeExtensionFrame(sensors),sensors,3,0,0);
            r.accept(imu.decodeExtensionFrame(commands),commands,3,0,0);
            testCase.verifyTrue(r.Active);
            r.accept(imu.decodeFrame(base),base,3,0,0);
            testCase.verifyFalse(r.Active);
            saved=load(r.LastPath,'telemetry','extensionTelemetry');
            testCase.verifyEqual(saved.telemetry(:,3),[1;2;3]);
            testCase.verifySize(saved.extensionTelemetry,[2 166]);
        end
        function startupFailureIsVisible(testCase)
            occupied=fullfile(testCase.Folder,'occupied');
            fid=fopen(occupied,'w');fclose(fid);
            testCase.Recorder.Folder=occupied;
            testCase.accept(1,2);
            testCase.verifyFalse(testCase.Recorder.Active);
            testCase.verifyGreaterThan(strlength(testCase.Recorder.ErrorMessage),0);
            testCase.verifyEmpty(testCase.Recorder.SavedPaths);
        end
        function delayedBaseDoesNotSplitFlight(testCase)
            [old,~,~]=testCase.frames(10,2);
            testCase.accept(10,2);testCase.accept(11,2);
            r=testCase.Recorder;r.accept(imu.decodeFrame(old),old,11.01,0,0);
            testCase.verifyTrue(r.Active);testCase.verifyEmpty(r.SavedPaths);
            testCase.accept(11.02,2);r.stop(0,0,'app_closed');
            saved=load(r.LastPath,'info','telemetry');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'app_closed');
            testCase.verifySize(saved.telemetry,[4 80]);
        end
        function initializationReturnIsNotParked(testCase)
            testCase.accept(10,2);testCase.accept(11,1);testCase.accept(12,1);
            saved=load(testCase.Recorder.LastPath,'info');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'initialization');
            testCase.verifyFalse(testCase.Recorder.Active);
        end
        function unconfirmedResetDoesNotInventCause(testCase)
            testCase.accept(100,2);testCase.accept(.1,1);
            testCase.Recorder.poll(102.1,0,0);
            saved=load(testCase.Recorder.LastPath,'info','telemetry');
            testCase.verifyEqual(saved.info.RecordingStop.Reason,'telemetry_lost');
            testCase.verifySize(saved.telemetry,[2 80],'未確定の受信パケットも原データとして保存する。');
            history=imu.readRecordingHistory(testCase.Recorder.LastPath,"all");
            testCase.verifyEqual(history.RecordingStopName,'通信途絶');
            testCase.verifyEqual(history.BootSegment,1);
            testCase.verifyEqual(history.ExcludedDelayedOrDuplicateFrames,1);
        end
        function restartReasonStaysWithNewBootMetadata(testCase)
            testCase.Packer.FirmwareRevision=uint32(1802);
            testCase.accept(100,2);
            [base,~,sensors]=testCase.frames(.1,1);
            sensors(244)=uint8(6);
            sensors(245:246)=reshape(typecast(imu.crc16(sensors(1:244)),'uint8'),2,1);
            r=testCase.Recorder;
            r.accept(imu.decodeExtensionFrame(sensors),sensors,101,0,0);
            r.accept(imu.decodeFrame(base),base,101,0,0);
            testCase.accept(.12,1);
            saved=load(r.LastPath,'info','extensionTelemetry');
            testCase.verifyEqual(saved.info.RecordingStop.NewBoot.ResetReason,6);
            testCase.verifyEqual(saved.info.RecordingStop.NewBoot.ConfirmedByBaseFrames,2);
            testCase.verifyEmpty(saved.extensionTelemetry);
            log=imu.readRecordingHistory(r.LastPath);
            testCase.verifyEqual(log.RestartReasonName,imu.resetReasonName(6));
        end
    end
    methods (Access=private)
        function accept(testCase,time,mode)
            [base,~,~]=testCase.frames(time,mode);
            testCase.Recorder.accept(imu.decodeFrame(base),base,time,0,0);
        end
        function [base,commands,sensors]=frames(testCase,time,mode)
            [raw,estimate,control,extra]=logging_fixture();
            raw.Time=single(time);control.Mode=uint8(mode);control.PreviousMode=uint8(mode);
            [base,commands,sensors]=testCase.Packer(raw,estimate,control,extra);
            testCase.Sequence=testCase.Sequence+uint16(1);
        end
    end
end
