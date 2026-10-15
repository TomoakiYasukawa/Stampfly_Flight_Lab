function run_control_layout_checks()
%RUN_CONTROL_LAYOUT_CHECKS Use a fresh process; never access the USB devices.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'config'));configure_stampfly_project();
Simulink.fileGenControl('set','CacheFolder',fullfile(root,'build','control_layout_checks','cache'), ...
    'CodeGenFolder',fullfile(root,'build','control_layout_checks'),'createDir',true);
report=verify_control_layout400();disp(report);
in=Simulink.SimulationInput('StampFly_Official_FlightTest400');
in=in.setModelParameter('StopTime','0');out=sim(in); %#ok<NASGU>
fprintf('CONTROL_LAYOUT_FULL_MODEL_COMPILE_PASSED\n');
end
