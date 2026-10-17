classdef Command < matlab.System
    %COMMAND 概要：移動・減速・停止位置保持を切り替えて水平速度目標を作ります。
    % 既存のスティック中立補正済み角度を、水平補助中だけ速度指令へ解釈します。
    % 将来の自動移動は、この出力と同じ局所速度[m/s]を制御器へ渡せます。
    properties (Nontunable)
        Enabled=true
        SampleTime=.0025
        MaxSpeedMps=.3
        CommandAccelerationMps2=.6
        PositionGainPerS=.8
        EngageHeightM=.20
        ReleaseHeightM=.15
        HealthyTimeS=.5
        RecoveryTimeS=1.0
        NeutralEnter=.05
        NeutralExit=.08
        StopSpeedMps=.08
        StopTimeS=.3
        ManualAngleLimitRad=pi/6
    end
    properties (Access=private)
        Active=false
        HadFailure=false
        HealthyTime=single(0)
        StopTime=single(0)
        Moving=false
        State=uint8(0)
        TargetPosition=zeros(2,1,'single')
        TargetVelocity=zeros(2,1,'single')
        LastEpoch=single(-1)
    end
    methods
        function o=Command(varargin),setProperties(o,nargin,varargin{:});end
    end
    methods (Access=protected)
        function [target,enabled,state,hold]=stepImpl(o,motion,manualAngles,context)
            % 1. Stabilize/Auto高度・実行許可・正常な測定だけを対象にします。
            dt=min(single(.02),max(single(.0005),single(context.Dt)));
            branch=uint8(context.FlightContext.Branch);
            landing=branch==uint8(5);
            modeOK=o.Enabled && uint8(context.ControlMode)==0 && context.ControlContext.Run && ...
                ~context.ControlContext.Reset && ( ...
                (branch==uint8(2)&&context.ControlContext.AltitudeEnabled) || (landing&&o.Active));
            neutralCommand=horizontal.limitVector(single(manualAngles)/single(o.ManualAngleLimitRad),single(1));
            amount=horizontal.vectorNorm(neutralCommand);
            if o.Moving,o.Moving=amount>single(o.NeutralEnter);
            else,o.Moving=amount>single(o.NeutralExit);end
            healthy=motion.Status(1)~=0 && all(isfinite(motion.Position)) && all(isfinite(motion.Velocity)) && ...
                isfinite(motion.Heading)&&motion.Height>=single(o.ReleaseHeightM);
            frameChanged=motion.Status(8)~=o.LastEpoch;o.LastEpoch=motion.Status(8);
            if frameChanged&&o.Active,healthy=false;end
            % 2. 欠測時は直ちに補助を解除し、復帰には良好測定と中立の継続を求めます。
            if ~modeOK || ~healthy
                if o.Active,o.HadFailure=true;end
                o.Active=false;o.HealthyTime=single(0);o.StopTime=single(0);o.TargetVelocity(:)=0;
                o.TargetPosition=motion.Position;
                if modeOK,o.State=uint8(1);else,o.State=uint8(0);o.HadFailure=false;end
            elseif ~o.Active
                o.State=uint8(1);o.TargetPosition=motion.Position;o.TargetVelocity(:)=0;
                if ~o.Moving&&motion.Height>=single(o.EngageHeightM)&&~landing
                    o.HealthyTime=o.HealthyTime+dt;
                else,o.HealthyTime=single(0);end
                wait=single(o.HealthyTimeS);if o.HadFailure,wait=single(o.RecoveryTimeS);end
                if o.HealthyTime>=wait
                    o.Active=true;o.State=uint8(4);o.StopTime=single(0);
                end
            end
            % 3. 50 Hzの観測更新時にだけ位置P・移動指令・減速目標を更新します。
            if o.Active && motion.Status(2)~=0
                h=motion.Status(3);h=min(single(.04),max(single(.008),h));
                desired=zeros(2,1,'single');
                if o.Moving&&~landing
                    o.State=uint8(3);o.StopTime=single(0);o.TargetPosition=motion.Position;
                    magnitude=(amount-single(o.NeutralEnter))/(single(1)-single(o.NeutralEnter));
                    normalized=neutralCommand*(max(single(0),magnitude)/max(amount,single(.001)));
                    body=single(o.MaxSpeedMps)*[-normalized(2);normalized(1)];
                    c=horizontal.mathSingle('cos',motion.Heading);s=horizontal.mathSingle('sin',motion.Heading);
                    desired=[c*body(1)-s*body(2);s*body(1)+c*body(2)];
                else
                    if o.State==uint8(3),o.State=uint8(4);o.StopTime=single(0);end
                    if o.State==uint8(2)
                        desired=horizontal.limitVector(single(o.PositionGainPerS)*(o.TargetPosition-motion.Position),single(o.MaxSpeedMps));
                    else
                        o.State=uint8(4);
                        if horizontal.vectorNorm(motion.Velocity)<single(o.StopSpeedMps)&&horizontal.vectorNorm(o.TargetVelocity)<single(.02)
                            o.StopTime=o.StopTime+h;
                        else,o.StopTime=single(0);end
                        if o.StopTime>=single(o.StopTimeS)
                            o.State=uint8(2);o.TargetPosition=motion.Position;
                        end
                    end
                end
                % 4. 速度ベクトルの変化量を制限し、Yaw中の急な方向変更も抑えます。
                increment=horizontal.limitVector(desired-o.TargetVelocity,single(o.CommandAccelerationMps2)*h);
                o.TargetVelocity=horizontal.limitVector(o.TargetVelocity+increment,single(o.MaxSpeedMps));
            end
            target=o.TargetVelocity;enabled=o.Active;state=o.State;hold=o.TargetPosition;
        end
        function n=getNumInputsImpl(~),n=3;end
        function n=getNumOutputsImpl(~),n=4;end
        function varargout=getInputNamesImpl(~),varargout={'HorizontalMotion','ManualAngleRP','SharedControlContext'};end
        function varargout=getOutputNamesImpl(~),varargout={'VelocityTarget2','AssistEnabled','State','HoldPosition2'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[1 1],[1 1],[2 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','boolean','uint8','single'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
        function validatePropertiesImpl(o)
            assert(o.MaxSpeedMps>0&&o.CommandAccelerationMps2>0&&o.PositionGainPerS>=0);
            assert(o.NeutralEnter>0&&o.NeutralEnter<o.NeutralExit&&o.NeutralExit<1);
            assert(o.ReleaseHeightM>0&&o.EngageHeightM>o.ReleaseHeightM);
        end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','移動・減速・停止位置保持の目標生成', ...
                'Text',['Enabled=trueでStabilize/Auto高度の水平補助を許可します。' ...
                'スティックは機首方向の速度指令、中立後は減速して新しい停止位置を保持します。' ...
                '欠測時は解除し、正常測定と中立が継続してから現在位置を取り直します。' ...
                'State: 0手動、1準備/復帰待ち、2位置保持、3移動、4減速。' ...
                'Yawと高度の指令経路は従来のままです。速度[m/s]、加速度[m/s²]、高さ[m]、時間[s]を設定します。'], ...
                'ShowSourceLink',true);
        end
    end
end
