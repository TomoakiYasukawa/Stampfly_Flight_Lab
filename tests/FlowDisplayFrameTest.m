classdef FlowDisplayFrameTest < matlab.unittest.TestCase
    % Display frame regression; packet/storage and flight control stay raw.
    methods (TestClassSetup)
        function configure(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tests')));
        end
    end
    methods (Test)
        function officialForwardBackRightLeftSigns(testCase)
            [raw,estimate,control,extra]=logging_fixture();
            raw.BottomMm=int16(350);estimate.Angles=single([0;0;-pi]);
            source=[0 -.02;0 .02;-.02 0;.02 0];
            expected=[0 .02;0 -.02;.02 0;-.02 0];
            packer=basic.ExtendedLogger50;
            testCase.addTeardown(@()release(packer));
            tracker=imu.FlatGroundPoseTracker();
            for k=1:size(source,1)
                raw.Time=single(10+k*.02);
                extra.Distance.PositionEN=single(source(k,:)');
                [frame,~,~]=packer(raw,estimate,control,extra);
                sample=imu.decodeFrame(frame);
                [position,height]=tracker.update(sample);
                testCase.verifyEqual(position(1:2),expected(k,:),'AbsTol',1e-7);
                testCase.verifyEqual(height,.35,'AbsTol',1e-7);
                testCase.verifyEqual(double(sample.XYDisplacementM),source(k,:),'AbsTol',1e-7);
            end
        end

        function earlierMonitorBuildKeepsItsDirections(testCase)
            [raw,estimate,control,extra]=logging_fixture();
            packer=basic.ExtendedLogger50;packer.BuildID=uint32(2026101101);
            testCase.addTeardown(@()release(packer));
            extra.Distance.PositionEN=single([.02;-.03]);
            [frame,~,~]=packer(raw,estimate,control,extra);
            sample=imu.decodeFrame(frame);tracker=imu.FlatGroundPoseTracker();
            position=tracker.update(sample);
            testCase.verifyEqual(position(1:2),[.02 -.03],'AbsTol',1e-7);
            testCase.verifyEqual(imu.flowDisplaySign([1401 2026101101 0]),[-1 1 1]);
        end
    end
end
