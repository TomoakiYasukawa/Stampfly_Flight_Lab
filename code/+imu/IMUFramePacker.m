classdef IMUFramePacker < matlab.System
    %IMUFRAMEPACKER Turn BMI270 outputs into a versioned CRC-protected frame.
    properties (Access = private)
        Sequence = uint16(0)
    end
    methods (Access = protected)
        function frame = stepImpl(obj, accel, gyro, status, timeSeconds)
            frame = imu.packFrame(obj.Sequence, timeSeconds, accel, gyro, status);
            obj.Sequence = uint16(bitand(uint32(obj.Sequence) + 1, ...
                uint32(65535)));
        end
        function resetImpl(obj)
            obj.Sequence = uint16(0);
        end
        function validateInputsImpl(~, accel, gyro, status, timeSeconds)
            if numel(accel) ~= 3 || numel(gyro) ~= 3 || ...
                    ~isscalar(status) || ~isscalar(timeSeconds)
                error('imu:InputShape', 'Expected Accel3, Gyro3, Status and time.');
            end
        end
        function n = getNumInputsImpl(~), n = 4; end
        function n = getNumOutputsImpl(~), n = 1; end
        function varargout = getInputNamesImpl(~)
            varargout = {'Accel','Gyro','IMUValid','TimeSeconds'};
        end
        function name = getOutputNamesImpl(~), name = 'Frame37'; end
        function s = getOutputSizeImpl(~), s = [37 1]; end
        function t = getOutputDataTypeImpl(~), t = 'uint8'; end
        function c = isOutputComplexImpl(~), c = false; end
        function f = isOutputFixedSizeImpl(~), f = true; end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete','SampleTime',0.04);
        end
    end
end
