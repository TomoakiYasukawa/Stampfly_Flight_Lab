classdef BottomToFWithFreshness < stampfly.VL53L3CX
    %BOTTOMTOFWITHFRESHNESS Expose accepted ranges and reject stale data.
    % The shared C driver reports both an interrupt and an accepted range.
    properties (Constant, Hidden)
        % Allow normal ~30 Hz updates but expire a prolonged measurement gap.
        MaxDataAgeS = single(0.12)
    end
    properties (Access = private)
        DataAgeS = single(0)
    end
    methods (Access = protected)
        function [range,rangeStatus,status,newData] = stepImpl(obj)
            range = single(0);
            rangeStatus = uint8(0);
            newData = uint8(0);
            if coder.target('Rtw')
                rawRange = single(0);
                freshValid = uint8(0);
                metrics = zeros(10,1,'single');
                coder.cinclude('vl53l3cx_bottom_official128_driver.h');
                coder.ceval('vl53l3cx_bottom_official128_step', ...
                    coder.wref(range),coder.wref(rawRange), ...
                    coder.wref(rangeStatus),coder.wref(freshValid), ...
                    coder.wref(newData),coder.wref(metrics));
            end
            [ageS,status,rangeStatus] = imu.gateToFDataAge( ...
                obj.DataAgeS,freshValid,range,rangeStatus, ...
                single(obj.SampleTime),single(obj.MaxDataAgeS));
            obj.DataAgeS = ageS;
            % The estimator must only differentiate a newly accepted range.
            newData = freshValid;
        end
        function resetImpl(obj)
            obj.DataAgeS = single(0);
        end
        function validatePropertiesImpl(obj)
            validatePropertiesImpl@stampfly.VL53L3CX(obj);
            if ~strcmp(obj.Sensor,'Bottom (0x29)')
                error('imu:BottomToFWithFreshness:Sensor', ...
                    'This block only supports the bottom ToF sensor.');
            end
        end
        function n = getNumOutputsImpl(~), n = 4; end
        function varargout = getOutputNamesImpl(~)
            varargout = {'Range','RangeStatus','Status','NewData'};
        end
        function varargout = getOutputSizeImpl(~)
            varargout = {[1 1],[1 1],[1 1],[1 1]};
        end
        function varargout = getOutputDataTypeImpl(~)
            varargout = {'single','uint8','uint8','uint8'};
        end
        function varargout = isOutputComplexImpl(~)
            varargout = {false,false,false,false};
        end
        function varargout = isOutputFixedSizeImpl(~)
            varargout = {true,true,true,true};
        end
    end
end
