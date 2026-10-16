classdef PMW3901MB < matlab.System & coder.ExternalDependency
    %PMW3901MB 光学フロー取得のみ。400 Hz、SPI 2 MHz、一括バースト読出し。
    % FlowCounts2は前回読出しからの生カウント（速度[m/s]ではない）。
    % Raw8: SQUAL, full shutter, motion, observation, raw sum/max/min, valid.
    % Info4: sample count, read us, max read us, sample time us.
    % Totals2: 符号付き累積カウントのuint32表現（2^32で巡回）。
    properties (Nontunable)
        SampleTime = 0.0025
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function n=getDescriptiveName(),n='StampFly Optical Flow 400 Hz';end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'),return;end
            root=stampfly_project_root();
            src=fullfile(root,'src','pmw3901');up=fullfile(src,'upstream');
            common=fullfile(root,'src','common');
            b.addIncludePaths({src,up,common});b.addSourcePaths({src,up,common});
            b.addSourceFiles('pmw3901_wrapper.cpp',src);
            b.addSourceFiles('Bitcraze_PMW3901.cpp',up);
            b.addSourceFiles('spi_esp32.cpp',common);
            spi=stampfly.BMI270IMU.locateArduinoLib('SPI');
            if ~isempty(spi),b.addIncludePaths(spi);b.addSourceFiles('SPI.cpp',spi);end
        end
    end
    methods (Access=protected)
        function setupImpl(~)
            if coder.target('Rtw'),coder.cinclude('pmw3901_driver.h');coder.ceval('pmw3901_setup');end
        end
        function [flow,raw,info,totals]=stepImpl(~)
            flow=zeros(2,1,'single');raw=zeros(8,1,'uint16');
            info=zeros(4,1,'uint32');totals=zeros(2,1,'uint32');
            if coder.target('Rtw')
                coder.cinclude('pmw3901_driver.h');
                coder.ceval('pmw3901_logger_step',coder.wref(flow),coder.wref(raw),coder.wref(info),coder.wref(totals));
            end
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=4;end
        function varargout=getOutputNamesImpl(~),varargout={'FlowCounts2','Raw8','Info4','Totals2'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[8 1],[4 1],[2 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint16','uint32','uint32'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly 光学フローセンサー', ...
                'Text','SPI の Motion Burst から 2 軸の差分カウント、品質 Raw8、診断 Info4、巡回する累積 Totals2 を 400 Hz で取得します。カウントは距離・速度そのものではありません。距離換算は後段の FlowDistance50 で行います。','ShowSourceLink',true);
        end
    end

end
