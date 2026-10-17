classdef VelocityPI < matlab.System
    %VELOCITYPI 概要：局所水平速度の誤差をPIで水平加速度へ変換します。
    % 50 Hzの有効な観測だけ積分し、欠測・解除時は積分をリセットします。
    % 速度指令の出所を持たないため、将来の自動移動にも同じ境界を使えます。
    properties (Nontunable)
        SampleTime=.0025
        ProportionalGainPerS=1.8
        IntegralGainPerS2=.5
        MaxAccelerationMps2=.6
        IntegralLimitMps2=.25
        AccelerationSlewMps3=2.0
    end
    properties (Access=private)
        Integral=zeros(2,1,'single')
        Acceleration=zeros(2,1,'single')
        LastEpoch=single(-1)
        Saturated=false
    end
    methods
        function o=VelocityPI(varargin),setProperties(o,nargin,varargin{:});end
    end
    methods (Access=protected)
        function [acceleration,integral,saturated]=stepImpl(o,target,motion,enabled,motorSaturated)
            % 1. 無効・解除・局所基準変更では積分を消去し、再有効化の飛びを防ぎます。
            active=enabled&&motion.Status(1)~=0;
            if ~active||motion.Status(8)~=o.LastEpoch
                o.Integral(:)=0;o.Acceleration(:)=0;o.Saturated=false;
            end
            o.LastEpoch=motion.Status(8);
            if active&&motion.Status(2)~=0
                % 2. 合成加速度制限と、1周期遅らせたモーター飽和帰還で積分を抑えます。
                h=min(single(.04),max(single(.008),motion.Status(3)));
                error=single(target)-motion.Velocity;
                proportional=single(o.ProportionalGainPerS)*error;
                candidate=horizontal.limitVector(o.Integral+single(o.IntegralGainPerS2)*error*h,single(o.IntegralLimitMps2));
                effort=proportional+o.Integral;
                clipping=horizontal.vectorNorm(effort)>single(o.MaxAccelerationMps2);
                pushesLimit=dot(effort,error)>0;
                unwinds=dot(o.Integral,error)<0;
                if (~motorSaturated&&(~clipping||~pushesLimit))||unwinds,o.Integral=candidate;end
                desired=horizontal.limitVector(proportional+o.Integral,single(o.MaxAccelerationMps2));
                % 3. 加速度指令の変化率を制限します。微分は量子化ノイズのため使いません。
                o.Acceleration=o.Acceleration+horizontal.limitVector(desired-o.Acceleration,single(o.AccelerationSlewMps3)*h);
                o.Acceleration=horizontal.limitVector(o.Acceleration,single(o.MaxAccelerationMps2));
                o.Saturated=motorSaturated||clipping;
            end
            acceleration=o.Acceleration;integral=o.Integral;saturated=o.Saturated;
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'VelocityTarget2','HorizontalMotion','AssistEnabled','PreviousMotorSaturation'};end
        function varargout=getOutputNamesImpl(~),varargout={'AccelerationTarget2','Integral2','Saturated'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[2 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','boolean'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
        function validatePropertiesImpl(o)
            assert(o.ProportionalGainPerS>0&&o.IntegralGainPerS2>=0);
            assert(o.MaxAccelerationMps2>0&&o.IntegralLimitMps2>=0&&o.AccelerationSlewMps3>0);
        end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','水平速度PI', ...
                'Text',['局所[X前方,Y右方]速度の目標と推定値[m/s]から水平加速度[m/s²]を作ります。' ...
                'P[1/s]、I[1/s²]。微分項は使いません。合成加速度、積分、変化率を制限し、' ...
                '配分飽和中は積分の増加を止めます。欠測・解除時は積分をリセットします。' ...
                'この出力を機体の傾き目標に変換して、既存の姿勢・角速度PIDへ渡します。'], ...
                'ShowSourceLink',true);
        end
    end
end
