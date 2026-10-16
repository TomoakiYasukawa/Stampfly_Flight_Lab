classdef BottomToFSource < official.BottomToF400
    %BOTTOMTOFSOURCE 下向き距離を飛行モードに依存せず取得するセンサー。
    % 初期化・ウォームアップ完了後に、データ準備割り込みと最小取得間隔を
    % 確認して core0 の I2C ワーカーへ要求する。400 Hz の処理は待たない。
    % 距離は有効対象の最遠値 [mm]。Fresh は新しい結果を取り出した周期で 1。
    % 初期化失敗・測距エラーは Status と Info で確認する。前方センサーは未使用。
    methods (Static)
        function name=getDescriptiveName(),name='StampFly 下向き ToF センサー';end
    end
    methods (Access=protected)
        function [bottom,newData,front,status,info]=stepImpl(~)
            % 最新の完了結果を取得し、次の読み出しを非同期で要求する。
            bottom=int16(0);newData=uint8(0);front=int16(0);status=uint8(0);
            info=zeros(4,1,'uint32');
            if coder.target('Rtw')
                coder.cinclude('official_tof.h');
                coder.ceval('official_tof_source_step',coder.wref(bottom), ...
                    coder.wref(newData),coder.wref(front),coder.wref(status));
                coder.ceval('official_tof_info',coder.wref(info));
            end
        end
        function n=getNumInputsImpl(~),n=0;end
    end
    methods (Static, Access=protected)
        function groups=getPropertyGroupsImpl()
            % 距離モード・33 ms の測距条件はドライバー側で固定します。
            % 実際に使用するモデル呼び出し周期だけを設定画面へ表示します。
            groups=matlab.system.display.Section('PropertyList',{'SampleTime'});
        end
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly 下向き ToF センサー', ...
                'Text','初期化完了後は飛行モードに依存せず距離を取得します。距離 [mm]、Fresh、未使用の前方距離、Status、Info を出力します。I2C 読み出しは core0 の非同期処理で、400 Hz の制御は待ちません。推定側の校正・待機条件は別に管理します。','ShowSourceLink',true);
        end
    end

end
