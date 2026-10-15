classdef StatusWrite400 < matlab.System & coder.ExternalDependency
 methods(Static)
  function tf=isSupportedContext(~),tf=true;end
  function name=getDescriptiveName(),name='StampFly queued LEDs and buzzer';end
  function updateBuildInfo(b,c)
   if ~c.isCodeGenTarget('rtw'),return;end
   src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');b.addIncludePaths(src);b.addSourceFiles('official_status.cpp',src);
  end
 end
 methods(Access=protected)
  function setupImpl(~),if coder.target('Rtw'),coder.cinclude('official_status.h');coder.ceval('official_status_setup');end;end
  function stepImpl(~,c1,c2,hz,restart)
   if coder.target('Rtw'),coder.cinclude('official_status.h');coder.ceval('official_status_write',c1,c2,hz,uint8(restart));end
  end
  function n=getNumInputsImpl(~),n=4;end
  function n=getNumOutputsImpl(~),n=0;end
  function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.0025);end
 end
end
