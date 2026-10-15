function flags =stepFn(accel,azd,voltage,mode,altFlag,height,rawRange,dt,parkingReset,flipFlag)
% 日本語の説明はブロック注釈とDescriptionを参照。
%#codegen
persistent Norm Voltage OverG RangeFlag LowVoltage PreviousMode;
if isempty(Norm)
Norm=single(0);
Voltage=single(0);
OverG=uint8(0);
RangeFlag=uint8(0);
LowVoltage=uint8(0);
PreviousMode=uint8(0);
end
            if parkingReset,OverG=uint8(0);RangeFlag=uint8(0);end
            if mode==3 && mode~=PreviousMode,Norm=single(0);end
            if mode>1
                if (height>single(2) && altFlag~=0 && flipFlag==0) || rawRange==0,RangeFlag=min(RangeFlag+uint8(1),uint8(20));else,RangeFlag=uint8(0);end
            end
            normA=sqrt(accel(1)*accel(1)+accel(2)*accel(2)+azd*azd);
            Norm=filterStep(normA,dt,single(.005),Norm);
            if Norm>single(2),OverG=uint8(1);end
            Voltage=filterStep(voltage,dt,single(.005),Voltage);
            if LowVoltage~=uint8(100)
                if Voltage<single(3.34),LowVoltage=LowVoltage+uint8(1);else,LowVoltage=uint8(0);end
                LowVoltage=min(LowVoltage,uint8(100));
            end
            flags=[OverG;RangeFlag;LowVoltage];PreviousMode=mode;
end

function s = filterStep(u,h,T,s)
%FILTERSTEP Exact Filter::update, including operation ordering.
%#codegen
s = s*T/(T+h) + u*h/(T+h);
end