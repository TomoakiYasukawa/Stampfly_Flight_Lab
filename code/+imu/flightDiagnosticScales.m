function scales = flightDiagnosticScales()
%FLIGHTDIAGNOSTICSCALES Counts per physical unit in the SFI7 extension.
% Keep this list aligned with MatRecordingWriter's diagnostic column names.
scales = single([ ...
    1000; 1; 1; ...                         % Battery V, validity, ToF fresh
    1000; 1000; 1000; 1000; 1000; 1000;   % Height and vertical speeds
    10; 10; 10; 10; 10; 10; 10; 1; 1;     % Throttle path and flags
    10; 10; 10; 10;                         % Mixer before saturation
    1000; 1000; 1000;                       % Received flight parameters
    1000; 100; 100; 1000; 10; 10; 10]);  % Deployed tuning values
end
