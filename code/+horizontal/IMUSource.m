classdef IMUSource < stampfly.BMI270IMU
    %IMUSOURCE 概要：従来BMI270の出力に読出し成功を追加します。
    % 加速度・角速度・温度・Freshの4出力と取得処理は従来と同じです。
    % Fresh=0の再読出しと読出し失敗を、水平推定が区別できるようにします。
    methods (Access=protected)
        function [accel,gyro,temp,fresh,readValid]=stepImpl(o)
            % 1. 既存ドライバーから同じセンサー値と新規サンプル状態を取得。
            [accel,gyro,temp,fresh]=stepImpl@stampfly.BMI270IMU(o);
            % 2. 直前の読出し結果だけを参照。SPI取引を増やしません。
            readValid=uint8(0);
            if coder.target('Rtw')
                coder.cinclude('bmi270_imu_driver.h');
                readValid=coder.ceval('bmi270_imu_read_valid');
            end
        end
        function n=getNumOutputsImpl(~),n=5;end
        function varargout=getOutputNamesImpl(~),varargout={'Accel','Gyro','Temp','Fresh','ReadValid'};end
        function varargout=getOutputSizeImpl(~),varargout={[3 1],[3 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single','uint8','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true,true};end
    end
    methods (Static,Access=protected)
        function header=getHeaderImpl()
            header=matlab.system.display.Header('Title','StampFly IMUと読出し状態', ...
                'Text',['加速度[m/s²]、角速度[rad/s]、温度[°C]は従来のBMI270出力です。' ...
                'Fresh=1は加速度と角速度の両方が新規、ReadValid=1はレジスター読出し成功を表します。' ...
                '新規でなくても短い再読出しは使えますが、水平推定は更新停止・読出し失敗を棄却します。' ...
                '400 Hz、±8 g・±2000 deg/s。PC実行は0を返すため、検証には再生入力を使います。'], ...
                'ShowSourceLink',true);
        end
    end
end
