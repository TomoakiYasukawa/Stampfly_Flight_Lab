classdef FlightCommandReceiver < matlab.System & coder.ExternalDependency
    %FLIGHTCOMMANDRECEIVER Read the latest CRC-checked ESP-NOW control.
    % Operation: 0 none, 1 takeoff, 2 landing, 3 emergency, 4 reset.
    properties (Nontunable)
        Channel = uint8(3)
    end
    methods (Static)
        function name = getDescriptiveName()
            name = 'StampFly Flight Command Receiver';
        end
        function tf = isSupportedContext(~), tf = true; end
        function updateBuildInfo(buildInfo, context)
            if ~context.isCodeGenTarget('rtw'), return; end
            folder = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            buildInfo.addIncludePaths(folder);
            buildInfo.addSourcePaths(folder);
            buildInfo.addSourceFiles('imu_tx.cpp',folder);
        end
    end
    methods (Access = protected)
        function setupImpl(obj)
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');
                coder.ceval('imu_tx_init',uint8(obj.Channel));
            end
        end
        function [operation,sequence,climbMps,hoverM,landMps,linkAlive,emergencyStop] = stepImpl(~)
            operation = uint8(0);
            sequence = uint16(0);
            climb = uint16(100);
            hover = uint16(150);
            land = uint16(80);
            linkAlive = uint8(0);
            emergencyStop = uint8(0);
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');
                coder.ceval('imu_tx_flight_command',coder.wref(operation), ...
                    coder.wref(sequence),coder.wref(climb), ...
                    coder.wref(hover),coder.wref(land), ...
                    coder.wref(linkAlive),coder.wref(emergencyStop));
            end
            climbMps = single(climb)*single(0.001);
            hoverM = single(hover)*single(0.001);
            landMps = single(land)*single(0.001);
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
            st = createSampleTime(obj,'Type','Discrete','SampleTime',0.004);
        end
    end
end
