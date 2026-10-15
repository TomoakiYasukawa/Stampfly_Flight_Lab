classdef VL53L3CX < matlab.System & coder.ExternalDependency
    %VL53L3CX  StampFly ST VL53L3CX time-of-flight distance sensor (I2C).
    %
    %   MATLAB System block wrapping ST's full VL53L3CX Ultra-Lite Driver
    %   (ULD, histogram ranging / multi-target / crosstalk) on the shared
    %   StampFly I2C bus (Wire1: SDA=3 SCL=4 @ 400 kHz). The bottom sensor
    %   uses the exact ULD 1.2.8 and acquisition sequence from the official
    %   M5StampFly firmware. Front and custom sensors retain the stm32duino
    %   VL53LX implementation. On the ESP32-S3 target it reads the device; in
    %   host simulation it returns zeros.
    %
    %   Which target is reported
    %   ------------------------
    %   The VL53L3CX histogram engine can see up to four objects in one
    %   measurement. TargetSelect picks which valid one becomes Range:
    %     - 'Auto'     : Bottom sensor -> farthest, Front/Custom -> nearest
    %     - 'Farthest' : right for the downward sensor. The nearer returns are
    %                    the crosstalk phantom off the cover/frame, and the
    %                    floor is the farthest valid target (this is what the
    %                    M5StampFly firmware does).
    %     - 'Nearest'  : right for the forward sensor, where the closest
    %                    obstacle is the one to react to.
    %
    %   Outputs:
    %     Range       [1x1] single  distance to target          (m)
    %     RangeStatus [1x1] uint8    WHY, from the sensor (see table below)
    %     Status      [1x1] uint8    1 = Range is valid, 0 = dropout/not ready/error
    %
    %   Status vs RangeStatus
    %   ---------------------
    %   Status is the gate: one bit, computed by the driver, answering "can I use
    %   Range this step?". RangeStatus is the diagnosis: the sensor's own quality
    %   code for the measurement, or a driver fault code. Use Status to gate the
    %   signal and RangeStatus only to work out why it went low.
    %
    %     RangeStatus  meaning                              Status
    %       0          valid measurement                      1
    %       6          valid, no wrap check                   1
    %      11          valid, merged pulse                    1
    %       1          sigma (noise) fail                     0
    %       2          signal too weak                        0
    %      13          below minimum range                    0
    %     255          no target found                        0
    %      90          I2C / data-ready read error            0
    %     101..105     driver setup failed at stage 1..5      0
    %                  (boot, DataInit, DistanceMode,
    %                   TimingBudget, StartMeasurement;
    %                   Range then carries the ULD error code)
    %
    %   Anything <= 14 or == 255 comes from the sensor; >= 90 is the driver. The
    %   driver band sits above 14 deliberately: the ULD reuses 11/13/14 for real
    %   measurement results, so a lower band could not be told apart from one.
    %
    %   StampFly carries two VL53L3CX (downward + forward) on the shared I2C
    %   bus. Choose which one this block reads with the Sensor parameter:
    %     - 'Bottom (0x29)' : downward altitude sensor (XSHUT GPIO 7)
    %     - 'Front (0x2A)'  : forward sensor           (XSHUT GPIO 9)
    %     - 'Custom (I2CAddress)' : any 7-bit address from the I2CAddress field
    %   Drop one block per sensor (one Bottom, one Front) and leave
    %   PerformBringUp on. Every unit powers up at 0x29 and the part has no
    %   address-select pin, so the blocks' bring-up enables them one at a time
    %   via XSHUT and re-addresses the front sensor to 0x2A (mirrors the
    %   M5StampFly firmware tof_init); the sequence is idempotent, so both
    %   blocks may have PerformBringUp set.
    %
    %   Status is a VALIDITY flag, not a freshness flag: it stays high between
    %   measurements while the last range is still good, and drops to 0 on a
    %   dropout, an I2C error or a failed setup. Gate on it directly (Range AND
    %   Status). It does NOT mark the step on which a new measurement arrived,
    %   so a filter correction driven off it will re-consume the same range
    %   several times per measurement; derive an edge from Range changing if
    %   that matters.
    %
    %   Update rate
    %   -----------
    %   The bottom sensor uses the official fixed 33 ms timing budget
    %   (~30 Hz). TimingBudget controls the front and custom sensor paths.
    %
    %     TimingBudget   rate     note
    %       33 ms       ~30 Hz    ULD / M5StampFly default
    %       20 ms       ~50 Hz    default here
    %       15 ms       ~65 Hz
    %       10 ms      ~100 Hz    short range only; check RangeStatus
    %
    %   Below ~1.7 ms the driver rejects the budget (RangeStatus 104). ABOVE that
    %   it is always accepted, even when the sensor cannot integrate enough
    %   signal - max range and accuracy then degrade silently and RangeStatus
    %   starts reporting sigma (1) / signal (2) failures. Lower it one step at a
    %   time and watch RangeStatus. Note also that the ULD merges up to six
    %   consecutive histograms for range extension, so the range carries some
    %   inherent smoothing on top of the budget period.
    %
    %   Note: the bottom path is backed by the official M5StampFly ULD 1.2.8.
    %   The front/custom path uses the ST/stm32duino ULD in src/vl53l3cx/uld.

    properties (Nontunable)
        % Sensor  Which StampFly ToF this block reads. 'Bottom (0x29)' is the
        % downward altitude sensor; 'Front (0x2A)' is the forward sensor;
        % 'Custom (I2CAddress)' uses the I2CAddress property below.
        Sensor = 'Bottom (0x29)'
        % I2CAddress  7-bit I2C address, used only when Sensor = Custom.
        I2CAddress = uint8(41)
        % SampleTime  Block poll period (s). Keep this FASTER than TimingBudget
        % so each completed measurement is caught promptly and Range updates
        % regularly. Polling at ~the measurement period aliases and makes updates
        % look random. Default 100 Hz.
        SampleTime = 0.01
        % DistanceMode  Ranging profile. 'Auto' keeps the historical StampFly
        % split (bottom = Medium, front = Long). Shorter modes tolerate a shorter
        % TimingBudget and reject ambient light better, at less maximum range.
        DistanceMode = 'Auto (bottom Medium / front Long)'
        % TimingBudget  Measurement timing budget (ms) - this is the update-rate
        % knob; rate ~= 1000/TimingBudget. See the rate table in the block help
        % before lowering it.
        TimingBudget = 20
        % PerformBringUp  Run the StampFly two-ToF XSHUT bring-up + re-address
        % (GPIO 7/9) once before configuring. Idempotent; leave true on StampFly,
        % set false if the sensors are enabled/addressed by other init.
        PerformBringUp (1,1) logical = true
        % TargetSelect  Which valid object becomes Range when the sensor sees
        % several. 'Auto' = farthest for Bottom (skips the cover crosstalk
        % phantom, tracks the floor), nearest for Front/Custom (closest
        % obstacle).
        TargetSelect = 'Auto (bottom Farthest / front Nearest)'
    end

    properties (Constant, Hidden)
        % Dropdown choices shown for the Sensor parameter in the block dialog.
        SensorSet = matlab.system.StringSet( ...
            {'Bottom (0x29)', 'Front (0x2A)', 'Custom (I2CAddress)'})
        DistanceModeSet = matlab.system.StringSet( ...
            {'Auto (bottom Medium / front Long)', 'Short', 'Medium', 'Long'})
        TargetSelectSet = matlab.system.StringSet( ...
            {'Auto (bottom Farthest / front Nearest)', 'Nearest', 'Farthest'})
    end

    methods (Static)
        function name = getDescriptiveName()
            name = 'StampFly VL53L3CX ToF';
        end

        function tf = isSupportedContext(~)
            tf = true;
        end

        function updateBuildInfo(buildInfo, context)
            if ~context.isCodeGenTarget('rtw'); return; end
            root   = stampfly.VL53L3CX.libsRoot;
            srcDir = fullfile(root, 'src', 'vl53l3cx');
            uldDir = fullfile(srcDir, 'uld');
            comDir = fullfile(root, 'src', 'common');
            officialDir = fullfile(root, 'third_party', ...
                'M5StampFly_official_5d6c3417', 'lib', 'vl53l3c');
            buildInfo.addIncludePaths( ...
                {srcDir, uldDir, comDir, officialDir});
            buildInfo.addSourcePaths( ...
                {srcDir, uldDir, comDir, officialDir});
            % StampFly C wrapper + the ST/stm32duino VL53L3CX ULD (used unmodified)
            buildInfo.addSourceFiles('vl53l3cx_uld_wrapper.cpp', srcDir);
            buildInfo.addSourceFiles('vl53lx_class.cpp', uldDir);
            buildInfo.addSourceFiles('i2c_esp32.cpp', comDir);
            % Exact M5StampFly ULD 1.2.8 path used for the bottom sensor.
            officialSources = { ...
                'vl53lx_api.c', ...
                'vl53lx_api_calibration.c', ...
                'vl53lx_api_core.c', ...
                'vl53lx_api_debug.c', ...
                'vl53lx_api_preset_modes.c', ...
                'vl53lx_core.c', ...
                'vl53lx_core_support.c', ...
                'vl53lx_dmax.c', ...
                'vl53lx_hist_algos_gen3.c', ...
                'vl53lx_hist_algos_gen4.c', ...
                'vl53lx_hist_char.c', ...
                'vl53lx_hist_core.c', ...
                'vl53lx_hist_funcs.c', ...
                'vl53lx_nvm.c', ...
                'vl53lx_nvm_debug.c', ...
                'vl53lx_platform.c', ...
                'vl53lx_platform_init.c', ...
                'vl53lx_platform_ipp.c', ...
                'vl53lx_platform_log.c', ...
                'vl53lx_register_funcs.c', ...
                'vl53lx_sigma_estimate.c', ...
                'vl53lx_silicon_core.c', ...
                'vl53lx_wait.c', ...
                'vl53lx_xtalk.c'};
            buildInfo.addSourceFiles( ...
                'vl53l3cx_bottom_official128_wrapper.cpp', srcDir);
            buildInfo.addSourceFiles(officialSources, officialDir);
            % ESP32 Arduino Wire library (<Wire.h> + Wire.cpp, not in libcore.a)
            wireDir = stampfly.VL53L3CX.locateArduinoLib('Wire');
            if ~isempty(wireDir)
                buildInfo.addIncludePaths(wireDir);
                buildInfo.addSourcePaths(wireDir);
                buildInfo.addSourceFiles('Wire.cpp', wireDir);
            end
        end

        function r = libsRoot()
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
        function addr = resolveAddr(obj)
            % Map the Sensor dropdown to a 7-bit address (Custom -> I2CAddress).
            switch obj.Sensor
                case 'Bottom (0x29)';        addr = uint8(41);   % 0x29 downward
                case 'Front (0x2A)';         addr = uint8(42);   % 0x2A forward
                otherwise;                   addr = uint8(obj.I2CAddress);
            end
        end

        function dm = resolveDistanceMode(obj)
            % Map the dropdown to the driver's VL53L3CX_DM_* selector.
            switch obj.DistanceMode
                case 'Short';   dm = uint8(1);
                case 'Medium';  dm = uint8(2);
                case 'Long';    dm = uint8(3);
                otherwise;      dm = uint8(0);   % Auto: per-sensor default
            end
        end

        function ts = resolveTargetSelect(obj)
            % Map the dropdown to the driver's VL53L3CX_TS_* selector.
            switch obj.TargetSelect
                case 'Nearest';  ts = uint8(1);
                case 'Farthest'; ts = uint8(2);
                otherwise;       ts = uint8(0);   % Auto: per-sensor default
            end
        end

        function setupImpl(obj)
            if coder.target('Rtw')
                if strcmp(obj.Sensor, 'Bottom (0x29)')
                    coder.cinclude( ...
                        'vl53l3cx_bottom_official128_driver.h');
                    coder.ceval( ...
                        'vl53l3cx_bottom_official128_setup');
                else
                    coder.cinclude('vl53l3cx_driver.h');
                    if obj.PerformBringUp
                        % Idempotent XSHUT sequence.
                        coder.ceval('vl53l3cx_bringup');
                    end
                    coder.ceval('vl53l3cx_setup', obj.resolveAddr(), ...
                        obj.resolveDistanceMode(), ...
                        uint32(obj.TimingBudget * 1000), ...
                        obj.resolveTargetSelect());
                end
            end
        end

        function [range, rangeStatus, status] = stepImpl(obj)
            range       = single(0);
            rangeStatus = uint8(0);
            status      = uint8(0);
            if coder.target('Rtw')
                if strcmp(obj.Sensor, 'Bottom (0x29)')
                    rawRange = single(0);
                    freshValid = uint8(0);
                    newData = uint8(0);
                    metrics = zeros(10, 1, 'single');
                    coder.cinclude( ...
                        'vl53l3cx_bottom_official128_driver.h');
                    coder.ceval( ...
                        'vl53l3cx_bottom_official128_step', ...
                        coder.wref(range), coder.wref(rawRange), ...
                        coder.wref(rangeStatus), ...
                        coder.wref(freshValid), coder.wref(newData), ...
                        coder.wref(metrics));
                    status = uint8(rangeStatus == 0 && range > 0);
                else
                    coder.cinclude('vl53l3cx_driver.h');
                    coder.ceval('vl53l3cx_step', obj.resolveAddr(), ...
                        coder.wref(range), coder.wref(rangeStatus), ...
                        coder.wref(status));
                end
            end
        end

        function flag = isInactivePropertyImpl(obj, prop)
            % Grey out I2CAddress unless the Custom sensor option is selected.
            flag = strcmp(prop, 'I2CAddress') && ...
                   ~strcmp(obj.Sensor, 'Custom (I2CAddress)');
        end

        function validatePropertiesImpl(obj)
            b = double(obj.TimingBudget);
            if ~isscalar(b) || ~isfinite(b) || b < 2 || b > 500
                error('stampfly:VL53L3CX:budget', ...
                    ['TimingBudget must be a scalar in ms, 2..500. ' ...
                     'Below ~1.7 ms the ULD rejects the budget outright.']);
            end
            % The poll period must be shorter than the measurement period,
            % otherwise completed measurements are missed and Range updates
            % look random rather than at the budget rate.
            tsMs = double(obj.SampleTime) * 1000;
            if tsMs >= b
                warning('stampfly:VL53L3CX:pollTooSlow', ...
                    ['SampleTime (%g ms) is not faster than TimingBudget ' ...
                     '(%g ms); measurements will alias.'], tsMs, b);
            end
            if strcmp(obj.Sensor, 'Custom (I2CAddress)')
                a = double(obj.I2CAddress);
                if ~isscalar(a) || a < 1 || a > 127
                    error('stampfly:VL53L3CX:addr', ...
                        'I2CAddress must be a 7-bit value in 1..127 (0x01..0x7F).');
                end
            end
        end

        function num = getNumInputsImpl(~);  num = 0; end
        function num = getNumOutputsImpl(~); num = 3; end

        function varargout = getOutputNamesImpl(~)
            varargout = {'Range', 'RangeStatus', 'Status'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 1], [1 1], [1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single', 'uint8', 'uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false, false, false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true, true, true};
        end

        function st = getSampleTimeImpl(obj)
            st = createSampleTime(obj, 'Type', 'Discrete', ...
                'SampleTime', obj.SampleTime);
        end
    end

    methods (Static, Access = protected)
        function header = getHeaderImpl
            header = matlab.system.display.Header( ...
                'Title', 'StampFly VL53L3CX ToF Sensor', ...
                'Text', ['Ver. 1.1 - Bottom ToF uses the official ' ...
                         'M5StampFly ULD 1.2.8.'], ...
                'ShowSourceLink', true);
        end
    end
end
