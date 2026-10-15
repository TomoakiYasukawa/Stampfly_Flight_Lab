classdef USBLogger50 < matlab.System & coder.ExternalDependency
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='StampFly queued SFI8 USB logger';end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'),return;end
            src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            b.addIncludePaths(src);b.addSourcePaths(src);b.addSourceFiles('official_usb.cpp',src);
        end
    end
    methods (Access=protected)
        function setupImpl(~)
            if coder.target('Rtw'),coder.cinclude('official_usb.h');coder.ceval('official_usb_setup');end
        end
        function dropped=stepImpl(~,frame)
            dropped=uint32(0);
            if coder.target('Rtw'),coder.cinclude('official_usb.h');dropped=coder.ceval('official_usb_queue',coder.rref(frame));end
        end
        function n=getNumInputsImpl(~),n=1;end
        function n=getNumOutputsImpl(~),n=1;end
        function name=getInputNamesImpl(~),name='SFI8Frame190';end
        function name=getOutputNamesImpl(~),name='DroppedFrames';end
        function s=getOutputSizeImpl(~),s=[1 1];end
        function t=getOutputDataTypeImpl(~),t='uint32';end
        function c=isOutputComplexImpl(~),c=false;end
        function f=isOutputFixedSizeImpl(~),f=true;end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',.02);end
    end
end
