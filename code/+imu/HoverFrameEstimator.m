classdef HoverFrameEstimator < matlab.System
    %HOVERFRAMEESTIMATOR Launch-relative heading, position, and velocity.
    % Flow is allowed to establish the XY origin only after several good
    % frames. Each loss of Flow invalidates XY control; reacquisition starts
    % a new local XY origin because motion during the gap was unobserved.

    properties (Nontunable)
        SampleTime = 0.02
        VelocityFilterTime = 0.2
        VerticalVelocityFilterTime = 0.2
        FlowReadyFrames = 3
        MaxVerticalSpeedMps = 2.0
        UseExternalVerticalTime = false
        UseExternalHeightFreshness = false
    end

    properties (Access = private)
        InitialYaw = single(0)
        HeadingCaptured = false
        OriginEastNorth = single(zeros(2,1))
        XYOriginCaptured = false
        GoodFlowCount = uint8(0)
        PositionXY = single(zeros(2,1))
        VelocityXY = single(zeros(2,1))
        LastHeight = single(NaN)
        HeldHeight = single(0)
        HeldRawVz = single(NaN)
        ElapsedSinceFresh = single(0)
        VelocityZ = single(0)
    end

    methods (Access = protected)
        function [position,velocity,initialYaw,relativeYaw,xyReady,zReady,rawVz] = ...
                stepImpl(obj,yaw,orientationValid,height,heightValid, ...
                eastNorth,flowUsed,deltaEastNorth,varargin)
            position = single(zeros(3,1));
            velocity = single(zeros(3,1));
            xyReady = uint8(0);
            zReady = uint8(0);
            rawVz = single(NaN);
            if obj.UseExternalVerticalTime
                verticalTime = single(varargin{1});
                if ~isfinite(verticalTime) || verticalTime <= 0
                    verticalTime = single(obj.VerticalVelocityFilterTime);
                end
            else
                verticalTime = single(obj.VerticalVelocityFilterTime);
            end
            heightFresh = true;
            if obj.UseExternalHeightFreshness
                heightFresh = varargin{1+double(obj.UseExternalVerticalTime)} ~= 0;
            end

            headingOK = orientationValid ~= 0 && isfinite(yaw);
            if headingOK && ~obj.HeadingCaptured
                obj.InitialYaw = single(yaw);
                obj.HeadingCaptured = true;
            end
            initialYaw = obj.InitialYaw;
            relativeYaw = single(0);
            if obj.HeadingCaptured && headingOK
                relativeYaw = atan2(sin(single(yaw)-initialYaw), ...
                    cos(single(yaw)-initialYaw));
            end

            heightOK = heightValid ~= 0 && isfinite(height) && height >= 0;
            if heightOK
                obj.HeldHeight = single(height);
                % The 50 Hz poll can repeat a range; count ticks until new data.
                obj.ElapsedSinceFresh = obj.ElapsedSinceFresh + single(obj.SampleTime);
                if heightFresh
                    if isfinite(obj.LastHeight)
                        rawVz = (single(height)-obj.LastHeight)/obj.ElapsedSinceFresh;
                        obj.HeldRawVz = rawVz;
                        if abs(rawVz) <= obj.MaxVerticalSpeedMps
                            alpha = obj.ElapsedSinceFresh/(verticalTime+obj.ElapsedSinceFresh);
                            obj.VelocityZ = obj.VelocityZ + alpha*(rawVz-obj.VelocityZ);
                        else
                            obj.VelocityZ = single(0);
                        end
                    else
                        obj.VelocityZ = single(0);
                    end
                    obj.LastHeight = single(height);
                    obj.ElapsedSinceFresh = single(0);
                else
                    rawVz = obj.HeldRawVz;
                end
                zReady = uint8(1);
            else
                obj.LastHeight = single(NaN);
                obj.HeldRawVz = single(NaN);
                obj.ElapsedSinceFresh = single(0);
                obj.VelocityZ = single(0);
            end
            position(3) = obj.HeldHeight;
            velocity(3) = obj.VelocityZ;

            flowOK = obj.HeadingCaptured && headingOK && flowUsed ~= 0 && ...
                all(isfinite(eastNorth)) && all(isfinite(deltaEastNorth));
            if ~flowOK
                obj.GoodFlowCount = uint8(0);
                obj.XYOriginCaptured = false;
                obj.VelocityXY(:) = single(0);
            else
                obj.GoodFlowCount = min(obj.GoodFlowCount+uint8(1), ...
                    uint8(obj.FlowReadyFrames));
                if obj.GoodFlowCount >= obj.FlowReadyFrames
                    if ~obj.XYOriginCaptured
                        obj.OriginEastNorth = single(eastNorth(:));
                        obj.PositionXY(:) = single(0);
                        obj.VelocityXY(:) = single(0);
                        obj.XYOriginCaptured = true;
                    else
                        delta = single(eastNorth(:))-obj.OriginEastNorth;
                        stepDelta = single(deltaEastNorth(:));
                        s = sin(initialYaw);
                        c = cos(initialYaw);
                        obj.PositionXY(1) = s*delta(1)+c*delta(2);
                        obj.PositionXY(2) = c*delta(1)-s*delta(2);
                        measuredVX = (s*stepDelta(1)+c*stepDelta(2))/single(obj.SampleTime);
                        measuredVY = (c*stepDelta(1)-s*stepDelta(2))/single(obj.SampleTime);
                        alpha = single(obj.SampleTime/(obj.VelocityFilterTime+obj.SampleTime));
                        obj.VelocityXY(1) = obj.VelocityXY(1) + ...
                            alpha*(measuredVX-obj.VelocityXY(1));
                        obj.VelocityXY(2) = obj.VelocityXY(2) + ...
                            alpha*(measuredVY-obj.VelocityXY(2));
                    end
                    xyReady = uint8(1);
                end
            end
            position(1:2) = obj.PositionXY;
            velocity(1:2) = obj.VelocityXY;
        end

        function resetImpl(obj)
            obj.InitialYaw = single(0);
            obj.HeadingCaptured = false;
            obj.OriginEastNorth(:) = single(0);
            obj.XYOriginCaptured = false;
            obj.GoodFlowCount = uint8(0);
            obj.PositionXY(:) = single(0);
            obj.VelocityXY(:) = single(0);
            obj.LastHeight = single(NaN);
            obj.HeldHeight = single(0);
            obj.HeldRawVz = single(NaN);
            obj.ElapsedSinceFresh = single(0);
            obj.VelocityZ = single(0);
        end

        function validateInputsImpl(obj,yaw,orientationValid,height,heightValid, ...
                eastNorth,flowUsed,deltaEastNorth,varargin)
            if ~isscalar(yaw) || ~isscalar(orientationValid) || ...
                    ~isscalar(height) || ~isscalar(heightValid) || ...
                    numel(eastNorth) ~= 2 || ~isscalar(flowUsed) || ...
                    numel(deltaEastNorth) ~= 2
                error('imu:HoverFrameEstimator:Shape', ...
                    'Expected yaw, height, validity, and two-element flow vectors.');
            end
            expectedOptional = double(obj.UseExternalVerticalTime) + ...
                double(obj.UseExternalHeightFreshness);
            if numel(varargin) ~= expectedOptional
                error('imu:HoverFrameEstimator:Shape', ...
                    'Unexpected number of optional inputs.');
            end
            if obj.UseExternalVerticalTime && ~isscalar(varargin{1})
                error('imu:HoverFrameEstimator:FilterTime', ...
                    'Expected a scalar vertical filter time.');
            end
            if obj.UseExternalHeightFreshness && ...
                    ~isscalar(varargin{expectedOptional})
                error('imu:HoverFrameEstimator:HeightFreshness', ...
                    'Expected a scalar height freshness flag.');
            end
        end

        function n = getNumInputsImpl(obj)
            n = 7 + double(obj.UseExternalVerticalTime) + ...
                double(obj.UseExternalHeightFreshness);
        end
        function n = getNumOutputsImpl(~), n = 7; end
        function varargout = getInputNamesImpl(obj)
            names = {'YawRad','OrientationValid','HeightM', ...
                'HeightValid','EastNorthM2','FlowUsed','DeltaEN2'};
            if obj.UseExternalVerticalTime
                names{end+1} = 'VerticalFilterTimeS';
            end
            if obj.UseExternalHeightFreshness
                names{end+1} = 'HeightFresh';
            end
            varargout = names;
        end
        function varargout = getOutputNamesImpl(~)
            varargout = {'PositionFRU3','VelocityFRU3','InitialYaw', ...
                'RelativeYaw','XYReady','ZReady','RawVerticalSpeed'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[3 1],[3 1],[1 1],[1 1],[1 1],[1 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','single','single','single','uint8','uint8','single'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false,false,false,false,false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true,true,true,true,true,true};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete','SampleTime',obj.SampleTime);
        end
    end
end
