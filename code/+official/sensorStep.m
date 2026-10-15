function [attitude,rates,height,velocity,flags,q,diagnostics,s]=sensorStep(accelMps2,gyro,rangeMm,newToF,voltage,mode,altFlag,h,s)
%SENSORSTEP Official sensor_read and 800-sample gyro/vertical bias calibration.
% Input ToF is already the farthest status-0 target, zero if no valid object.
% Acquisition cadence is handled by BottomToF400. No freshness expiry is added.
% IMPORTANT: official Az is in g, not m/s^2; preserved for reproduction.
%#codegen
rawA=accelMps2([2 1 3])/single(9.80665);rawA(3)=-rawA(3);
rawG=gyro([2 1 3]);rawG(3)=-rawG(3);
if mode==uint8(3) && mode~=s.previousMode
    s.first=false;s.history(:)=int16(0);s.rawFilters(:)=single(0);
    s.az=single(0);s.alt=single(0);s.accNorm=single(0);
end
if mode==uint8(0)
    s.offset(:)=single(0);s.offsetCount=uint16(0);
elseif mode==uint8(1) && s.offsetCount<uint16(800)
    v=[rawG;rawA(3)];n=single(s.offsetCount);
    s.offset=(n*s.offset+v)/(n+single(1));s.offsetCount=s.offsetCount+uint16(1);
end
if mode>uint8(1)
    for j=1:3
        s.rawFilters(j)=official.filterStep(rawA(j),h,single(0.003),s.rawFilters(j));
        s.rawFilters(j+3)=official.filterStep(rawG(j)-s.offset(j),h,single(0.003),s.rawFilters(j+3));
    end
    s.rawFilters(7)=official.filterStep(rawA(3)-s.offset(4),h,single(0.1),s.rawFilters(7));
    s.accel=s.rawFilters(1:3);s.rates=s.rawFilters(4:6);s.azd=s.rawFilters(7);
    [s.attitude,s.q]=official.madgwickStep(s.rates,s.accel,s.q,false);
    s.az=official.filterStep(-s.azd,h,single(0.1),s.az);
    if newToF~=0
        s.rawRange=rangeMm;
        if s.rawRange>int16(20), s.range=s.rawRange; end
        delta=int32(s.range)-int32(s.history(2));
        if abs(delta)>int32(500) && s.outlier<uint8(2)
            extrap=int32(s.history(2))+idivide(int32(s.history(2))-int32(s.history(4)),int32(2),'fix');
            s.range=int16(extrap);s.outlier=s.outlier+uint8(1);
        else
            s.outlier=uint8(0);s.history(4)=s.history(3);
            s.history(3)=s.history(2);s.history(2)=s.range;
        end
    end
    s.alt=official.filterStep(single(double(s.range)/1000),h,single(0.005),s.alt);
    if s.first
        [~,s.kalman]=official.kalmanStep(s.alt,s.az,h,false,s.kalman);
    else
        s.first=true;
    end
    if (s.kalman.output(2)>single(2) && altFlag~=0) || s.rawRange==0
        s.rangeFlag=min(s.rangeFlag+uint8(1),uint8(20));
    else
        s.rangeFlag=uint8(0);
    end
end
normA=sqrt(s.accel(1)*s.accel(1)+s.accel(2)*s.accel(2)+s.azd*s.azd);
s.accNorm=official.filterStep(normA,h,single(0.005),s.accNorm);
if s.accNorm>single(2),s.overG=uint8(1);end
s.voltageFilter=official.filterStep(voltage,h,single(0.005),s.voltageFilter);
if s.underVoltage~=uint8(100)
    if s.voltageFilter<single(3.34),s.underVoltage=s.underVoltage+uint8(1);
    else,s.underVoltage=uint8(0);end
    s.underVoltage=min(s.underVoltage,uint8(100));
end
attitude=s.attitude;rates=s.rates;height=s.kalman.output(2);velocity=s.kalman.output(1);
flags=[s.overG;s.rangeFlag;s.underVoltage];q=s.q;
diagnostics=[s.az;s.kalman.output(3);s.alt;s.offset;single(s.offsetCount)];
s.previousMode=mode;
end
