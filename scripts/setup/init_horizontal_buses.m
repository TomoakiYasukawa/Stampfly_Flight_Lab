function init_horizontal_buses()
%INIT_HORIZONTAL_BUSES 水平推定の固定型・固定サイズの信号境界を定義します。
define('HorizontalFlowBus',{'Delta','Raw','Info','Totals'},[2 8 4 2],{'single','uint16','uint32','uint32'});
define('HorizontalInertialBus',{'Quaternion','RawAngularRate','StaticOffsets','FilteredRate','CorrectedRate','Fresh','ReadValid'}, ...
    [4 3 4 3 3 1 1],{'single','single','single','single','single','uint8','uint8'});
define('HorizontalRangeBus',{'DistanceMm','Fresh','Status','VerticalSpeed'},[1 1 1 1],{'int16','uint8','uint8','single'});
define('HorizontalContextBus',{'Dt','Reset','PoseReady'},[1 1 1],{'single','boolean','boolean'});
define('HorizontalMotionBus',{'Position','Velocity','Heading','Height','Status','Diagnostics'}, ...
    [2 2 1 1 8 8],{'single','single','single','single','single','single'});
% 水平補助が使う制御条件だけを、既存バスから固定型へまとめます。
define('HorizontalFlightContextBus',{'Branch'},1,{'uint8'});
define('HorizontalControlGatesBus',{'Run','Reset','AltitudeEnabled'},[1 1 1],{'boolean','boolean','boolean'});
define('HorizontalControlContextBus',{'Dt','ControlMode','FlightContext','ControlContext'},[1 1 1 1], ...
    {'single','uint8','Bus: HorizontalFlightContextBus','Bus: HorizontalControlGatesBus'});
end
function define(name,names,dims,types)
elements(1,numel(names))=Simulink.BusElement;
for k=1:numel(names)
    elements(k).Name=names{k};elements(k).Dimensions=dims(k);elements(k).DataType=types{k};
end
bus=Simulink.Bus;bus.Elements=elements;
bus.Description='水平補助の固定サイズ境界。局所X=基準機首、Y=右。';
assignin('base',name,bus);
end
