function init()
%INIT 閉ループ試験で剛体の真値を実制御ブロックへ渡す固定型境界です。
init_imu_flight();
define('HorizontalTestAttitudeBus',{'Angles','Quaternion','AngularRate'},[3 4 3],{'single','single','single'});
define('HorizontalTestVerticalBus',{'Altitude','Velocity'},[1 1],{'single','single'});
define('HorizontalTestPilotBus',{'Sticks','BatteryVoltage','Dt','Flags'},[6 1 1 3],{'single','single','single','uint8'});
define('HorizontalTestSupervisorBus',{'Branch','PreMode','AttitudeReset','ParkingReset','Connected'}, ...
    [1 1 1 1 1],{'uint8','uint8','boolean','boolean','uint8'});
end
function define(name,names,dimensions,types)
elements(1,numel(names))=Simulink.BusElement;
for k=1:numel(names),elements(k).Name=names{k};elements(k).Dimensions=dimensions(k);elements(k).DataType=types{k};end
bus=Simulink.Bus;bus.Elements=elements;assignin('base',name,bus);
end
