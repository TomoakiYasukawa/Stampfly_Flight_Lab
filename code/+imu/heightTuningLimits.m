function [lower,upper] = heightTuningLimits()
%HEIGHTTUNINGLIMITS Allowed complete height-control parameter set.
% Order is defined in heightTuningScales.
lower = single([0;0;0;0.02;0;0;0;0.05;0]);
upper = single([10;300;100;1;100;255;255;2;255]);
end
