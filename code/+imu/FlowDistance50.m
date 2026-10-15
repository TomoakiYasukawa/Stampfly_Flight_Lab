classdef FlowDistance50 < matlab.System
    %FLOWDISTANCE50 全400 Hz差分を集計し、平らな床に対するXY移動距離を推定。
    % 既存GroundFlowXYTrackerと同じ385 count/radの初期換算・回転補正。
    % PoseAndRange4 = [公式姿勢角3(rad); 下向きToF距離(m)]。
    % 出力は記録・表示専用。位置制御の入力には接続しない。
    properties (Nontunable)
        SampleTime = 0.02
        XCountsPerRad = 385
        YCountsPerRad = 385
        MinQuality = 25
        MaxHeightM = 2
        MaxHorizontalSpeedMps = 1.5
        MaxVerticalSpeedMps = 2
        MinDownProjection = 0.5
    end
    properties (Access=private)
        Position = zeros(2,1,'single')
        PreviousTotals = zeros(2,1,'uint32')
        PreviousHeight = single(NaN)
        Started = false
    end
    methods (Access=protected)
        function [position,used,deltaEN]=stepImpl(o,totals,raw,gyroRaw,poseRange)
            position=o.Position;used=uint8(0);deltaEN=nan(2,1,'single');
            flow=zeros(2,1);
            for k=1:2
                count=mod(double(totals(k))-double(o.PreviousTotals(k)),4294967296);
                if count>=2147483648,count=count-4294967296;end
                flow(k)=count;
            end
            o.PreviousTotals=totals;
            q=official.eulerQuaternion(poseRange(1:3));
            [height,valid,R]=imu.correctToFHeight(poseRange(4),poseRange(4)>0,q,true);
            previous=o.PreviousHeight;o.PreviousHeight=single(height);
            if ~o.Started,o.Started=true;return;end
            if ~valid || ~isfinite(previous) || height>o.MaxHeightM || ...
                    R(3,3)<o.MinDownProjection || raw(8)==0 || ...
                    ~(raw(1)>=o.MinQuality || bitshift(raw(2),-8)<31) || ...
                    ~all(isfinite(gyroRaw))
                return
            end
            dt=double(o.SampleTime);dh=height-double(previous);
            if abs(dh)/dt>o.MaxVerticalSpeedMps,return;end
            gyro=double(gyroRaw([2 1 3]));gyro(3)=-gyro(3);
            forward=(-flow(2)/o.YCountsPerRad-gyro(2)*dt)*height;
            right=(flow(1)/o.XCountsPerRad+gyro(1)*dt)*height;
            down=-(dh+R(3,1)*forward+R(3,2)*right)/R(3,3);
            displacement=R*[forward;right;down];delta=[displacement(2);displacement(1)];
            if ~all(isfinite(delta)) || norm(delta)/dt>o.MaxHorizontalSpeedMps,return;end
            o.Position=o.Position+single(delta);
            position=o.Position;used=uint8(1);deltaEN=single(delta);
        end
        function resetImpl(o)
            o.Position(:)=single(0);o.PreviousTotals(:)=uint32(0);
            o.PreviousHeight=single(NaN);o.Started=false;
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'CumulativeCounts2','FlowRaw8','AngularRateRaw3','PoseAndRange4'};end
        function varargout=getOutputNamesImpl(~),varargout={'EastNorthM2','FlowUsed','DeltaEastNorthM2'};end
        function varargout=getOutputSizeImpl(~),varargout={[2 1],[1 1],[2 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','uint8','single'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
