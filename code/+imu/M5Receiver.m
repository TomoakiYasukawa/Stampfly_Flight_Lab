classdef M5Receiver < matlab.System & coder.ExternalDependency
    %M5RECEIVER ESP-NOW input and USB serial output for an M5StampS3.
    properties (Nontunable)
        Channel = uint8(3)
        BaudRate = uint32(921600)
    end
    methods (Static)
        function name = getDescriptiveName()
            name = 'M5StampS3 IMU Receiver';
        end
        function tf = isSupportedContext(~), tf = true; end
        function updateBuildInfo(buildInfo, context)
            if ~context.isCodeGenTarget('rtw'), return; end
            folder = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            buildInfo.addIncludePaths(folder);
            buildInfo.addSourcePaths(folder);
            buildInfo.addSourceFiles('imu_rx.cpp',folder);
        end
    end
    methods (Access = protected)
        function setupImpl(obj)
            if coder.target('Rtw')
                coder.cinclude('imu_rx.h');
                coder.ceval('imu_rx_init',uint8(obj.Channel),uint32(obj.BaudRate));
            end
        end
        function [forwarded, channel] = stepImpl(~)
            forwarded = uint32(0);
            channel = uint8(3);
            if coder.target('Rtw')
                coder.cinclude('imu_rx.h');
                coder.ceval('imu_rx_step',coder.wref(forwarded), ...
                    coder.wref(channel));
            end
        end
        function n = getNumInputsImpl(~), n = 0; end
        function n = getNumOutputsImpl(~), n = 2; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'FramesForwarded','RadioChannel'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'uint32','uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true};
        end
        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj,'Type','Discrete','SampleTime',0.01);
        end
    end
end
