classdef UserButton400 < matlab.System & coder.ExternalDependency
 methods(Static)
  function tf=isSupportedContext(~),tf=true;end
  function name=getDescriptiveName(),name='StampFly GPIO0 button';end
  function updateBuildInfo(b,c),official.StatusWrite400.updateBuildInfo(b,c);end
 end
 methods(Access=protected)
  function pressed=stepImpl(~)
   pressed=uint8(0);if coder.target('Rtw'),coder.cinclude('official_status.h');pressed=coder.ceval('official_user_button');end
  end
  function s=getOutputSizeImpl(~),s=[1 1];end
  function t=getOutputDataTypeImpl(~),t='uint8';end
  function b=isOutputComplexImpl(~),b=false;end
  function b=isOutputFixedSizeImpl(~),b=true;end
  function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
 end
    methods (Static, Access=protected)
        function header=getHeaderImpl()
            % ダブルクリックした設定画面に用途と入出力を表示します。
            header=matlab.system.display.Header( ...
                'Title','StampFly 機体ボタン', ...
                'Text','StampS3 の GPIO0 ボタンを読み、押下中は uint8(1) を出力します。操縦用 JoyStick のボタンとは別です。押下時間と解放の判定は StatusIndicators で行います。','ShowSourceLink',true);
        end
    end

end
