classdef FlatGroundPoseTracker < handle
    %FLATGROUNDPOSETRACKER Estimate display position above a flat floor.
    % SFI4 carries cumulative east/north estimated on the transmitter.
    % Older packets carry right/forward XY and are converted here for
    % playback compatibility.

    properties (SetAccess = private)
        EastNorthM (1,2) double = [0 0]
        HeightM (1,1) double = NaN
    end

    properties (Access = private)
        LastSourceXYM (1,2) double = [NaN NaN]
    end

    methods
        function [positionENU,heightNow] = update(obj,sample)
            if sample.Version >= 4
                % SFI4 carries the height calculated on StampFly.
                heightNow = double(sample.HeightM);
                heightValid = logical(sample.HeightValid) && ...
                    isfinite(heightNow) && heightNow >= 0;
            else
                % Older recordings only carry the slant range.
                [heightNow,heightValid,bodyToNED] = imu.correctToFHeight( ...
                    sample.ToFDistanceM,sample.ToFValid, ...
                    sample.Orientation,sample.OrientationValid);
            end
            if heightValid
                obj.HeightM = heightNow;
            end

            sourceXY = double(sample.XYDisplacementM(:).');
            if sample.Version >= 4
                if numel(sourceXY) == 2 && all(isfinite(sourceXY))
                    obj.EastNorthM = sourceXY;
                end
                positionENU = [obj.EastNorthM,obj.HeightM];
                return
            end
            if numel(sourceXY) == 2 && all(isfinite(sourceXY))
                if all(isfinite(obj.LastSourceXYM)) && heightValid
                    if double(sample.ToFDistanceM) > 1e-8
                        bodyXY = (sourceXY-obj.LastSourceXYM) * ...
                            (heightNow/double(sample.ToFDistanceM));
                    else
                        bodyXY = [0 0];
                    end
                    deltaNED = bodyToNED * [bodyXY(2);bodyXY(1);0];
                    if all(isfinite(deltaNED(1:2)))
                        obj.EastNorthM = obj.EastNorthM + ...
                            [deltaNED(2),deltaNED(1)];
                    end
                end
                obj.LastSourceXYM = sourceXY;
            else
                obj.LastSourceXYM = [NaN NaN];
            end
            positionENU = [obj.EastNorthM,obj.HeightM];
        end

        function reset(obj)
            obj.EastNorthM = [0 0];
            obj.HeightM = NaN;
            obj.LastSourceXYM = [NaN NaN];
        end
    end
end
