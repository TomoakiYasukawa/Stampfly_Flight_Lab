classdef FullReplayInput400 < matlab.System
    %FULLREPLAYINPUT400 Typed inputs for the independent full official oracle.
    methods (Access=protected)
        function [s,a,r,z,v,b,rf,og,h,arm,flip,packet,ahrs]=stepImpl(~,u)
            s=u(1:6);a=u(7:9);r=u(10:12);z=u(13);v=u(14);b=u(15);
            rf=uint8(u(16));og=uint8(u(17));h=u(19);
            arm=uint8(u(20));flip=uint8(u(21));packet=uint8(u(22));ahrs=uint8(u(23));
        end
        function n=getNumInputsImpl(~),n=1;end
        function n=getNumOutputsImpl(~),n=13;end
        function varargout=getOutputSizeImpl(~),varargout={[6 1],[3 1],[3 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'single','single','single','single','single','single','uint8','uint8','single','uint8','uint8','uint8','uint8'};end
        function varargout=isOutputComplexImpl(~),varargout=repmat({false},1,13);end
        function varargout=isOutputFixedSizeImpl(~),varargout=repmat({true},1,13);end
    end
end
