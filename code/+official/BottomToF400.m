classdef BottomToF400 < stampfly.VL53L3CX
    %BOTTOMTOF400 Official dcnt>14 and ready-flag acquisition; 33ms budget.
    % Farthest status-0 target only. Forward sensor is disabled for this task.
    % ULD communication runs on core0; base rate consumes the latest result.
    methods (Static)
        function updateBuildInfo(b,c)
            stampfly.VL53L3CX.updateBuildInfo(b,c);
            if c.isCodeGenTarget('rtw')
                b.addIncludePaths(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src'));
            end
        end
    end
    methods (Access=protected)
        function setupImpl(~)
            if coder.target('Rtw')
                coder.cinclude('official_tof.h');coder.ceval('official_tof_setup');
            end
        end
        function [bottom,newData,front,status,info]=stepImpl(~,mode)
            bottom=int16(0);newData=uint8(0);front=int16(0);status=uint8(0);
            info=zeros(4,1,'uint32');
            if coder.target('Rtw')
                coder.cinclude('official_tof.h');
                coder.ceval('official_tof_step',mode,coder.wref(bottom),coder.wref(newData),coder.wref(front),coder.wref(status));
                coder.ceval('official_tof_info',coder.wref(info));
            end
        end
        function n=getNumInputsImpl(~),n=1;end
        function n=getNumOutputsImpl(~),n=5;end
        function name=getInputNamesImpl(~),name='PreviousMode';end
        function varargout=getOutputNamesImpl(~),varargout={'RawBottommm','NewData','UnusedFrontmm','BottomRangeStatus','CompletedRequestedMaxUsError'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[1 1],[1 1],[4 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'int16','uint8','int16','uint8','uint32'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true,true,true};end
    end
end
