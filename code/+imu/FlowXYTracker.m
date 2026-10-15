classdef FlowXYTracker < matlab.System
    %FLOWXYTRACKER Integrate downward optical flow into relative sensor XY.
    % X is right and Y is forward. Raw PMW3901 Y counts are negative
    % for forward translation on StampFly. The 385 counts/rad scale is an
    % initial estimate from the PX4 PMW3901 driver, not StampFly-calibrated;
    % rotations and sensor tilt are not compensated.

    properties (Nontunable)
        SampleTime = 0.02
        XCountsPerRad = 385
        YCountsPerRad = 385
        MinQuality = 25
        MinHeightM = 0
        MaxHeightM = 2.0
        MaxSpeedMps = 1.5
    end

    properties (Access = private)
        Position = single(zeros(2,1))
    end

    methods (Access = protected)
        function [xy, used] = stepImpl(obj, flow, quality, flowStatus, ...
                shutter, height, tofStatus)
            used = uint8(0);
            xy = obj.Position;
            valid = all(isfinite(flow)) && isfinite(height) && ...
                flowStatus ~= 0 && tofStatus ~= 0 && ...
                (quality >= obj.MinQuality || shutter < 31) && ...
                height >= obj.MinHeightM && height <= obj.MaxHeightM;
            if ~valid
                return
            end
            delta = single([flow(1) * height / obj.XCountsPerRad; ...
                           -flow(2) * height / obj.YCountsPerRad]);
            if any(abs(delta) / single(obj.SampleTime) > obj.MaxSpeedMps)
                return
            end
            obj.Position = obj.Position + delta;
            xy = obj.Position;
            used = uint8(1);
        end

        function resetImpl(obj)
            obj.Position = single(zeros(2,1));
        end

        function validateInputsImpl(~,flow,quality,flowStatus, ...
                shutter,height,tofStatus)
            if numel(flow) ~= 2 || ~isscalar(quality) || ...
                    ~isscalar(flowStatus) || ~isscalar(shutter) || ...
                    ~isscalar(height) || ~isscalar(tofStatus)
                error('imu:FlowXYTracker:Shape', ...
                    'Expected Flow2 and five scalar sensor values.');
            end
        end

        function n = getNumInputsImpl(~), n = 6; end
        function n = getNumOutputsImpl(~), n = 2; end
        function varargout = getInputNamesImpl(~)
            varargout = {'Flow2','Quality','FlowStatus', ...
                'Shutter','ToFM','ToFValid'};
        end
        function varargout = getOutputNamesImpl(~)
            varargout = {'RelativeXY2','FlowUsed'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[2 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end
end
