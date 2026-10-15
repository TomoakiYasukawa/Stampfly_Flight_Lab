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
end
