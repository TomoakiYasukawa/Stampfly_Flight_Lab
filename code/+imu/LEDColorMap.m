classdef LEDColorMap < matlab.System
    %LEDCOLORMAP Map PC monitoring state to the StampFly GPIO39 RGB LED.
    %   0: off, 1: green (receiving), 2: red (recording).

    methods (Access = protected)
        function rgb = stepImpl(~, mode)
            rgb = zeros(3,1,'uint8');
            if uint8(mode) == uint8(1)
                rgb(2) = uint8(20);
            elseif uint8(mode) == uint8(2)
                rgb(1) = uint8(20);
            end
        end

        function validateInputsImpl(~, mode)
            if ~isscalar(mode) || ~isnumeric(mode)
                error('imu:LEDMode','LED mode must be numeric and scalar.');
            end
        end

        function n = getNumInputsImpl(~), n = 1; end
        function n = getNumOutputsImpl(~), n = 1; end
        function name = getInputNamesImpl(~), name = 'LEDMode'; end
        function name = getOutputNamesImpl(~), name = 'RGB'; end
        function s = getOutputSizeImpl(~), s = [3 1]; end
        function t = getOutputDataTypeImpl(~), t = 'uint8'; end
        function c = isOutputComplexImpl(~), c = false; end
        function f = isOutputFixedSizeImpl(~), f = true; end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete','SampleTime',0.02);
        end
    end
end
