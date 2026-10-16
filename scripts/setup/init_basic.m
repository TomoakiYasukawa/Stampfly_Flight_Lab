function p=init_basic()
%INIT_BASIC Initialize the basic flight model and its reduced logging buses.
p=init_official();
define('BasicLogPilotBus',{'Sticks','ArmButton','NewPacket','AHRSRequest'}, ...
    [6 1 1 1],{'single','uint8','uint8','uint8'});
define('BasicLogCommandBus', ...
    {'Duty','AppliedCounts','PWMStatus','PacketError','Connected','AltitudeEnabled', ...
     'PreviousMode','Mode','Dt','StartUs','UsedSticks','Pilot','OutputEnabled'}, ...
    [4 4 4 1 1 1 1 1 1 1 6 1 1], ...
    {'single','uint8','uint32','uint8','uint8','uint8','uint8','uint8', ...
     'single','uint32','single','Bus: BasicLogPilotBus','boolean'});
end
function define(name,names,dimensions,types)
elements(1,numel(names))=Simulink.BusElement;
for k=1:numel(names)
    elements(k).Name=names{k};elements(k).Dimensions=dimensions(k);elements(k).DataType=types{k};
end
bus=Simulink.Bus;bus.Elements=elements;bus.Description='StampFly basic flight logging interface';
assignin('base',name,bus);
end
