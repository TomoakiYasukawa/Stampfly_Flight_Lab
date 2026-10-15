function [heightM,isValid,bodyToNED] = correctToFHeight( ...
        rangeM,tofValid,orientation,orientationValid)
%CORRECTTOFHEIGHT Project a downward ToF beam onto a horizontal floor.
% The floor is treated as an infinite horizontal plane. The ToF beam is
% aligned with the body's +Z (down) axis. Height is measured at the sensor;
% no sensor-to-mesh-center offset is included.
heightM = NaN;
isValid = false;
bodyToNED = NaN(3);
if ~logical(tofValid) || ~isscalar(rangeM) || ...
        ~isfinite(rangeM) || rangeM < 0
    return
end
[bodyToNED,orientationIsValid] = imu.bodyToNEDRotation( ...
    orientation,orientationValid);
if ~orientationIsValid
    return
end
downProjection = bodyToNED(3,3);
if ~isfinite(downProjection) || downProjection <= 0
    return
end
heightM = double(rangeM)*downProjection;
isValid = true;
end
