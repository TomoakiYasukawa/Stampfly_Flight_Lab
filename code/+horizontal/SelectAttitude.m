classdef SelectAttitude < matlab.System
    %SELECTATTITUDE 概要：水平補助と従来の姿勢目標を滑らかに切り替えます。
    % 補助OFFでBlend=0なら元のsingle値をそのまま返し、従来出力を保ちます。
    properties (Nontunable)
        SampleTime=.0025
        EngageTimeS=.3
        ReleaseTimeS=.15
        MaxAssistTiltDeg=10
        MaxAssistTiltRateDegps=20
    end
    properties (Access=private)
        Blend=single(0)
        Assist=zeros(2,1,'single')
    end
    methods
        function o=SelectAttitude(varargin),setProperties(o,nargin,varargin{:});end
    end
    methods (Access=protected)
        function [selected,blend,assist]=stepImpl(o,manual,acceleration,motion,enabled,context)
            % 1. 有効な水平加速度を、既存の制御座標のRoll/Pitchへ戻します。
            h=min(single(.02),max(single(.0005),single(context.Dt)));
            if enabled
                target=horizontal.controlTilt(acceleration,motion.Heading);
                target=horizontal.limitVector(target,single(o.MaxAssistTiltDeg*pi/180));
                o.Assist=o.Assist+horizontal.limitVector(target-o.Assist,single(o.MaxAssistTiltRateDegps*pi/180)*h);
                o.Blend=min(single(1),o.Blend+h/single(o.EngageTimeS));
            else
                o.Blend=max(single(0),o.Blend-h/single(o.ReleaseTimeS));
            end
            % 2. Sport・停止・低推力リセットは、既存の角度/角速度選択に直ちに従います。
            if ~context.ControlContext.Run||context.ControlContext.Reset||uint8(context.ControlMode)~=0
                o.Blend=single(0);o.Assist(:)=0;
            end
            % 3. 解除時は直前の補助角から現在の手動角へ移行します。端点では再演算しません。
            if o.Blend==0,selected=single(manual);o.Assist(:)=0;
            elseif o.Blend==1,selected=o.Assist;
            else,selected=(single(1)-o.Blend)*single(manual)+o.Blend*o.Assist;end
            blend=o.Blend;assist=o.Assist;
        end
        function n=getNumInputsImpl(~),n=5;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'ManualAngleRP','AccelerationTarget2','HorizontalMotion','AssistEnabled','SharedControlContext'};end
        function varargout=getOutputNamesImpl(~),varargout={'SelectedAngleRP','Blend','AssistAngleRP'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[1 1],[2 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','水平補助の姿勢目標を選択', ...
                'Text',['水平加速度を機首方向へ戻し、従来のRoll/Pitch制御角を作ります。' ...
                '有効化・解除を時間[s]で混合し、補助の合成傾き[deg]と変化率[deg/s]を制限します。' ...
                'Blend=0は従来の手動角、1は水平補助角です。Sport・停止・低推力リセットは即座に従来の条件へ従います。'], ...
                'ShowSourceLink',true);
        end
    end
end
