classdef VirtualStampFlyPlant < matlab.System
    %VIRTUALSTAMPFLYPLANT Illustrative rigid body and noiseless sensors.
    % This block is used only in StampFly_VirtualFlight_3D. Its thrust and
    % torque coefficients have not been calibrated against the real drone.
    % Motor order is front-right, front-left, rear-right, rear-left.
    % Internal world coordinates are north, east, down; body is FRD.

    properties (Nontunable)
        SampleTime = 0.004
        FloorHeightM = 0.03
        BatteryVoltageV = 3.8
        ReferenceVoltageV = 3.8
        HoverPWMAtReferenceV = 147
        MotorTimeConstantS = 0.04
        LinearDampingPerS = 0.5
        RollPitchAccelPerCount = 0.15
        YawAccelPerCount = 0.08
        AngularDampingPerS = 4
        GravityOnlyAccelerometer = true
    end

    properties (Access = private)
        PositionNED = single([0;0;-0.03])
        VelocityNED = single(zeros(3,1))
        AttitudeQ = single([1;0;0;0])
        BodyRate = single(zeros(3,1))
        WorldAccel = single(zeros(3,1))
        MotorPWM = single(zeros(4,1))
    end

    methods (Access = protected)
        function setupImpl(obj)
            resetImpl(obj);
        end

        function [rawAccel,rawGyro,imuValid,rawMag,magStatus, ...
                tofRange,tofStatus,tofValid,tofFresh,flowCounts, ...
                flowQuality,flowStatus,flowShutter,batteryV,batteryValid, ...
                translation,rotation,positionNED,velocityNED] = ...
                stepImpl(obj,motorCommands)
            dt = single(obj.SampleTime);
            gravity = single([0;0;9.80665]);
            sensorMap = single([0 1 0;1 0 0;0 0 -1]);
            R = rotationMatrix(obj.AttitudeQ);
            height = max(single(0),-obj.PositionNED(3));
            if obj.GravityOnlyAccelerometer
                % Ideal tilt reference for a baseline control test. A real
                % accelerometer also sees translational acceleration.
                specificForce = -R.'*gravity;
            else
                specificForce = R.'*(obj.WorldAccel-gravity);
            end
            rawAccel = (sensorMap*specificForce).';
            rawGyro = (sensorMap*obj.BodyRate).';
            imuValid = uint8(1);
            rawMag = (sensorMap*(R.'*single([25;0;42]))).';
            magStatus = uint8(1);
            downProjection = max(single(0.5),R(3,3));
            tofRange = height/downProjection;
            tofStatus = uint8(0);
            tofValid = uint8(height <= single(2.0) && R(3,3) > 0.5);
            tofFresh = uint8(1);

            % Invert the equations in GroundFlowXYTracker for ideal flow.
            bodyVelocity = R.'*obj.VelocityNED;
            imageHeight = max(single(0.04),height);
            flowX = single(385)*(bodyVelocity(2)*single(0.02)/ ...
                imageHeight-obj.BodyRate(1)*single(0.02));
            flowY = -single(385)*(bodyVelocity(1)*single(0.02)/ ...
                imageHeight+obj.BodyRate(2)*single(0.02));
            flowCounts = int16(round([flowX flowY]));
            flowQuality = uint8(100);
            flowStatus = uint8(height > 0.04);
            flowShutter = uint8(50);
            batteryV = single(obj.BatteryVoltageV);
            batteryValid = uint8(1);

            % The actor is set to AERO coordinates (north, east, down).
            translation = obj.PositionNED.';
            rotation = eulerAngles(obj.AttitudeQ).';
            positionNED = obj.PositionNED.';
            velocityNED = obj.VelocityNED.';

            % Sensor output uses the preceding state, so the feedback loop
            % has one 4 ms delay and no direct feedthrough.
            requested = single(motorCommands(:));
            requested = min(max(requested,single(0)),single(255));
            lagFraction = dt/(single(obj.MotorTimeConstantS)+dt);
            obj.MotorPWM = obj.MotorPWM+ ...
                lagFraction*(requested-obj.MotorPWM);
            effectivePWM = obj.MotorPWM* ...
                single(obj.BatteryVoltageV/obj.ReferenceVoltageV);
            thrustAcceleration = single(9.80665)* ...
                mean(effectivePWM)/single(obj.HoverPWMAtReferenceV);
            R = rotationMatrix(obj.AttitudeQ);
            accel = gravity-R(:,3)*thrustAcceleration- ...
                single(obj.LinearDampingPerS)*obj.VelocityNED;
            obj.VelocityNED = obj.VelocityNED+dt*accel;
            obj.PositionNED = obj.PositionNED+dt*obj.VelocityNED;
            if obj.PositionNED(3) > -single(obj.FloorHeightM)
                obj.PositionNED(3) = -single(obj.FloorHeightM);
                obj.VelocityNED(3) = min(obj.VelocityNED(3),single(0));
                accel(3) = single(0);
            end
            obj.WorldAccel = accel;

            fr = effectivePWM(1); fl = effectivePWM(2);
            rr = effectivePWM(3); rl = effectivePWM(4);
            angularAccel = single([ ...
                obj.RollPitchAccelPerCount*(fl+rl-fr-rr); ...
                obj.RollPitchAccelPerCount*(fr+fl-rr-rl); ...
                obj.YawAccelPerCount*(fr+rl-fl-rr)])- ...
                single(obj.AngularDampingPerS)*obj.BodyRate;
            obj.BodyRate = obj.BodyRate+dt*angularAccel;
            q = obj.AttitudeQ;
            p = obj.BodyRate(1); qrate = obj.BodyRate(2);
            r = obj.BodyRate(3);
            qdot = single(0.5)*single([ ...
                -q(2)*p-q(3)*qrate-q(4)*r; ...
                 q(1)*p+q(3)*r-q(4)*qrate; ...
                 q(1)*qrate-q(2)*r+q(4)*p; ...
                 q(1)*r+q(2)*qrate-q(3)*p]);
            q = q+dt*qdot;
            obj.AttitudeQ = q/norm(q);
        end

        function resetImpl(obj)
            obj.PositionNED = single([0;0;-obj.FloorHeightM]);
            obj.VelocityNED = single(zeros(3,1));
            obj.AttitudeQ = single([1;0;0;0]);
            obj.BodyRate = single(zeros(3,1));
            obj.WorldAccel = single(zeros(3,1));
            obj.MotorPWM = single(zeros(4,1));
        end

        function validateInputsImpl(~,motorCommands)
            if numel(motorCommands) ~= 4
                error('imu:VirtualStampFlyPlant:MotorCount', ...
                    'Expected four motor commands in FR FL RR RL order.');
            end
        end

        function feedthrough = isInputDirectFeedthroughImpl(~)
            feedthrough = false;
        end
        function n = getNumInputsImpl(~), n = 1; end
        function n = getNumOutputsImpl(~), n = 19; end
        function name = getInputNamesImpl(~), name = 'MotorCommands4'; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'RawAccel3','RawGyro3','IMUValid', ...
                'RawMag3','MagStatus','ToFRangeM','ToFStatus', ...
                'ToFValid','ToFFresh','FlowCounts2','FlowQuality', ...
                'FlowStatus','FlowShutter','BatteryVoltageV', ...
                'BatteryValid','Translation3','Rotation3', ...
                'PositionNED3','VelocityNED3'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 3],[1 3],[1 1],[1 3],[1 1], ...
                [1 1],[1 1],[1 1],[1 1],[1 2],[1 1],[1 1], ...
                [1 1],[1 1],[1 1],[1 3],[1 3],[1 3],[1 3]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','single','uint8','single', ...
                'uint8','single','uint8','uint8','uint8', ...
                'int16','uint8','uint8','uint8','single', ...
                'uint8','single','single','single','single'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = repmat({false},1,19);
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = repmat({true},1,19);
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end
end

function R = rotationMatrix(q)
% Unit quaternion [w x y z], body FRD to world NED.
w=q(1); x=q(2); y=q(3); z=q(4);
R = single([ ...
    1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w); ...
    2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w); ...
    2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]);
end

function angles = eulerAngles(q)
% Roll, pitch, yaw in radians, using the same FRD/NED convention.
w=q(1); x=q(2); y=q(3); z=q(4);
roll = atan2(2*(w*x+y*z),1-2*(x*x+y*y));
pitchArgument = min(max(2*(w*y-z*x),single(-1)),single(1));
pitch = asin(pitchArgument);
yaw = atan2(2*(w*z+x*y),1-2*(y*y+z*z));
angles = single([roll;pitch;yaw]);
end
