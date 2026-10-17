classdef ExtendedLogger50 < matlab.System
    %EXTENDEDLOGGER50 計測・指令を3つのCRC付きフレームへまとめる（50 Hz）。
    % 光学フローの400 Hz生差分は、通常フレームには20 ms区間合計を保存。
    % 補足フレームは同じSequence/Time/BuildIDを持ち、制御を変更しない。
    properties (Access=private)
        Sequence=uint16(0)
        LastToF=uint32(0)
        LastMag=uint32(0)
        LastFlowTotals=zeros(2,1,'uint32')
    end
    properties (Nontunable)
        BuildID=uint32(1401)
        FirmwareRevision=uint32(1601)
    end
    methods (Access=protected)
        function [base,commands,sensors]=stepImpl(o,raw,estimate,control,extra)
            profile=uint32(0);
            if coder.target('Rtw'),coder.cinclude('official_scheduler.h');profile=coder.ceval('official_now_us');end
            base=packBaseImpl(o,o.Sequence,raw,estimate,control,extra);
            commands=basic.packCommandExtension(o.Sequence,raw.Time,o.BuildID,o.FirmwareRevision,estimate,control);
            sensors=imu.packSensorExtension(o.Sequence,raw.Time,o.BuildID,o.FirmwareRevision,raw,estimate,control,extra);
            o.Sequence=uint16(bitand(uint32(o.Sequence)+1,uint32(65535)));
            if coder.target('Rtw'),coder.ceval('official_profile_record',uint8(0),profile);end
        end
        function base=packBaseImpl(o,sequence,raw,estimate,control,extra)
            % 通常パケットの値・CRCを共通化し、分散版も同じ形式を使用します。
            tofNew=uint8(raw.ToFInfo(1)~=o.LastToF);o.LastToF=raw.ToFInfo(1);
            magFresh=uint8(extra.Mag.Info(1)~=o.LastMag);o.LastMag=extra.Mag.Info(1);
            flowSum=zeros(2,1,'single');
            for k=1:2
                delta=mod(double(extra.Flow.Totals(k))-double(o.LastFlowTotals(k)),4294967296);
                if delta>=2147483648,delta=delta-4294967296;end
                flowSum(k)=single(delta);
            end
            o.LastFlowTotals=extra.Flow.Totals;
            cd=estimate.ControlDiagnostics;z=estimate.Height;v=estimate.Velocity;
            diag=nan(32,1,'single');
            diag(1:10)=[raw.Voltage;single(raw.BatteryValid);single(tofNew);cd(1);cd(1)-z;cd(4);v;v;cd(4)-v;cd(2)];
            diag(11:13)=single(raw.ToFInfo(1:3));
            diag(14)=single(double(cd(5))/3.7)-cd(2);
            diag(15:18)=[single(double(cd(5))/3.7);single(double(cd(5))/3.7);single(control.Mode==2);single(any(control.Duty>=single(.95)))];
            diag(19:22)=cd(14:17);diag(24)=cd(1);
            % No height-tuning namespace is claimed for this fixed-PID model.
            q=official.eulerQuaternion(estimate.Angles);
            base=imu.packFlightTuningFrame(sequence,raw.Time,raw.Acceleration,raw.AngularRate,raw.IMUFresh, ...
                single(raw.BottomMm)/single(1000),uint8(raw.BottomMm>0 && raw.ToFStatus==0),raw.ToFStatus, ...
                flowSum,uint8(extra.Flow.Raw(1)),uint8(extra.Flow.Raw(8)),uint8(bitshift(extra.Flow.Raw(2),-8)), ...
                extra.Distance.PositionEN,extra.Distance.Used,extra.Mag.Field,extra.Mag.Flags(1),q,uint8(control.Mode>1), ...
                z,uint8(control.Mode>1),extra.Distance.DeltaEN,zeros(4,1,'single'),uint8(1),control.Mode,uint16(0),diag, ...
                o.BuildID,single([0;0]),uint16(0),uint8(0),true);
            base(74)=uint8(extra.Mag.Flags(1)~=0)+bitshift(magFresh,1);
            % MotorFR/FL/RR/RL are COMPUTED PWM counts, not applied outputs/RPM.
            base(105:108)=uint8(floor(single(255)*control.Duty));base(109)=uint8(1);
            base(188)=uint8(0);
            base(189:190)=reshape(typecast(imu.crc16(base(1:188)),'uint8'),2,1);
        end
        function n=getNumInputsImpl(~),n=4;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getInputNamesImpl(~),varargout={'RawSensors','Estimates','Commands','ExtraSensors'};end
        function varargout=getOutputNamesImpl(~),varargout={'SFI8Frame190','CommandFrame190','SensorFrame246'};end
        function varargout=getOutputSizeImpl(~),varargout={[190 1],[190 1],[246 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'uint8','uint8','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.02);end
    end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly ログパケット作成', ...
                'Text','生センサー、推定、制御、追加センサーの名前付きバスを 50 Hz のログへ変換します。SFI8・SFIX・SFIY の項目順、型、CRC を保ちます。BuildID はプログラムの識別番号で、機体固有の ID ではありません。送信は後段の LogTransport50 が行います。','ShowSourceLink',true);
        end
    end

end
