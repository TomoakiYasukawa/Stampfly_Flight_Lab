classdef FlightTuningReceiver < matlab.System & coder.ExternalDependency
    %FLIGHTTUNINGRECEIVER Read the latest SFP1 request from the radio driver.
    methods (Static)
        function name = getDescriptiveName()
            name = 'StampFly height tuning receiver';
        end
        function tf = isSupportedContext(~), tf = true; end
        function updateBuildInfo(buildInfo,context)
            if ~context.isCodeGenTarget('rtw'), return; end
            folder = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            buildInfo.addIncludePaths(folder);
            buildInfo.addSourcePaths(folder);
            buildInfo.addSourceFiles('imu_tx.cpp',folder);
        end
    end
    methods (Access = protected)
        function [values,sequence,pending] = stepImpl(~)
            raw = zeros(9,1,'int16');
            sequence = uint16(0);
            pending = uint8(0);
            if coder.target('Rtw')
                coder.cinclude('imu_tx.h');
                coder.ceval('imu_tx_tuning_request',coder.wref(raw), ...
                    coder.wref(sequence),coder.wref(pending));
            end
            values = single(raw)./imu.heightTuningScales();
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
