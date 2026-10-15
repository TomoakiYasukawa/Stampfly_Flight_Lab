function [bodyToNED,isValid] = bodyToNEDRotation(orientation,orientationValid)
%BODYTONEDROTATION Convert a WXYZ quaternion to body-to-NED point rotation.
bodyToNED = NaN(3);
isValid = false;
q = double(orientation(:).');
if ~logical(orientationValid) || numel(q) ~= 4 || ~all(isfinite(q))
    return
end
qNorm = norm(q);
if qNorm < 1e-8
    return
end
q = q/qNorm;
w = q(1); x = q(2); y = q(3); z = q(4);
bodyToNED = [1-2*(y*y+z*z), 2*(x*y-w*z),   2*(x*z+w*y); ...
             2*(x*y+w*z),   1-2*(x*x+z*z), 2*(y*z-w*x); ...
             2*(x*z-w*y),   2*(y*z+w*x),   1-2*(x*x+y*y)];
isValid = true;
end
