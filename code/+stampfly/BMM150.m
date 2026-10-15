classdef BMM150 < matlab.System & coder.ExternalDependency
    %BMM150 磁気取得専用。センサー30 Hz、400 Hz側は非待機で最新値を取得。
    % I2Cは下向きToF/電池と同じmutexを使い、core0で100 HzのDRDY確認。
    % 校正済みuTはセンサー座標。磁気を姿勢推定・制御には使用しない。
    % Flags3: valid, fresh this tick, error code. Info6はCヘッダー参照。
    properties (Nontunable)
        I2CAddress = uint8(16)
        SampleTime = 0.0025
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function n=getDescriptiveName(),n='StampFly Magnetometer (30 Hz / cache 400 Hz)';end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'),return;end
            root=stampfly_project_root();src=fullfile(root,'src','bmm150');
            up=fullfile(src,'upstream');common=fullfile(root,'src','common');
            b.addIncludePaths({src,up,common,fullfile(root,'src')});
            b.addSourcePaths({src,up,common});b.addDefines('-DBMM150_USE_FLOATING_POINT');
            b.addSourceFiles('bmm150_driver.c',src);b.addSourceFiles('bmm150.c',up);
            b.addSourceFiles('bmm150_logger.cpp',src);b.addSourceFiles('i2c_esp32.cpp',common);
            wire=stampfly.BMI270IMU.locateArduinoLib('Wire');
            if ~isempty(wire),b.addIncludePaths(wire);b.addSourceFiles('Wire.cpp',wire);end
        end
    end
    methods (Access=protected)
        function setupImpl(o)
            if coder.target('Rtw'),coder.cinclude('bmm150_logger.h');coder.ceval('bmm150_logger_setup',o.I2CAddress);end
        end
        function [mag,flags,info]=stepImpl(~)
            mag=zeros(3,1,'single');flags=zeros(3,1,'uint8');info=zeros(6,1,'uint32');
            if coder.target('Rtw')
                coder.cinclude('bmm150_logger.h');
                coder.ceval('bmm150_logger_step',coder.wref(mag),coder.wref(flags),coder.wref(info));
            end
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getOutputNamesImpl(~),varargout={'MagneticFieldUT3','Flags3','Info6'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[3 1],[6 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8','uint32'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function validatePropertiesImpl(o)
            validateattributes(o.I2CAddress,{'uint8'},{'scalar','>=',16,'<=',19});
        end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
