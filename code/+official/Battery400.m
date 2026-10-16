classdef Battery400 < matlab.System & coder.ExternalDependency
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='StampFly official battery voltage';end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'),return;end
            src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            b.addIncludePaths(src);b.addSourcePaths(src);b.addSourceFiles('official_battery.cpp',src);
        end
    end
    methods (Access=protected)
        function setupImpl(~)
            if coder.target('Rtw'),coder.cinclude('official_battery.h');coder.ceval('official_battery_setup');end
        end
        function [v,s]=stepImpl(~)
            v=single(0);s=uint8(0);
            if coder.target('Rtw')
                coder.cinclude('official_battery.h');coder.ceval('official_battery_step',coder.wref(v),coder.wref(s));
            end
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=2;end
        function varargout=getOutputNamesImpl(~),varargout={'VoltageV','ReadValid'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly 電池電圧', ...
                'Text','機体の電池電圧 [V] と今回の読み出し成功 ReadValid を出力します。ToF・磁気と I2C の排他制御を共有し、使用中は待たずに前回値を返します。SampleTime は制御周期 0.0025 秒です。','ShowSourceLink',true);
        end
    end

end
