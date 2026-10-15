function [duty,counts,diagnostics,s] = controllerStep(stick,attitude,rates,height,velocity,voltage,rangeFlag,overG,mode,h,s)
%CONTROLLERSTEP Official get_command -> angle_control -> rate_control.
% stick = [aileron;elevator;rudder;throttle;controlMode;altMode].
% mode: 2 flight, 3 parking, 5 landing; others output zero.
% Motor order throughout: FR FL RR RL. Optical flow is intentionally absent.
% Derived from M5StampFly/src/flight_control.cpp (MIT; see official LICENSE).
%#codegen
duty = zeros(4,1,'single'); counts = zeros(4,1,'uint8');
before = zeros(4,1,'single'); torque = zeros(3,1,'single');
angleCmd = min(max(single(0.4*double(stick(1:2))),single(-1)),single(1));
yawCmd = min(max(stick(3),single(-1)),single(1));
rateRef = zeros(3,1,'single'); thrust = single(0); altFlag = false;
if mode == uint8(3)
    % Official parking does NOT reset the PID states or stick centers here.
    s.baseDuty = single(0); s.altRef = single(0.5); s.counter = uint16(0);
    s.landing = false; s.thrustFilter = single(0); s.dutyFilter(:) = single(0);
elseif mode == uint8(2) || mode == uint8(5)
    if mode == uint8(2)
        if uint8(stick(6)) == uint8(4)
            altFlag = true;
            if s.counter < uint16(500)
                s.baseDuty = min(single(s.counter)/single(1000),trim(single(3.8)));
                s.counter = s.counter+uint16(1);
            elseif s.counter < uint16(1000)
                s.baseDuty = min(single(s.counter)/single(1000),trim(voltage));
                s.counter = s.counter+uint16(1);
            else
                s.baseDuty = trim(voltage);
            end
            th = stick(4);
            if th > single(-0.2) && th < single(0.2), th = single(0); end
            s.altRef = min(max(single(double(s.altRef)+double(th)*0.001),single(0.05)),single(1.8));
            if rangeFlag > s.rangeOld || rangeFlag == uint8(20)
                s.baseDuty = s.baseDuty-single(0.02); s.rangeOld = rangeFlag;
            end
            thrust = single(double(s.baseDuty)*3.7);
        else
            th = min(max(stick(4),single(0)),single(1));
            if th > single(-0.2) && th < single(0.2), th = single(0); end
            rawThrust = single((0.00413+double(single(3.3)*th-single(5.44)*th*th+single(3.13)*th*th*th))*3.7);
            s.thrustFilter = official.filterStep(rawThrust,h,single(0.01),s.thrustFilter);
            thrust = s.thrustFilter;
        end
    else
        if ~s.landing
            s.landing = true; s.landHistory(:) = height; s.baseDuty = trim(voltage);
        end
        if s.landHistory(10) >= height, s.baseDuty = single(double(s.baseDuty)*0.9999); end
        if height < single(0.15), s.baseDuty = single(double(s.baseDuty)*0.999); end
        % Preserve official ascending-copy quirk: all history slots become old[0].
        for j = 2:10, s.landHistory(j) = s.landHistory(j-1); end
        s.landHistory(1) = height;
        % Thrust_command is held from previous tick in official landing.
        thrust = s.lastThrust;
    end
    rateRef(3) = single(2*pi*double(yawCmd-s.centers(3)));
    if uint8(stick(5)) == uint8(1)
        rateRef(1) = rateCommand(stick(1)); rateRef(2) = rateCommand(stick(2));
    end
    if double(thrust)/3.7 < double(single(0.1))
        % reset_angle_control then reset_rate_control, as in the original.
        s.pid(:) = single(0); s.pid(3,1:2) = s.angleRef';
        s.centers(1:2) = angleCmd; s.centers(3) = yawCmd;
        s.dutyFilter(:) = single(0); rateRef(:) = single(0);
    else
        if altFlag
            [s.zRef,s.pid(:,3)] = official.pidStep(s.altRef-height,h,single([0.38 10 0.5 0.125]),s.pid(:,3));
        end
        if uint8(stick(5)) == uint8(0)
            limit = single(30*pi/180);
            s.angleRef = min(max(single(0.5*pi*double(angleCmd-s.centers(1:2))),-limit),limit);
            [rateRef(1),s.pid(:,1)] = official.pidStep(s.angleRef(1)-attitude(1),h,single([5 4 0.04 0.125]),s.pid(:,1));
            [rateRef(2),s.pid(:,2)] = official.pidStep(s.angleRef(2)-attitude(2),h,single([5 4 0.04 0.125]),s.pid(:,2));
        end
        [torque(1),s.pid(:,4)] = official.pidStep(rateRef(1)-rates(1),h,single([0.65 0.7 0.01 0.125]),s.pid(:,4));
        [torque(2),s.pid(:,5)] = official.pidStep(rateRef(2)-rates(2),h,single([0.95 0.7 0.025 0.125]),s.pid(:,5));
        [torque(3),s.pid(:,6)] = official.pidStep(rateRef(3)-rates(3),h,single([3 0.8 0.01 0.125]),s.pid(:,6));
        if altFlag || mode == uint8(5)
            vRef = s.zRef;
            if mode == uint8(5), vRef = single(-0.15); end
            [correction,s.pid(:,7)] = official.pidStep(vRef-velocity,h,single([0.08 0.95 0.08 0.125]),s.pid(:,7));
            s.thrustFilter = official.filterStep(single(double(s.baseDuty+correction)*3.7),h,single(0.01),s.thrustFilter);
            thrust = s.thrustFilter;
            if altFlag
                if double(thrust)/3.7 > double(single(s.baseDuty*single(1.15)))
                    thrust = single(3.7*double(s.baseDuty)*double(single(1.15)));
                end
                if double(thrust)/3.7 < double(single(s.baseDuty*single(0.85)))
                    thrust = single(3.7*double(s.baseDuty)*double(single(0.85)));
                end
            end
        end
        mix = single([-1 1 1;1 1 -1;-1 -1 -1;1 -1 1]);
        for j = 1:4
            combination = mix(j,1)*torque(1)+mix(j,2)*torque(2)+mix(j,3)*torque(3);
            before(j) = single(double(thrust+combination*single(0.25))/3.7);
            s.dutyFilter(j) = official.filterStep(before(j),h,single(0.003),s.dutyFilter(j));
        end
        duty = min(max(s.dutyFilter,single(0)),single(0.95));
        if overG ~= 0, duty(:) = single(0); end
        counts = uint8(floor(single(255)*duty)); % C cast truncates, MATLAB uint8 rounds.
    end
end
if mode == uint8(3), thrust=s.lastThrust; else, s.lastThrust=thrust; end
diagnostics = [s.altRef;s.baseDuty;single(s.counter);s.zRef;thrust; ...
    s.angleRef;rateRef;torque;before];
end

function y = trim(v)
y = -single(0.2448)*v+single(1.5892);
end

function y = rateCommand(x)
x = min(max(x,single(-1)),single(1));
a = abs(x); t = a*(a*a*a*a*a*single(0.5)+a*single(0.5));
y = single(pi/180)*((single(1600)-single(70))*t+single(70)*a);
if x < 0, y = -y; end
end
