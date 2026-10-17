function name=flightStateName(state)
%FLIGHTSTATENAME 概要：モード番号をStateflowと一致する日本語名にします。
states=imu.flightStateDefinition();
index=find(states.Codes==double(state),1);
if isempty(index)
    name=sprintf('不明 (%g)',double(state));
else
    name=states.Names{index};
end
end
