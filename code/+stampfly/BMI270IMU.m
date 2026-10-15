classdef BMI270IMU < matlab.System & coder.ExternalDependency
    %BMI270IMU  StampFly BMI270 6-axis IMU (SPI) 窶・deployable device block.
    %
    %   MATLAB System block wrapping the Bosch BMI270 SensorAPI driver. On the
    %   ESP32-S3 target it reads the onboard BMI270 over SPI
    %   (MOSI=14 SCK=44 MISO=43 CS=46); during host simulation it returns zeros.
    %
    %   Outputs (sensor frame; apply body-axis remap downstream):
    %     Accel  [3x1] single  linear acceleration  (m/s^2)
    %     Gyro   [3x1] single  angular rate         (rad/s)
    %     Temp   [1x1] single  die temperature      (degC, chip updates at 10 Hz)
    %     Status [1x1] uint8   1 = accel AND gyro are new since the previous
    %                          step, 0 = repeated sample / not ready / error.
    %                          Accel/Gyro carry the latest registers either way.
    %
    %   Official settings: +/-8g, +/-2000dps, ODR400 Hz, normal filters.

    properties (Nontunable)
        % SampleTime  Block sample time (s). Default 400 Hz IMU rate.
        SampleTime = 0.0025
    end

    methods (Static)
        function name = getDescriptiveName()
            name = 'StampFly BMI270 IMU';
        end

        function tf = isSupportedContext(~)
            tf = true;   % host simulation (zeros) + ESP32 code generation
        end

        function updateBuildInfo(buildInfo, context)
            if ~context.isCodeGenTarget('rtw'); return; end
            root   = stampfly.BMI270IMU.libsRoot;
            srcDir = fullfile(root, 'src', 'bmi270');
            comDir = fullfile(root, 'src', 'common');
            buildInfo.addIncludePaths({srcDir, comDir});
            buildInfo.addSourcePaths({srcDir, comDir});
            buildInfo.addSourceFiles( ...
                {'bmi270_imu_driver.c', 'bmi270_spi_esp32.cpp', ...
                 'bmi270.c', 'bmi2.c'}, srcDir);
            % Shared StampFly SPI bus (global SPI, also used by the PMW3901)
            buildInfo.addSourceFiles('spi_esp32.cpp', comDir);
            % ESP32 Arduino SPI library (<SPI.h> + SPI.cpp, not in libcore.a)
            spiDir = stampfly.BMI270IMU.locateArduinoLib('SPI');
            if ~isempty(spiDir)
                buildInfo.addIncludePaths(spiDir);
                buildInfo.addSourcePaths(spiDir);
                buildInfo.addSourceFiles('SPI.cpp', spiDir);
            end
        end

        function r = libsRoot()
            % Root of StampFly_libs (parent of the +stampfly package folder).
            r = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        end

        function d = locateArduinoLib(libName)
            d = '';
            try
                base = fullfile( ...
                    codertarget.arduinobase.internal.getArduinoIDERoot, ...
                    'data', 'packages', 'esp32', 'hardware', 'esp32');
                hits = dir(fullfile(base, '*', 'libraries', libName, 'src'));
                if ~isempty(hits); d = hits(1).folder; end
            catch
            end
        end
    end

    methods (Access = protected)
        function setupImpl(~)
            if coder.target('Rtw')
                coder.cinclude('bmi270_imu_driver.h');
                coder.ceval('bmi270_imu_setup');
            end
        end

        function [accel, gyro, temp, status] = stepImpl(~)
            accel  = zeros(3, 1, 'single');
            gyro   = zeros(3, 1, 'single');
            temp   = single(0);
            status = uint8(0);
            if coder.target('Rtw')
                coder.cinclude('bmi270_imu_driver.h');
                coder.ceval('bmi270_imu_step', coder.wref(accel), ...
                    coder.wref(gyro), coder.wref(temp), coder.wref(status));
            end
        end

        function num = getNumInputsImpl(~);  num = 0; end
        function num = getNumOutputsImpl(~); num = 4; end

        function varargout = getOutputNamesImpl(~)
            varargout = {'Accel', 'Gyro', 'Temp', 'Status'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[3 1], [3 1], [1 1], [1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single', 'single', 'single', 'uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false, false, false, false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true, true, true, true};
        end

        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj, 'Type', 'Discrete', ...
                'SampleTime', obj.SampleTime);
        end
    end
end

