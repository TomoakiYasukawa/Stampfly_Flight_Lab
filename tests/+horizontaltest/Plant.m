classdef Plant < matlab.System
    %PLANT 概要：実制御ブロックの閉ループ確認用の簡易剛体・センサーです。
    % 推力・トルク係数は実機同定値ではありません。制御器の符号、停止・
    % 保持、遅延・量子化・欠測の確認に使い、飛行性能の保証には使いません。
    properties (Nontunable)
        SampleTime=.0025
        HoverDuty=.659
        MotorLagS=.04
        LinearDampingPerS=.5
        TorqueAccelPerCount=.15
        AngularDampingPerS=4
        RangeDelayS=.035
        FlowScale=1
        GyroDelayS=0
        HeadingDriftDegps=0
    end
    properties (Access=private)
        Position=single([0;0;-.03])
        Velocity=zeros(3,1,'single')
        Quaternion=single([1;0;0;0])
        Rate=zeros(3,1,'single')
        Motor=zeros(4,1,'single')
        FlowAccumulator=zeros(2,1)
        PreviousCounts=zeros(2,1)
        RangeHistory=repmat(single(.03),32,1)
        RateHistory=zeros(3,16,'single')
        LatestRange=int16(30)
        Tick=uint32(0)
    end
    methods
        function o=Plant(varargin),setProperties(o,nargin,varargin{:});end
    end
    methods (Access=protected)
        function [attitude,vertical,flow,inertial,range,truth]=stepImpl(o,duty,disturbance,quality)
            % 1. 一周期前の剛体状態を観測として出力し、代数ループを避けます。
            dt=single(o.SampleTime);q=o.Quaternion;R=rotation(q);
            % 方位の積算誤差を観測だけへ加え、実旋回とは区別します。
            drift=single(o.HeadingDriftDegps*pi/180)*single(o.Tick)*dt;
            c=cos(drift/single(2));s=sin(drift/single(2));
            estimated=single([c*q(1)-s*q(4);c*q(2)-s*q(3);c*q(3)+s*q(2);c*q(4)+s*q(1)]);
            filterQuaternion=single([estimated(1);estimated(3);estimated(2);-estimated(4)]);
            roll=atan2(single(2)*(filterQuaternion(1)*filterQuaternion(2)+filterQuaternion(3)*filterQuaternion(4)), ...
                single(1)-single(2)*(filterQuaternion(2)^2+filterQuaternion(3)^2));
            pitch=asin(max(single(-1),min(single(1),single(2)*(filterQuaternion(1)*filterQuaternion(3)-filterQuaternion(4)*filterQuaternion(2)))));
            filterYaw=atan2(single(2)*(filterQuaternion(2)*filterQuaternion(3)+filterQuaternion(1)*filterQuaternion(4)), ...
                single(1)-single(2)*(filterQuaternion(3)^2+filterQuaternion(4)^2));
            attitude=struct('Angles',single([pitch;roll;-filterYaw-single(pi)]), ...
                'Quaternion',filterQuaternion,'AngularRate',o.Rate);
            vertical=struct('Altitude',-o.Position(3),'Velocity',-o.Velocity(3));

            % 2. ToFを35 ms遅らせて約35 msごとに更新し、斜距離を1 mm量子化します。
            slant=max(single(.021),-o.Position(3)/max(single(.2),R(3,3)));
            o.RangeHistory(2:end)=o.RangeHistory(1:end-1);o.RangeHistory(1)=slant;
            delay=min(32,max(1,round(o.RangeDelayS/o.SampleTime)+1));
            fresh=uint8(mod(double(o.Tick),14)==0);
            if fresh~=0,o.LatestRange=int16(round(1000*o.RangeHistory(delay)));end
            range=struct('DistanceMm',o.LatestRange,'Fresh',fresh,'Status',uint8(0),'VerticalSpeed',-o.Velocity(3));

            % 3. 光学フローは並進と回転の画像速度から累積整数countを作ります。
            bodyVelocity=R'*o.Velocity;
            o.FlowAccumulator=o.FlowAccumulator+double(single(385*o.FlowScale)*dt*[ ...
                bodyVelocity(2)/slant-o.Rate(1);-bodyVelocity(1)/slant-o.Rate(2)]);
            counts=round(o.FlowAccumulator);delta=single(counts-o.PreviousCounts);o.PreviousCounts=counts;
            o.Tick=o.Tick+uint32(1);
            flow=struct('Delta',delta,'Raw',uint16([quality;8191;48;0;50;120;10;1]), ...
                'Info',uint32([o.Tick;300;400;double(o.Tick)*2500]), ...
                'Totals',uint32(mod(counts,4294967296)));
            o.RateHistory(:,2:end)=o.RateHistory(:,1:end-1);o.RateHistory(:,1)=o.Rate;
            lag=min(16,max(1,round(o.GyroDelayS/o.SampleTime)+1));measuredRate=o.RateHistory(:,lag);
            raw=single([measuredRate(2);measuredRate(1);-measuredRate(3)]);
            inertial=struct('Quaternion',filterQuaternion,'RawAngularRate',raw, ...
                'StaticOffsets',zeros(4,1,'single'),'FilteredRate',measuredRate, ...
                'CorrectedRate',measuredRate,'Fresh',uint8(1),'ReadValid',uint8(1));
            truth=single([o.Position(1:2);o.Velocity(1:2);-o.Position(3);o.Rate;R(3,3)]);

            % 4. モーター遅延とFR/FL/RR/RL配分で剛体の次周期を計算します。
            requested=max(single(0),min(single(.95),single(duty(:))));
            o.Motor=o.Motor+dt/(single(o.MotorLagS)+dt)*(requested-o.Motor);
            thrust=single(9.80665)*mean(o.Motor)/single(o.HoverDuty);
            acceleration=single([0;0;9.80665])-R(:,3)*thrust- ...
                single(o.LinearDampingPerS)*o.Velocity+single([disturbance(:);0]);
            o.Velocity=o.Velocity+dt*acceleration;o.Position=o.Position+dt*o.Velocity;
            if o.Position(3)>single(-.03),o.Position(3)=single(-.03);o.Velocity(3)=min(single(0),o.Velocity(3));end
            motors=single(255)*o.Motor;
            torque=single([motors(2)+motors(4)-motors(1)-motors(3); ...
                motors(1)+motors(2)-motors(3)-motors(4); ...
                single(.5)*(motors(1)+motors(4)-motors(2)-motors(3))]);
            o.Rate=o.Rate+dt*(single(o.TorqueAccelPerCount)*torque-single(o.AngularDampingPerS)*o.Rate);
            p=o.Rate(1);r=o.Rate(3);b=o.Rate(2);
            q=q+single(.5)*dt*[-q(2)*p-q(3)*b-q(4)*r; ...
                q(1)*p+q(3)*r-q(4)*b;q(1)*b-q(2)*r+q(4)*p;q(1)*r+q(2)*b-q(3)*p];
            o.Quaternion=q/sqrt(sum(q.*q));
        end
        % FlowQualityは今回の出力に反映するため、入力依存として宣言します。
        % 閉ループの代数ループはハーネス内の明示的なUnit Delayで切ります。
        function tf=isInputDirectFeedthroughImpl(~),tf=true;end
        function n=getNumInputsImpl(~),n=3;end
        function n=getNumOutputsImpl(~),n=6;end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1],[1 1],[1 1],[9 1]};end
        function varargout=getOutputDataTypeImpl(~)
            varargout={'Bus: HorizontalTestAttitudeBus','Bus: HorizontalTestVerticalBus','Bus: HorizontalFlowBus', ...
                'Bus: HorizontalInertialBus','Bus: HorizontalRangeBus','single'};
        end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
function R=rotation(q)
w=q(1);x=q(2);y=q(3);z=q(4);two=single(2);
R=[1-two*(y*y+z*z),two*(x*y-w*z),two*(x*z+w*y); ...
   two*(x*y+w*z),1-two*(x*x+z*z),two*(y*z-w*x); ...
   two*(x*z-w*y),two*(y*z+w*x),1-two*(x*x+y*y)];
end
