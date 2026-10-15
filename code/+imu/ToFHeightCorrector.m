classdef ToFHeightCorrector < matlab.System
    %TOFHEIGHTCORRECTOR Project the downward ToF range onto a flat floor.
    % The floor is an infinite horizontal plane. The sensor optical axis
    % is the body's +Z (down) axis. The output is height at the sensor.

    methods (Access = protected)
        function [heightM,heightValid] = stepImpl(~,rangeM,tofValid, ...
                orientation,orientationValid)
            [height,valid] = imu.correctToFHeight( ...
                rangeM,tofValid,orientation,orientationValid);
            heightM = single(height);
            heightValid = uint8(valid);
        end

        function validateInputsImpl(~,rangeM,tofValid, ...
                orientation,orientationValid)
            if ~isscalar(rangeM) || ~isscalar(tofValid) || ...
                    numel(orientation) ~= 4 || ~isscalar(orientationValid)
                error('imu:ToFHeightCorrector:Shape', ...
                    'Expected range, valid, quaternion4, and orientation valid.');
            end
        end

        function n = getNumInputsImpl(~), n = 4; end
        function n = getNumOutputsImpl(~), n = 2; end
        function varargout = getInputNamesImpl(~)
            varargout = {'SlantRangeM','ToFValid','Orientation4', ...
                'OrientationValid'};
        end
        function varargout = getOutputNamesImpl(~)
            varargout = {'HeightM','HeightValid'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 1],[1 1]};
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
            st = createSampleTime(obj,'Type','Discrete','SampleTime',0.02);
        end
    end
end
