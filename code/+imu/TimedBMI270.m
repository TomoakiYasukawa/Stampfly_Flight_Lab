classdef TimedBMI270 < stampfly.BMI270IMU
    %TIMEDBMI270 BMI270 with a timestamp before its SPI read.
    % This is used only by the motor-free diagnostic model.
    methods (Static)
        function name = getDescriptiveName()
            name = 'StampFly timed BMI270 IMU';
        end
        function updateBuildInfo(buildInfo,context)
            stampfly.BMI270IMU.updateBuildInfo(buildInfo,context);
            if ~context.isCodeGenTarget('rtw'), return; end
            projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            sourceFolder = fullfile(projectRoot,'src');
            buildInfo.addIncludePaths(sourceFolder);
            buildInfo.addSourcePaths(sourceFolder);
            buildInfo.addSourceFiles('hover_rate_diag.cpp',sourceFolder);
        end
    end

    methods (Access = protected)
        function setupImpl(obj)
            setupImpl@stampfly.BMI270IMU(obj);
            if coder.target('Rtw')
                coder.cinclude('hover_rate_diag.h');
                coder.ceval('hover_rate_diag_setup');
            end
        end
        function [accel,gyro,temp,status,startUs] = stepImpl(obj)
            startUs = uint32(0);
            if coder.target('Rtw')
                coder.cinclude('hover_rate_diag.h');
                startUs = coder.ceval('hover_rate_diag_now_us');
            end
            [accel,gyro,temp,status] = stepImpl@stampfly.BMI270IMU(obj);
        end
        function n = getNumOutputsImpl(~), n = 5; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'Accel','Gyro','Temp','Status','StartUs'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[3 1],[3 1],[1 1],[1 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','single','single','uint8','uint32'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false,false,false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true,true,true,true};
        end
    end
end
