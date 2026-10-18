function direction = flowDisplaySign(buildID)
%FLOWDISPLAYSIGN Align the official logger's east/north display with the drone.
% Build 1401 was checked by hand: forward was -N and right was -E.
% Reverse both horizontal axes for display; recorded packet values stay raw.
% Earlier stampfly_imu_monitor builds already use the intended directions.
direction = ones(size(buildID));
direction(buildID == 1401) = -1;
end
