classdef HeightTuningManager < matlab.System
    %HEIGHTTUNINGMANAGER Apply complete height settings only while idle.
    % Status: 0 no request, 1 applied, 2 busy, 3 invalid.
    properties (Access = private)
        Active = single(zeros(9,1))
        Initialized = false
        SeenSequence = false
        LastSequence = uint16(0)
        LastStatus = uint8(0)
    end
    methods (Access = protected)
        function [active,ackSequence,ackStatus] = stepImpl(obj,request, ...
                sequence,pending,flightState,pwmEnabled,defaults)
            if ~obj.Initialized
                obj.Active = single(defaults(:));
                obj.Initialized = true;
            end
            if pending ~= 0 && (~obj.SeenSequence || sequence ~= obj.LastSequence)
                obj.LastSequence = uint16(sequence);
                obj.SeenSequence = true;
                if flightState ~= 0 || pwmEnabled ~= 0
                    obj.LastStatus = uint8(2);
                elseif ~imu.HeightTuningManager.validParameters(request)
                    obj.LastStatus = uint8(3);
                else
                    obj.Active = single(request(:));
                    obj.LastStatus = uint8(1);
                end
            end
            active = obj.Active;
            ackSequence = obj.LastSequence;
            ackStatus = obj.LastStatus;
        end
        function resetImpl(obj)
            obj.Active(:) = single(0);
            obj.Initialized = false;
            obj.SeenSequence = false;
            obj.LastSequence = uint16(0);
            obj.LastStatus = uint8(0);
        end
        function validateInputsImpl(~,request,sequence,pending, ...
                flightState,pwmEnabled,defaults)
            if numel(request) ~= 9 || numel(defaults) ~= 9 || ...
                    ~isscalar(sequence) || ~isscalar(pending) || ...
                    ~isscalar(flightState) || ~isscalar(pwmEnabled)
                error('imu:HeightTuningShape','Expected two nine-element vectors and four scalars.');
            end
        end
        function n = getNumInputsImpl(~), n = 6; end
        function n = getNumOutputsImpl(~), n = 3; end
        function varargout = getInputNamesImpl(~)
            varargout = {'Requested9','RequestSequence','RequestPending', ...
                'FlightState','PWMEnable','Defaults9'};
        end
        function varargout = getOutputNamesImpl(~)
            varargout = {'Active9','AckSequence','AckStatus'};
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
    methods (Static, Access = private)
        function ok = validParameters(p)
            values = single(p(:));
            [lower,upper] = imu.heightTuningLimits();
            ok = numel(values) == 9 && all(isfinite(values)) && ...
                all(values >= lower) && all(values <= upper);
        end
    end
end
