classdef FlowMotion < matlab.System
    %FLOWMOTION 概要：400 Hzの光学フロー・角速度を同一区間で集計し、
    % 50 Hzで水平速度と相対位置を推定します。局所Xは基準機首、Yは右。
    % 不良区間を速度ゼロに置き換えず、Statusで使用可否を公開します。
    properties (Nontunable)
        SampleTime=.0025
        WindowSamples=8
        XCountsPerRad=385
        YCountsPerRad=385
        MinQuality=25
        MinHeightM=.08
        MaxHeightM=1.0
        MaxRangeAgeS=.15
        MaxFlowAgeS=.025
        MaxSampleGapS=.01
        MaxGyroAgeS=.0075
        MaxSpeedMps=1.5
        MaxVerticalSpeedMps=2.0
        MaxTiltDeg=25
        VelocityTimeConstantS=.05
    end
    properties (Access=private)
        Position=zeros(2,1,'single')
        Velocity=zeros(2,1,'single')
        Heading=single(0)
        Height=single(0)
        LastCount=uint32(0)
        LastTime=uint32(0)
        LastTotals=zeros(2,1,'uint32')
        LastGyro=zeros(3,1,'single')
        Counts=zeros(2,1,'single')
        GyroIntegral=zeros(2,1,'single')
        WindowTime=single(0)
        Elapsed=single(0)
        Samples=uint8(0)
        Seen=uint8(0)
        WindowGood=false
        Started=false
        FilterStarted=false
        ReferenceCaptured=false
        ReferenceYaw=single(0)
        PreviousReset=false
        Epoch=uint16(0)
        FlowAge=single(1)
        RangeAge=single(1)
        GyroAge=single(1)
        LastRange=single(0)
        MinSqual=single(0)
        Valid=false
        Reason=single(1)
        LastDiagnostic=zeros(8,1,'single')
        LastStatus=zeros(8,1,'single')
    end
    methods
        function o=FlowMotion(varargin),setProperties(o,nargin,varargin{:});end
    end
    methods (Access=protected)
        function [position,velocity,heading,height,status,diagnostic]=stepImpl(o,flow,inertial,range,context)
            % 実機でこの処理だけの最大時間を測り、400 Hz全タスクとは別に記録します。
            profile=uint32(0);
            if coder.target('Rtw'),coder.cinclude('official_scheduler.h');profile=coder.ceval('official_now_us');end
            % 1. 周期とリセットの立上りを確認し、各飛行・姿勢基準を取り直します。
            dt=single(context.Dt);dtOK=isfinite(dt)&&dt>single(.0005)&&dt<single(.02);
            if ~dtOK,dt=single(o.SampleTime);end
            if context.Reset && ~o.PreviousReset
                o.Position(:)=0;o.Velocity(:)=0;o.FilterStarted=false;
                o.ReferenceCaptured=false;o.Started=false;o.Valid=false;o.GyroAge=single(1);
                o.Samples=uint8(0);o.Epoch=o.Epoch+uint16(1);
            end
            o.PreviousReset=context.Reset;
            o.FlowAge=min(single(1),o.FlowAge+dt);o.RangeAge=min(single(1),o.RangeAge+dt);
            % 2. 非同期ToFは到着時刻を管理します。状態エラーと古い保持値を棄却します。
            if range.Fresh~=0
                o.LastRange=single(range.DistanceMm)*single(.001);o.RangeAge=single(0);
            end
            [R,poseOK]=horizontal.bodyRotation(inertial.Quaternion);
            o.Height=o.LastRange*R(3,3);
            poseOK=poseOK && context.PoseReady && R(3,3)>horizontal.mathSingle('cos',single(o.MaxTiltDeg*pi/180));
            rangeOK=range.Status==0 && o.RangeAge<=single(o.MaxRangeAgeS) && ...
                o.Height>=single(o.MinHeightM)&&o.Height<=single(o.MaxHeightM)&&isfinite(o.Height);
            % 3. 静止校正と推定器の残留バイアスを生角速度から引きます。
            % フィルター済み角速度を直接積分すると遅延するため、生の時間応答を使います。
            rawRate=single([inertial.RawAngularRate(2);inertial.RawAngularRate(1);-inertial.RawAngularRate(3)]);
            bias=single(inertial.StaticOffsets(1:3)) + ...
                (single(inertial.FilteredRate)-single(inertial.CorrectedRate));
            gyro=rawRate-bias;
            % Freshは両センサーの新規状態。成功した短い再読出しは7.5 ms以内なら採用。
            % 読出し失敗は直ちに棄却し、新規値が止まった場合も使用を停止します。
            o.GyroAge=min(single(1),o.GyroAge+dt);
            if inertial.Fresh~=0&&inertial.ReadValid~=0,o.GyroAge=single(0);end
            imuOK=inertial.ReadValid~=0 && o.GyroAge<=single(o.MaxGyroAgeS) && ...
                all(isfinite(gyro)) && horizontal.vectorNorm(gyro)<single(8) && ...
                isfinite(range.VerticalSpeed)&&abs(range.VerticalSpeed)<=single(o.MaxVerticalSpeedMps);
            % 4. 取得番号・時刻・巡回累積値が整合する新しいフローだけを取り込みます。
            updated=false;newSample=flow.Info(1)~=o.LastCount && flow.Info(4)~=o.LastTime;
            sampleOK=false;gap=single(0);reason=single(0);
            if newSample
                gap=single(double(horizontal.counterDelta(flow.Info(4),o.LastTime))*1e-6);
                countGap=horizontal.counterDelta(flow.Info(1),o.LastCount);
                delta=zeros(2,1,'single');
                for k=1:2
                    % 下位32 bitを符号付き差へ読み替え、負の移動countも保ちます。
                    d=typecast(horizontal.counterDelta(flow.Totals(k),o.LastTotals(k)),'int32');
                    delta(k)=single(d);
                end
                sampleOK=o.Started && countGap==uint32(1) && gap>=single(.0005)&&gap<=single(o.MaxSampleGapS) && ...
                    all(isfinite(flow.Delta)) && all(delta==flow.Delta) && ...
                    flow.Raw(8)~=0 && flow.Raw(1)>=uint16(o.MinQuality) && imuOK && poseOK && rangeOK && dtOK;
                o.LastCount=flow.Info(1);o.LastTime=flow.Info(4);o.LastTotals=flow.Totals;
                o.FlowAge=single(0);o.Started=true;
                if ~sampleOK,reason=single(1);end
            else
                reason=single(2);
            end
            if ~poseOK,reason=single(3);end
            if ~rangeOK,reason=single(4);end
            if ~imuOK||~dtOK,reason=single(5);end
            % 5. 8周期の全サンプルの品質を確認し、countと台形角速度積分を集計します。
            if o.Samples==0
                o.Counts(:)=0;o.GyroIntegral(:)=0;o.WindowTime=single(0);
                o.Elapsed=single(0);o.Seen=uint8(0);o.WindowGood=true;o.MinSqual=single(255);
            end
            o.Samples=o.Samples+uint8(1);o.Elapsed=o.Elapsed+dt;
            o.WindowGood=o.WindowGood&&sampleOK;
            if sampleOK
                o.Counts=o.Counts+single(flow.Delta);
                o.GyroIntegral=o.GyroIntegral+(o.LastGyro(1:2)+gyro(1:2))*single(.5)*gap;
                o.WindowTime=o.WindowTime+gap;o.Seen=o.Seen+uint8(1);
                o.MinSqual=min(o.MinSqual,single(flow.Raw(1)));
            end
            o.LastGyro=gyro;
            if ~sampleOK,o.Valid=false;o.FilterStarted=false;o.Reason=reason;end
            if o.FlowAge>single(o.MaxFlowAgeS),o.Valid=false;o.Reason=single(2);end
            % 6. 良好な区間だけ並進速度へ換算します。ToFの斜距離と鉛直速度で投影します。
            if o.Samples>=uint8(o.WindowSamples)
                updated=true;o.Samples=uint8(0);
                intervalOK=o.WindowGood&&o.WindowTime>single(.008)&&o.WindowTime<single(.04);
                if intervalOK
                    % 軸交換後のRz*Rx*RyからYawを取り出します。
                    yaw=horizontal.mathSingle('atan2',-R(1,2),R(2,2));
                    if ~o.ReferenceCaptured,o.ReferenceYaw=yaw;o.ReferenceCaptured=true;end
                    o.Heading=horizontal.mathSingle('atan2',horizontal.mathSingle('sin',yaw-o.ReferenceYaw),horizontal.mathSingle('cos',yaw-o.ReferenceYaw));
                    forward=o.LastRange*(-o.Counts(2)/single(o.YCountsPerRad)-o.GyroIntegral(2))/o.WindowTime;
                    right=o.LastRange*(o.Counts(1)/single(o.XCountsPerRad)+o.GyroIntegral(1))/o.WindowTime;
                    down=(-single(range.VerticalSpeed)-R(3,1)*forward-R(3,2)*right)/R(3,3);
                    world=R*[forward;right;down];c=horizontal.mathSingle('cos',o.ReferenceYaw);s=horizontal.mathSingle('sin',o.ReferenceYaw);
                    measured=[c*world(1)+s*world(2);-s*world(1)+c*world(2)];
                    intervalOK=all(isfinite(measured))&&horizontal.vectorNorm(measured)<=single(o.MaxSpeedMps);
                    if intervalOK
                        if ~o.FilterStarted,o.Velocity=measured;o.FilterStarted=true;
                        else
                            alpha=o.WindowTime/(single(o.VelocityTimeConstantS)+o.WindowTime);
                            o.Velocity=o.Velocity+alpha*(measured-o.Velocity);
                        end
                        o.Position=o.Position+measured*o.WindowTime;
                        o.Reason=single(0);
                    else,o.FilterStarted=false;o.Reason=single(6);end
                    o.LastDiagnostic=[o.Counts;o.GyroIntegral;o.LastRange;o.MinSqual;forward;right];
                end
                o.Valid=intervalOK;
                o.LastStatus(3)=o.WindowTime;o.LastStatus(6)=single(o.Seen)/single(o.WindowSamples);
            end
            % 7. 無効中は位置・速度の表示を保持し、Valid=falseで使用を禁止します。
            o.LastStatus(1)=single(o.Valid);o.LastStatus(2)=single(updated);
            o.LastStatus(4)=o.FlowAge;o.LastStatus(5)=o.RangeAge;
            o.LastStatus(7)=o.Reason;o.LastStatus(8)=single(o.Epoch);
            position=o.Position;velocity=o.Velocity;heading=o.Heading;height=o.Height;
            status=o.LastStatus;diagnostic=o.LastDiagnostic;
            if coder.target('Rtw'),coder.ceval('official_profile_record',uint8(1),profile);end
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=6;end
        function varargout=getInputNamesImpl(~),varargout={'OpticalFlow','InertialMotion','RangeMotion','Context'};end
        function varargout=getOutputNamesImpl(~),varargout={'Position2','Velocity2','Heading','Height','Status8','Diagnostics8'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[2 1],[1 1],[1 1],[8 1],[8 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single','single','single','single'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
        function validatePropertiesImpl(o)
            assert(o.WindowSamples==8 && o.SampleTime==.0025);
            assert(o.XCountsPerRad>0&&o.YCountsPerRad>0&&o.MinQuality>=1);
            assert(o.MinHeightM>0&&o.MaxHeightM>o.MinHeightM&&o.MaxSpeedMps>0);
            assert(o.MaxGyroAgeS>=o.SampleTime&&o.MaxGyroAgeS<=.02);
        end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','水平速度・相対位置の推定', ...
                'Text',['光学フローを400 Hzで確認し、8周期ごとに速度[m/s]と相対位置[m]を更新します。' ...
                'Xは基準機首、Yは右。前=-センサーY、右=+センサーX。角速度は同一区間の台形積分で除去します。' ...
                'ToFの斜距離と姿勢・鉛直速度で平らな床へ投影し、古い測距・低品質・欠測・外れ値は使用しません。' ...
                'IMU読出し成功と更新を区別し、短い再読出しはMaxGyroAgeS以内だけ使います。' ...
                '385 count/radは初期換算値です。Status8とDiagnostics8の項目はdocs/horizontal_control.mdを参照してください。'], ...
                'ShowSourceLink',true);
        end
    end
end
