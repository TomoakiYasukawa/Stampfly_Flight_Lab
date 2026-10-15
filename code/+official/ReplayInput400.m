classdef ReplayInput400 < matlab.System
    %REPLAYINPUT400 Typed decomposition of the independent comparison trace.
    methods (Access=protected)
        function [s,a,r,z,v,b,rf,og,m,h]=stepImpl(~,u)
            s=single(u(1:6));a=single(u(7:9));r=single(u(10:12));
            z=single(u(13));v=single(u(14));b=single(u(15));
            rf=uint8(u(16));og=uint8(u(17));m=uint8(u(18));h=single(u(19));
        end
        function n=getNumInputsImpl(~),n=1;end
        function n=getNumOutputsImpl(~),n=10;end
        function varargout=getOutputSizeImpl(~),varargout={[6 1],[3 1],[3 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single','single','single','single','uint8','uint8','uint8','single'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,10);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,10);end
    end
end
