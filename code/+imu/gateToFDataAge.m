function [ageS,valid,rangeStatus] = gateToFDataAge( ...
        ageS,freshValid,rangeM,rangeStatus,pollTimeS,maxAgeS)
%GATETOFDATAAGE Expire a held ToF range without accepted measurements.
% The driver can report new data without updating its held valid range.
if freshValid ~= 0
    ageS = single(0);
else
    ageS = min(single(ageS)+single(pollTimeS),single(1e3));
end
valid = uint8(rangeStatus == 0 && rangeM > 0 && ageS <= maxAgeS);
if ageS > maxAgeS && rangeStatus == 0 && rangeM > 0
    rangeStatus = uint8(91); % Host-side stale-data diagnosis.
end
end
