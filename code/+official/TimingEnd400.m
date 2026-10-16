classdef TimingEnd400 < matlab.System & coder.ExternalDependency
    properties (Nontunable)
        SampleTime=0.0025
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='StampFly 400 Hz timing end';end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'),return;end
            src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            b.addIncludePaths(src);b.addSourcePaths(src);b.addSourceFiles('official_timing.cpp',src);
        end
    end
    methods (Access=protected)
        function d=stepImpl(~,start,fresh,applied,pwm,frameDependency)
            d=zeros(8,1,'uint32');
            if coder.target('Rtw')
                coder.cinclude('official_timing.h');
                coder.ceval('official_timing_end',start,fresh,coder.rref(applied),coder.rref(pwm),coder.wref(d));
            end
            % Signal dependence places the probe after telemetry packing.
            if isempty(frameDependency),d(1)=uint32(0);end
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=1;end
        function varargout=getInputNamesImpl(~),varargout={'StartUs','IMUFresh','Applied4','PWMInfo4','TelemetryDependency'};end
        function name=getOutputNamesImpl(~),name='ExecGapCountFreshMeanMaxGapOver';end
        function s=getOutputSizeImpl(~),s=[8 1];end
        function t=getOutputDataTypeImpl(~),t='uint32';end
        function c=isOutputComplexImpl(~),c=false;end
        function f=isOutputFixedSizeImpl(~),f=true;end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly 周期の処理時間', ...
                'Text','周期開始時刻からこの地点までの時間・周期間隔・平均・最大・超過などを記録します。IMU の Fresh、実適用 PWM、ログへの信号依存で計測位置を固定しています。全タスクの処理時間は生成 step のラッパーが別途計測します。','ShowSourceLink',true);
        end
    end

end
