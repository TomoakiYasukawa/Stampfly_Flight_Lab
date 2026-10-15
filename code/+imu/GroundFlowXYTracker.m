classdef GroundFlowXYTracker < matlab.System
    %GROUNDFLOWXYTRACKER Estimate east/north motion above a flat floor.
    % Optical flow is interpreted at the center of a downward camera.
    % Roll and pitch gyro motion is removed from the measured angular flow.
    % Corrected vertical height scales the remaining flow; orientation and the measured
    % height change resolve motion along the optical axis. Yaw-induced
    % image rotation and sensor-to-body offsets are not calibrated here.

    properties (Nontunable)
        SampleTime = 0.02
        XCountsPerRad = 385
        YCountsPerRad = 385
        MinQuality = 25
        MinHeightM = 0
        MaxHeightM = 2.0
        MaxHorizontalSpeedMps = 1.5
        MaxVerticalSpeedMps = 2.0
        MinDownProjection = 0.5
        IMUToBody = single([0 1 0;1 0 0;0 0 -1])
    end

    properties (Access = private)
        EastNorthM = single(zeros(2,1))
        LastHeightM = single(NaN)
    end

    methods (Access = protected)
        function [eastNorth,used,deltaENOut] = stepImpl(obj,flow,quality,flowStatus, ...
                shutter,rangeM,tofValid,heightM,heightValid,gyroRaw, ...
                imuValid,orientation,orientationValid)
            eastNorth = obj.EastNorthM;
            used = uint8(0);
            deltaENOut = single([NaN;NaN]);
            heightOK = heightValid ~= 0 && tofValid ~= 0 && ...
                isfinite(heightM) && heightM >= obj.MinHeightM && ...
                heightM <= obj.MaxHeightM;
            if ~heightOK
                obj.LastHeightM = single(NaN);
                return
            end
            previousHeight = obj.LastHeightM;
            obj.LastHeightM = single(heightM);
            if ~isfinite(previousHeight) || ~isfinite(rangeM) || ...
                    rangeM <= 0 || flowStatus == 0 || imuValid == 0 || ...
                    ~(quality >= obj.MinQuality || shutter < 31) || ...
                    ~all(isfinite(flow)) || ~all(isfinite(gyroRaw))
                return
            end
            [bodyToNED,orientationOK] = imu.bodyToNEDRotation( ...
                orientation,orientationValid);
            if ~orientationOK || ...
                    bodyToNED(3,3) < obj.MinDownProjection
                return
            end

            dt = double(obj.SampleTime);
            deltaHeight = double(heightM)-double(previousHeight);
            if abs(deltaHeight)/dt > obj.MaxVerticalSpeedMps
                return
            end
            gyroBody = double(obj.IMUToBody)*double(gyroRaw(:));
            % Empirical count axes: +X means right translation and -Y
            % means forward translation. For a central image feature,
            % pitch contributes +q*dt forward and roll -p*dt right.
            forwardAngle = -double(flow(2))/obj.YCountsPerRad;
            rightAngle = double(flow(1))/obj.XCountsPerRad;
            forwardM = (forwardAngle-gyroBody(2)*dt)*double(heightM);
            rightM = (rightAngle+gyroBody(1)*dt)*double(heightM);
            % On an infinite horizontal plane, measured height change
            % constrains translation along the camera's optical axis.
            downM = -(deltaHeight + bodyToNED(3,1)*forwardM + ...
                bodyToNED(3,2)*rightM)/bodyToNED(3,3);
            deltaNED = bodyToNED*[forwardM;rightM;downM];
            deltaEN = [deltaNED(2);deltaNED(1)];
            if ~all(isfinite(deltaEN)) || ...
                    norm(deltaEN)/dt > obj.MaxHorizontalSpeedMps
                return
            end
            obj.EastNorthM = obj.EastNorthM + single(deltaEN);
            eastNorth = obj.EastNorthM;
            used = uint8(1);
            deltaENOut = single(deltaEN);
        end

        function resetImpl(obj)
            obj.EastNorthM = single(zeros(2,1));
            obj.LastHeightM = single(NaN);
        end

        function validateInputsImpl(~,flow,quality,flowStatus,shutter, ...
                rangeM,tofValid,heightM,heightValid,gyroRaw,imuValid, ...
                orientation,orientationValid)
            if numel(flow) ~= 2 || numel(gyroRaw) ~= 3 || ...
                    numel(orientation) ~= 4 || ~isscalar(quality) || ...
                    ~isscalar(flowStatus) || ~isscalar(shutter) || ...
                    ~isscalar(rangeM) || ~isscalar(tofValid) || ...
                    ~isscalar(heightM) || ~isscalar(heightValid) || ...
                    ~isscalar(imuValid) || ~isscalar(orientationValid)
                error('imu:GroundFlowXYTracker:Shape', ...
                    'Unexpected flow, ToF, IMU, or orientation dimensions.');
            end
        end

        function n = getNumInputsImpl(~), n = 12; end
        function n = getNumOutputsImpl(~), n = 3; end
        function varargout = getInputNamesImpl(~)
            varargout = {'Flow2','Quality','FlowStatus','Shutter', ...
                'SlantRangeM','ToFValid','HeightM','HeightValid', ...
                'GyroRaw3','IMUValid','Orientation4','OrientationValid'};
        end
        function varargout = getOutputNamesImpl(~)
            varargout = {'EastNorthM2','FlowUsed','CorrectedDeltaEN2'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[2 1],[1 1],[2 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','uint8','single'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true,true};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end
end
