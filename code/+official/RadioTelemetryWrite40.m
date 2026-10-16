classdef RadioTelemetryWrite40 < matlab.System
 methods(Access=protected)
  function sent=stepImpl(~,values,gains,altFlag,mode,front)
   sent=uint8(0);
   if coder.target('Rtw')
    coder.cinclude('official_radio.h');sent=coder.ceval('official_radio_send',coder.rref(values),coder.rref(gains),altFlag,mode,uint16(max(front,int16(0))));
   end
  end
  function n=getNumInputsImpl(~),n=5;end
  function s=getOutputSizeImpl(~),s=[1 1];end
  function t=getOutputDataTypeImpl(~),t='uint8';end
  function b=isOutputComplexImpl(~),b=false;end
  function b=isOutputFixedSizeImpl(~),b=true;end
  function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.025);end
 end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly JoyStick への状態返信', ...
                'Text','公式の 27 float 値とゲイン表、高度モード、飛行モード、前方距離を 40 Hz で JoyStick へ返信します。公式 120 byte 形式を保ちます。Sent は送信要求の結果です。','ShowSourceLink',true);
        end
    end

end
