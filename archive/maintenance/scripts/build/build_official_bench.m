function build_official_bench()
%BUILD_OFFICIAL_BENCH Build the motor-disabled firmware without downloading.
init_official;
root=stampfly_project_root();
configure_stampfly_project();
cd(root);
model='StampFly_Official_Bench400';open_system(model);
pwmBlocks=find_system(model,'LookUnderMasks','all','BlockType','MATLABSystem','System','official.MotorPWM400');
assert(numel(pwmBlocks)==1,'official:PWMSingleOwner','Expected one PWM writer.');
pwm=pwmBlocks{1};
assert(strcmp(get_param(pwm,'AllowMotorOutput'),'false'), ...
    'official:MotorInterlock','Bench firmware must disable physical motor output.');
d=get_param(model,'CoderTargetData');
assert(strcmp(d.Runtime.BuildAction,'Build'),'official:BuildOnly', ...
    'Select build only before building; deployment is handled separately.');
slbuild(model);
end
