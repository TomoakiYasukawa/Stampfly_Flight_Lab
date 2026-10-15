function app = run_stampfly_imu_app()
%RUN_STAMPFLY_IMU_APP Open the App Designer plain-text logger.
setup_imu_monitor();
app = StampFlyIMUApp();
end
