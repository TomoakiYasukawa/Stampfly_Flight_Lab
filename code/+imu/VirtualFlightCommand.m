classdef VirtualFlightCommand < matlab.System
    %VIRTUALFLIGHTCOMMAND Time-based commands for the virtual flight only.
    % Output types and order match imu.FlightCommandReceiver exactly.

    properties (Nontunable)
        SampleTime = 0.004
        TakeoffTimeS = 1.0
        LandingTimeS = 8.0
        ClimbMps = 0.10
        HoverHeightM = 0.15
        LandMps = 0.08
    end

    properties (Access = private)
        Tick = uint32(0)
    end

    methods (Access = protected)
        function [operation,sequence,climbMps,hoverM,landMps, ...
                linkAlive,emergencyStop] = stepImpl(obj)
            elapsed = double(obj.Tick)*obj.SampleTime;
            operation = uint8(0);
            sequence = uint16(0);
            if elapsed >= obj.LandingTimeS
                operation = uint8(2);
                sequence = uint16(2);
            elseif elapsed >= obj.TakeoffTimeS
                operation = uint8(1);
                sequence = uint16(1);
            end
            climbMps = single(obj.ClimbMps);
            hoverM = single(obj.HoverHeightM);
            landMps = single(obj.LandMps);
            linkAlive = uint8(1);
            emergencyStop = uint8(0);
            obj.Tick = obj.Tick+uint32(1);
        end

        function resetImpl(obj)
            obj.Tick = uint32(0);
        end

        function n = getNumInputsImpl(~), n = 0; end
        function n = getNumOutputsImpl(~), n = 7; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'Operation','CommandSequence','ClimbMps', ...
                'HoverM','LandMps','LinkAlive','EmergencyStop'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = repmat({[1 1]},1,7);
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'uint8','uint16','single','single','single', ...
                'uint8','uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = repmat({false},1,7);
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = repmat({true},1,7);
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete', ...
                'SampleTime',obj.SampleTime);
        end
    end
end
