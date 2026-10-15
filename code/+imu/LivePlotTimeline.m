classdef LivePlotTimeline < handle
    %LIVEPLOTTIMELINE Keep the monitor's time axis continuous across reboots.
    % 保存する生タイムスタンプは変えず、表示だけを接続開始からの秒にする。
    properties (Access = private)
        LastDeviceTime = NaN
        LastDisplayTime = NaN
        LastHostTime = NaN
        LastSequence = NaN
        NominalStep = 0.02
    end

    methods
        function [time,restarted,accepted] = advance(obj,deviceTime,sequence,hostTime)
            time = obj.LastDisplayTime;
            restarted = false;
            accepted = false;
            deviceTime = double(deviceTime);
            sequence = double(sequence);
            if ~isfinite(deviceTime) || deviceTime < 0
                return
            end
            if isnan(obj.LastDeviceTime)
                time = 0;
            else
                elapsed = deviceTime-obj.LastDeviceTime;
                sequenceStep = mod(sequence-obj.LastSequence,65536);
                if elapsed == 0 && sequenceStep == 0
                    return % 同じフレームを二重に描画しない。
                end
                if elapsed < 0
                    if obj.LastDeviceTime > 2^32/1000-1 && deviceTime < 1
                        elapsed = elapsed+2^32/1000;
                    elseif elapsed < -0.5 || (sequence <= 1 && deviceTime < 0.5)
                        restarted = true;
                        elapsed = max(obj.NominalStep,hostTime-obj.LastHostTime);
                    else
                        return % 遅れて届いた古いフレームで時間軸を戻さない。
                    end
                elseif elapsed > 0 && elapsed < 1 && sequenceStep > 0 && sequenceStep < 32768
                    obj.NominalStep = elapsed/sequenceStep;
                end
                time = obj.LastDisplayTime+elapsed;
            end
            obj.LastDeviceTime = deviceTime;
            obj.LastDisplayTime = time;
            obj.LastHostTime = hostTime;
            obj.LastSequence = sequence;
            accepted = true;
        end

        function reset(obj)
            obj.LastDeviceTime = NaN;
            obj.LastDisplayTime = NaN;
            obj.LastHostTime = NaN;
            obj.LastSequence = NaN;
            obj.NominalStep = 0.02;
        end
    end
end
