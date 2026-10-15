function paths = setup_imu_monitor()
%SETUP_IMU_MONITOR Use only this project's copied sensor and logger files.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'config'));
paths = configure_stampfly_project();
end
