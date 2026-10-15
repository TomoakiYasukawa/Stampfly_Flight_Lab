classdef VirtualNoHeightTuning < matlab.System
    %VIRTUALNOHEIGHTTUNING Keep source defaults in the virtual model.
    % Output types and order match imu.FlightTuningReceiver.

    methods (Access = protected)
        function [values,sequence,pending] = stepImpl(~)
            values = zeros(9,1,'single');
            sequence = uint16(0);
            pending = uint8(0);
        end
        function n = getNumInputsImpl(~), n = 0; end
        function n = getNumOutputsImpl(~), n = 3; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'Requested9','Sequence','Pending'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[9 1],[1 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','uint16','uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true,true};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete','SampleTime',0.02);
        end
    end
end
