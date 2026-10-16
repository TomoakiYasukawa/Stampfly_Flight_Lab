function [accelMps2,gyroRps,run,filterReset]=IMUFilterInputs(rates,accelG,mode,reset)
%IMUFILTERINPUTS Match the previous estimator axes and use gravity-positive NED.
%#codegen
% The previous Madgwick frame is [bodyY bodyX -bodyZ]. Its accelerometer
% vector has +g on Z at rest. NED IMU Filter uses the same gravity sign.
accelMps2=single([accelG(2),accelG(1),-accelG(3)])*single(9.80665);
gyroRps=single([rates(2),rates(1),-rates(3)]);
run=mode>uint8(1);
% A disabled subsystem does not execute its Reset port. Retain reset requests
% during calibration/hold and apply them before the next fusion update.
persistent pendingReset
if isempty(pendingReset),pendingReset=false;end
if reset,pendingReset=true;end
filterReset=pendingReset;
if run,pendingReset=false;end
end
