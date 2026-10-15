classdef ESPNowIMUTx < matlab.System & coder.ExternalDependency
    %ESPNOWIMUTX Initialize channel 3 and broadcast SFI frames.
    properties (Nontunable)
        Channel = uint8(3)
    end
    methods (Static)
        function name = getDescriptiveName()
            name = 'StampFly ESP-NOW IMU Transmitter';
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
        function [queued, ledMode] = stepImpl(~, frame)
            queued = uint8(0);
            ledMode = uint8(0);
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');
                bytes = uint8(frame(:));
                queued = coder.ceval('imu_tx_send',coder.rref(bytes), ...
                    uint16(numel(bytes)));
                ledMode = coder.ceval('imu_tx_led_mode');
            end
        end
        function validateInputsImpl(~, frame)
            if numel(frame) ~= 37 && numel(frame) ~= 63 && ...
                    numel(frame) ~= 93 && numel(frame) ~= 106 && ...
                    numel(frame) ~= 111 && numel(frame) ~= 114 && ...
                    numel(frame) ~= 182 && numel(frame) ~= 190
                error('imu:TxLength', ...
                    'Expected a supported SFI frame (37 to 190 bytes).');
            end
        end
        function n = getNumInputsImpl(~), n = 1; end
        function n = getNumOutputsImpl(~), n = 2; end
        function name = getInputNamesImpl(~), name = 'SFIFrame'; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'Queued','LEDMode'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'uint8','uint8'};
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
