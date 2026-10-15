classdef QuaternionToEuler < matlab.System
    %QUATERNIONTOEULER NED scalar-first quaternion to roll/pitch/yaw.
    properties (Nontunable)
        SampleTime = 0.04
    end
    methods (Access = protected)
        function euler = stepImpl(~,orientation)
            q = single(orientation(:));
            euler = zeros(3,1,'single');
            normSquared = sum(q.*q);
            if ~all(isfinite(q)) || normSquared < single(0.5)
                return
            end
            q = q ./ sqrt(normSquared);
            w = q(1); x = q(2); y = q(3); z = q(4);
            euler(1) = atan2(2*(w*x+y*z),1-2*(x*x+y*y));
            pitchSin = 2*(w*y-z*x);
            euler(2) = asin(min(max(pitchSin,single(-1)),single(1)));
            euler(3) = atan2(2*(w*z+x*y),1-2*(y*y+z*z));
        end
        function validateInputsImpl(~,orientation)
            if numel(orientation) ~= 4
                error('imu:QuaternionToEuler:Shape','Expected quaternion [w x y z].');
            end
        end
        function n = getNumInputsImpl(~), n = 1; end
        function n = getNumOutputsImpl(~), n = 1; end
        function name = getInputNamesImpl(~), name = 'NEDQuaternion4'; end
        function name = getOutputNamesImpl(~), name = 'RollPitchYaw3'; end
        function s = getOutputSizeImpl(~), s = [3 1]; end
        function t = getOutputDataTypeImpl(~), t = 'single'; end
        function c = isOutputComplexImpl(~), c = false; end
        function f = isOutputFixedSizeImpl(~), f = true; end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end
end
