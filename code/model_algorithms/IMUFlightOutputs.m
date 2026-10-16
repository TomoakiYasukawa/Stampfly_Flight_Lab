function [angles,q,rates]=IMUFlightOutputs(orientation,angularVelocity,run,reset,rawRates)
%IMUFLIGHTOUTPUTS Preserve the previous estimator's flight-facing conventions.
%#codegen
% Match the previous angle/quaternion hold behavior before estimation starts.
% A reset clears orientation but retains the last angles until the next update.
persistent heldAngles heldQuaternion heldBias
if isempty(heldAngles)
    heldAngles=zeros(3,1,'single');
    heldQuaternion=single([1;0;0;0]);
    heldBias=zeros(3,1,'single');
end
if reset
    heldQuaternion=single([1;0;0;0]);
    heldBias=zeros(3,1,'single');
end
correctedRates=single([angularVelocity(2);angularVelocity(1);-angularVelocity(3)]);
if run
    heldQuaternion=single(orientation(:));
    w=heldQuaternion(1);x=heldQuaternion(2);y=heldQuaternion(3);z=heldQuaternion(4);
    roll=atan2(single(2)*(w*x+y*z),single(1)-single(2)*(x*x+y*y));
    pitch=asin(min(single(1),max(single(-1),single(2)*(w*y-z*x))));
    yaw=atan2(single(2)*(x*y+w*z),single(1)-single(2)*(y*y+z*z));
    % Retain the original rounded radians/degrees factors and yaw offset.
    heldAngles=[pitch*single(57.29578);roll*single(57.29578); ...
        -(yaw*single(57.29578)+single(180))]*single(pi/180);
    heldBias=single(rawRates(:))-correctedRates;
end
angles=heldAngles;q=heldQuaternion;
% Keep the live gyro path when fusion is disabled; the retained residual bias
% is zero during startup and after reset. No extra sample delay is introduced.
rates=single(rawRates(:))-heldBias;
if run,rates=correctedRates;end
end
