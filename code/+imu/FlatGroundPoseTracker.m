classdef FlatGroundPoseTracker < handle
    %FLATGROUNDPOSETRACKER Estimate display position above a flat floor.
    % SFI4 carries cumulative east/north estimated on the transmitter.
    % The official logger's horizontal display axes are reversed together.
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
            % 表示の「補正高さ」は同じToF測定の鉛直投影値。
            % sample.HeightM は飛行制御のKalman高度で、傾き補正値とは別。
            [heightNow,heightValid,bodyToNED] = imu.correctToFHeight( ...
                sample.ToFDistanceM,sample.ToFValid, ...
                sample.Orientation,sample.OrientationValid);
            if heightValid
                obj.HeightM = heightNow;
            end

            sourceXY = double(sample.XYDisplacementM(:).');
            if sample.Version >= 4
                if numel(sourceXY) == 2 && all(isfinite(sourceXY))
                    obj.EastNorthM = imu.flowDisplaySign(sample.BuildID)*sourceXY;
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
