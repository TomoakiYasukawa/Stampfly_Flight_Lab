classdef AttitudeInputAdapter < matlab.System
    %ATTITUDEINPUTADAPTER Align sensors and hold the last valid measurement.
    % Holds the latest BMM150 sample while running at the attitude rate.
    % Calibration parameters use the sensor frame; the filter inputs use
    % a common FRD body frame.
    % BMI270 raw axes are right, forward, up on StampFly. The body axes
    % are forward, right, down, as confirmed by the hand-tilt calibration
    % in project/new_hover/stampfly_textbook_params.m.

    properties (Nontunable)
        SampleTime = 0.04
        IMUToBody = single([0 1 0;1 0 0;0 0 -1])
        MagToBody = single([0 1 0;1 0 0;0 0 -1])
        MagBiasUT = zeros(3,1,'single')
        MagCorrection = eye(3,'single')
    end

    properties (Access = private)
        LastAccel = single([0;0;9.80665])
        LastGyro = zeros(3,1,'single')
        LastMag = single([1;0;0])
        IMUSeen = false
        MagSeen = false
    end

    methods (Access = protected)
        function [accelBody,gyroBody,magBody,ready] = ...
                stepImpl(obj,accel,gyro,mag,magStatus)
            a = single(accel(:));
            g = single(gyro(:));
            m = single(mag(:));
            if all(isfinite(a)) && all(isfinite(g)) && ...
                    sum(a.^2) > single(1)
                obj.LastAccel = a;
                obj.LastGyro = g;
                obj.IMUSeen = true;
            end
            if magStatus ~= 0 && all(isfinite(m)) && ...
                    sum(m.^2) > single(1)
                obj.LastMag = m;
                obj.MagSeen = true;
            end
            % BMI270 reports specific force (+g along raw up at rest).
            % Complementary Filter expects the gravity vector (+g down
            % in a level FRD body), so reverse the acceleration after
            % remapping the sensor axes.
            accelBody = -(single(obj.IMUToBody) * obj.LastAccel).';
            gyroBody = (single(obj.IMUToBody) * obj.LastGyro).';
            magBody = (single(obj.MagToBody) * ...
                (single(obj.MagCorrection) * ...
                (obj.LastMag - single(obj.MagBiasUT)))).';
            ready = uint8(obj.IMUSeen && obj.MagSeen);
        end

        function resetImpl(obj)
            obj.LastAccel = single([0;0;9.80665]);
            obj.LastGyro = zeros(3,1,'single');
            obj.LastMag = single([1;0;0]);
            obj.IMUSeen = false;
            obj.MagSeen = false;
        end

        function validateInputsImpl(~,accel,gyro,mag,magStatus)
            if numel(accel) ~= 3 || numel(gyro) ~= 3 || ...
                    numel(mag) ~= 3 || ~isscalar(magStatus)
                error('imu:AttitudeInputAdapter:Shape', ...
                    'Expected Accel3, Gyro3, Mag3, and MagStatus.');
            end
        end

        function validatePropertiesImpl(obj)
            if ~isscalar(obj.SampleTime) || ~isfinite(obj.SampleTime) || ...
                    obj.SampleTime <= 0 || ...
                    ~isequal(size(obj.IMUToBody),[3 3]) || ...
                    ~isequal(size(obj.MagToBody),[3 3]) || ...
                    ~isequal(size(obj.MagCorrection),[3 3]) || ...
                    numel(obj.MagBiasUT) ~= 3
                error('imu:AttitudeInputAdapter:Calibration', ...
                    'Axis and correction matrices must be 3-by-3.');
            end
        end

        function n = getNumInputsImpl(~), n = 4; end
        function n = getNumOutputsImpl(~), n = 4; end
        function varargout = getInputNamesImpl(~)
            varargout = {'Accel','Gyro','Mag','MagStatus'};
        end
        function varargout = getOutputNamesImpl(~)
            varargout = {'AccelBody','GyroBody','MagBody','Ready'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 3],[1 3],[1 3],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','single','single','uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false,false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true,true,true};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj, ...
                'Type','Discrete','SampleTime',obj.SampleTime);
        end
    end
end
