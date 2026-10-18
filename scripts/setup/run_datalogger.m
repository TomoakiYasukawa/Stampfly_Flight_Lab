function app = run_datalogger()
%RUN_DATALOGGER Open the App Designer plain-text logger.
setup_imu_monitor();
app = DataLogger();
end
