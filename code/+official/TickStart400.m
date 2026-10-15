classdef TickStart400 < matlab.System & coder.ExternalDependency
    %TICKSTART400 Timestamp and install the 2500us GPTimer scheduler wrappers.
    properties (Nontunable)
        SampleTime=0.0025
    end
    properties (Access=private)
        Last=uint32(0)
    end
    methods (Static)
        function tf=isSupportedContext(~),tf=true;end
        function name=getDescriptiveName(),name='StampFly GPTimer 400 Hz';end
        function updateBuildInfo(b,c)
            if ~c.isCodeGenTarget('rtw'),return;end
            src=fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))),'src');
            b.addIncludePaths(src);b.addSourcePaths(src);b.addSourceFiles('official_scheduler.cpp',src);
            b.addLinkFlags('-Wl,--wrap=mw_osTimerCreate,--wrap=mw_osTimerStart,--wrap=mw_osTimerStop,--wrap=mw_osTimerDelete');
            % The bench task wrapper measures all work, including state updates.
            if contains(c.getBuildDir(),'StampFly_Official_Bench400')
                b.addDefines('OFFICIAL_BENCH_PROFILE');
                b.addLinkFlags('-Wl,--wrap=StampFly_Official_Bench400_step');
            elseif contains(c.getBuildDir(),'StampFly_Official_FlightTest400')
                b.addDefines('OFFICIAL_FLIGHT_TEST_PROFILE');
                b.addLinkFlags('-Wl,--wrap=StampFly_Official_FlightTest400_step');
            end
        end
    end
    methods (Access=protected)
        function [start,dt,info]=stepImpl(o)
            start=uint32(0);info=zeros(4,1,'uint32');dt=single(o.SampleTime);
            if coder.target('Rtw')
                coder.cinclude('official_scheduler.h');start=coder.ceval('official_now_us');
                coder.ceval('official_scheduler_info',coder.wref(info));
            end
            if o.Last~=0,dt=single(double(official.elapsedUs(start,o.Last))*1e-6);end
            o.Last=start;
        end
        function resetImpl(o),o.Last=uint32(0);end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=3;end
        function varargout=getOutputNamesImpl(~),varargout={'StartUs','MeasuredDt','TicksMissedPeriodError'};end
        function varargout=getOutputSizeImpl(~),varargout={[1 1],[1 1],[4 1]};end
        function varargout=getOutputDataTypeImpl(~),varargout={'uint32','single','uint32'};end
        function varargout=isOutputComplexImpl(~),varargout={false,false,false};end
        function varargout=isOutputFixedSizeImpl(~),varargout={true,true,true};end
        function st=getSampleTimeImpl(o),st=createSampleTime(o,'Type','Discrete','SampleTime',o.SampleTime);end
    end
end
