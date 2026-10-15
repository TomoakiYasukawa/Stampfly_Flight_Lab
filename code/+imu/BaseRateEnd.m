classdef BaseRateEnd < matlab.System
    %BASERATEEND Summarize full-tick time and fresh BMI270 reads on USB CDC.
    % This sink belongs only in the separate diagnostic model. A signal
    % dependency on the motor mixer and telemetry keeps it at the end.
    properties (Nontunable)
        SampleTime = 0.004
        DeadlineUs = uint32(4000)
        GapToleranceUs = uint32(50)
        ReportEvery = uint32(250)
    end

    properties (Access = private)
        StepCount = uint32(0)
        FreshCount = uint32(0)
        TotalUs = uint32(0)
        MaxUs = uint32(0)
        OverrunCount = uint32(0)
        LateCount = uint32(0)
        MaxGapUs = uint32(0)
        LastStartUs = uint32(0)
        Checksum = uint32(0)
    end

    methods (Access = protected)
        function stepImpl(obj,startUs,fresh,motor4,sendQueued)
            stopUs = uint32(0);
            if coder.target('Rtw')
                coder.cinclude('hover_rate_diag.h');
                stopUs = coder.ceval('hover_rate_diag_now_us');
            end
            elapsedUs = stopUs - startUs;
            obj.StepCount = obj.StepCount + uint32(1);
            obj.FreshCount = obj.FreshCount + uint32(fresh ~= 0);
            obj.TotalUs = obj.TotalUs + elapsedUs;
            obj.MaxUs = max(obj.MaxUs,elapsedUs);
            obj.OverrunCount = obj.OverrunCount + ...
                uint32(elapsedUs > obj.DeadlineUs);
            if obj.LastStartUs ~= 0
                gapUs = startUs - obj.LastStartUs;
                obj.MaxGapUs = max(obj.MaxGapUs,gapUs);
                obj.LateCount = obj.LateCount + ...
                    uint32(gapUs > obj.DeadlineUs + obj.GapToleranceUs);
            end
            obj.LastStartUs = startUs;
            % Use these inputs so the probe executes after both branches.
            obj.Checksum = bitxor(obj.Checksum, ...
                sum(uint32(motor4(:))) + uint32(sendQueued));
            if obj.StepCount >= obj.ReportEvery
                meanUs = uint32(obj.TotalUs / obj.StepCount);
                if coder.target('Rtw')
                    coder.ceval('hover_rate_diag_report',obj.StepCount, ...
                        obj.FreshCount,meanUs,obj.MaxUs, ...
                        obj.OverrunCount,obj.LateCount,obj.MaxGapUs, ...
                        obj.Checksum);
                end
                obj.StepCount = uint32(0);
                obj.FreshCount = uint32(0);
                obj.TotalUs = uint32(0);
                obj.MaxUs = uint32(0);
                obj.OverrunCount = uint32(0);
                obj.LateCount = uint32(0);
                obj.MaxGapUs = uint32(0);
                obj.Checksum = uint32(0);
            end
        end
        function resetImpl(obj)
            obj.StepCount = uint32(0);
            obj.FreshCount = uint32(0);
            obj.TotalUs = uint32(0);
            obj.MaxUs = uint32(0);
            obj.OverrunCount = uint32(0);
            obj.LateCount = uint32(0);
            obj.MaxGapUs = uint32(0);
            obj.LastStartUs = uint32(0);
            obj.Checksum = uint32(0);
        end
        function validateInputsImpl(~,startUs,fresh,motor4,sendQueued)
            if ~isscalar(startUs) || ~isscalar(fresh) || ...
                    numel(motor4) ~= 4 || ~isscalar(sendQueued)
                error('imu:BaseRateEnd:Shape', ...
                    'Expected timestamp, IMU status, four motors, send status.');
            end
        end
        function n = getNumInputsImpl(~), n = 4; end
        function n = getNumOutputsImpl(~), n = 0; end
        function varargout = getInputNamesImpl(~)
            varargout = {'StartUs','Fresh','Motor4','SendQueued'};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end
end
