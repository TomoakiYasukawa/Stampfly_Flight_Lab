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
end
