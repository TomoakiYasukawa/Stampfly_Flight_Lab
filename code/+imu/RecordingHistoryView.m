classdef RecordingHistoryView
    %RECORDINGHISTORYVIEW UI behavior for the logger's history tab.
    methods (Static)
        function refresh(app, newPath)
            if nargin < 2
                newPath = "";
            end
            state = app.HistoryList.UserData;
            if ~isstruct(state) || ~isfield(state,'ExtraPaths')
                state = struct('ExtraPaths',strings(0,1));
            end
            previous = strings(0,1);
            if strcmp(app.HistoryList.Enable,'on')
                previous = string(app.HistoryList.Value);
                previous = previous(:);
            end
            if strlength(string(newPath)) > 0
                state.ExtraPaths(end+1,1) = string(newPath);
            end
            folder = fullfile(fileparts(which('StampFlyIMUApp')),'recordings');
            files = dir(fullfile(folder,'*.mat'));
            [~,order] = sort([files.datenum],'descend');
            files = files(order);
            if isempty(files)
                paths = strings(0,1);
                labels = strings(0,1);
            else
                paths = string(fullfile({files.folder},{files.name})).';
                labels = string({files.name}).';
            end
            state.ExtraPaths = unique(state.ExtraPaths(isfile(state.ExtraPaths)),'stable');
            extra = state.ExtraPaths(~ismember(state.ExtraPaths,paths));
            extraLabels = strings(size(extra));
            for k = 1:numel(extra)
                [parent,name,ext] = fileparts(extra(k));
                [~,folderName] = fileparts(parent);
                extraLabels(k) = string(name) + string(ext) + " [" + string(folderName) + "]";
            end
            paths = [paths;extra];
            labels = [labels;extraLabels];
            app.HistoryList.UserData = state;
            if isempty(paths)
                app.HistoryList.ItemsData = {};
                app.HistoryList.Items = {'記録なし'};
                app.HistoryList.Enable = 'off';
                app.HistoryStatusLabel.Text = 'recordings にMAT記録がありません';
                app.HistorySummaryTable.Data = cell(0,7);
                return
            end
            chosen = previous(ismember(previous,paths));
            if strlength(string(newPath)) > 0 && ismember(string(newPath),paths)
                chosen = string(newPath);
            elseif isempty(chosen)
                chosen = paths(1);
            end
            app.HistoryList.ItemsData = {};
            app.HistoryList.Items = cellstr(labels);
            app.HistoryList.ItemsData = cellstr(paths);
            app.HistoryList.Enable = 'on';
            app.HistoryList.Value = cellstr(chosen);
            imu.RecordingHistoryView.show(app);
        end

        function addFile(app)
            folder = fullfile(fileparts(which('StampFlyIMUApp')),'recordings');
            [name,parent] = uigetfile({'*.mat','MAT記録 (*.mat)'}, ...
                '過去のStampFly記録を選択',folder);
            if isequal(name,0)
                return
            end
            imu.RecordingHistoryView.refresh(app,string(fullfile(parent,name)));
        end

        function show(app)
            timeAxes = [app.HistoryHeightAxes app.HistoryVerticalSpeedAxes ...
                app.HistoryHeightErrorAxes app.HistoryVelocityErrorAxes ...
                app.HistoryControlAxes app.HistoryThrottleAxes ...
                app.HistoryMotorAxes app.HistoryValidityAxes];
            axesList = [timeAxes app.HistoryXYAxes app.HistoryStateAxes];
            for ax = axesList
                delete(findall(ax,'Type','constantline'));
                cla(ax);
                legend(ax,'off');
                grid(ax,'on');
                hold(ax,'on');
            end
            title(app.HistoryHeightAxes,'高度: 補正値 / 生ToF');
            xlabel(app.HistoryHeightAxes,'離陸・記録開始からの時間 (s)');
            ylabel(app.HistoryHeightAxes,'高さ (cm)');
            title(app.HistoryVerticalSpeedAxes,'鉛直速度: 生 / フィルター / 目標');
            xlabel(app.HistoryVerticalSpeedAxes,'時間 (s)');
            ylabel(app.HistoryVerticalSpeedAxes,'速度 (m/s)');
            title(app.HistoryHeightErrorAxes,'高度誤差');
            xlabel(app.HistoryHeightErrorAxes,'時間 (s)');
            ylabel(app.HistoryHeightErrorAxes,'誤差 (cm)');
            title(app.HistoryVelocityErrorAxes,'鉛直速度誤差');
            xlabel(app.HistoryVelocityErrorAxes,'時間 (s)');
            ylabel(app.HistoryVelocityErrorAxes,'誤差 (m/s)');
            title(app.HistoryControlAxes,'高度制御: P / I / PI / 適用補正');
            xlabel(app.HistoryControlAxes,'時間 (s)');
            ylabel(app.HistoryControlAxes,'補正 (PWM)');
            title(app.HistoryThrottleAxes,'スロットル: 基準 / 制限前 / 制限後');
            xlabel(app.HistoryThrottleAxes,'時間 (s)');
            ylabel(app.HistoryThrottleAxes,'指令値 (0–255)');
            ylim(app.HistoryThrottleAxes,[0 255]);
            title(app.HistoryMotorAxes,'モーター指令: 単独は4軸 / 比較は平均');
            xlabel(app.HistoryMotorAxes,'離陸・記録開始からの時間 (s)');
            ylabel(app.HistoryMotorAxes,'指令値 (0–255)');
            ylim(app.HistoryMotorAxes,[0 255]);
            title(app.HistoryXYAxes,'相対XY (区間開始=0)');
            xlabel(app.HistoryXYAxes,'ΔX (m)');
            ylabel(app.HistoryXYAxes,'ΔY (m)');
            title(app.HistoryStateAxes,'飛行状態');
            xlabel(app.HistoryStateAxes,'離陸・記録開始からの時間 (s)');
            app.HistoryStateAxes.YTick = 0:4;
            app.HistoryStateAxes.YTickLabel = {'待機','離陸','ホバリング','着陸','非常停止'};
            ylim(app.HistoryStateAxes,[-0.3 4.3]);
            title(app.HistoryValidityAxes,'診断フラグ（各段の下=0・上=1）');
            xlabel(app.HistoryValidityAxes,'時間 (s)');
            ylabel(app.HistoryValidityAxes,'状態');
            app.HistorySummaryTable.Data = cell(0,7);
            if strcmp(app.HistoryList.Enable,'off')
                return
            end
            selected = string(app.HistoryList.Value);
            selected = selected(:);
            selected = selected(isfile(selected));
            if isempty(selected)
                app.HistoryStatusLabel.Text = '記録を選択してください';
                return
            end
            omitted = max(0,numel(selected)-6);
            selected = selected(1:min(6,numel(selected)));
            mode = string(app.HistoryRangeDropDown.Value);
            logs = cell(0,1);
            errors = strings(0,1);
            for k = 1:numel(selected)
                try
                    logs{end+1,1} = imu.readRecordingHistory(selected(k),mode); %#ok<AGROW>
                catch err
                    errors(end+1,1) = string(err.message); %#ok<AGROW>
                end
            end
            if isempty(logs)
                app.HistoryStatusLabel.Text = '選択したMATファイルを読めません';
                app.HistoryStatusLabel.Tooltip = char(strjoin(errors,newline));
                return
            end
            if isscalar(logs)
                title(app.HistoryHeightAxes,'高度: 補正値 / 生ToF');
                title(app.HistoryMotorAxes,'モーター指令: FR / FL / RR / RL');
                app.HistoryValidityAxes.YTick = 0.5:2:10.5;
                app.HistoryValidityAxes.YTickLabel = { ...
                    'ToF新規','ToF有効','補正高度','姿勢','高度制御','スロットル飽和'};
                ylim(app.HistoryValidityAxes,[-0.5 11.5]);
            else
                title(app.HistoryHeightAxes,'補正高度の比較');
                title(app.HistoryMotorAxes,'モーター指令の平均値');
                title(app.HistoryValidityAxes,'補正高度の有効状態');
                app.HistoryValidityAxes.YTick = [0 1];
                app.HistoryValidityAxes.YTickLabel = {'無効','有効'};
                ylim(app.HistoryValidityAxes,[-0.2 1.2]);
            end
            colors = lines(numel(logs));
            summary = cell(numel(logs),7);
            stateEvents = zeros(0,2);
            for k = 1:numel(logs)
                log = logs{k};
                stamp = regexp(char(log.Name), ...
                    'StampFly_([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})', ...
                    'tokens','once');
                if isempty(stamp)
                    name = sprintf('%d: %s',k,char(log.Name));
                else
                    name = sprintf('%d: %s/%s %s:%s:%s',k, ...
                        stamp{2},stamp{3},stamp{4},stamp{5},stamp{6});
                end
                t = log.Time;
                color = colors(k,:);
                stateNow = log.FlightState(:);
                changed = find(isfinite(stateNow) & ...
                    [false;stateNow(2:end) ~= stateNow(1:end-1)]);
                if mode == "firstFlight" && isfinite(stateNow(1)) && ...
                        stateNow(1) ~= 0
                    changed = [1;changed]; %#ok<AGROW>
                end
                stateEvents = [stateEvents; t(changed) stateNow(changed)]; %#ok<AGROW>
                if isscalar(logs) && any(isfinite(log.ToFM))
                    plot(app.HistoryHeightAxes,t,100*log.ToFM, ...
                        'Color',[0.35 0.35 0.35],'LineWidth',1.1, ...
                        'DisplayName','ToF斜距離');
                end
                if any(isfinite(log.HeightM))
                    plot(app.HistoryHeightAxes,t,100*log.HeightM, ...
                        'Color',color,'LineWidth',1.4,'DisplayName',[name ' 補正']);
                end
                if any(isfinite(log.ZReferenceM))
                    if isscalar(logs)
                        referenceName = '目標高度';
                        referenceColor = [0.10 0.10 0.10];
                    else
                        referenceName = [name ' 目標'];
                        referenceColor = color;
                    end
                    plot(app.HistoryHeightAxes,t,100*log.ZReferenceM, ...
                        '--','Color',referenceColor,'LineWidth',1.0, ...
                        'DisplayName',referenceName);
                end
                if isscalar(logs)
                    if any(isfinite(log.RawVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,t,log.RawVerticalVelocityMps, ...
                            'Color',[0.60 0.60 0.60],'LineWidth',0.9, ...
                            'DisplayName','生速度');
                    end
                    if any(isfinite(log.FilteredVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,t,log.FilteredVerticalVelocityMps, ...
                            'Color',[0.00 0.45 0.74],'LineWidth',1.4, ...
                            'DisplayName','フィルター後');
                    end
                    if any(isfinite(log.VerticalVelocityReferenceMps))
                        plot(app.HistoryVerticalSpeedAxes,t, ...
                            log.VerticalVelocityReferenceMps,'k--', ...
                            'LineWidth',1.0,'DisplayName','目標速度');
                    end
                else
                    if any(isfinite(log.FilteredVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,t, ...
                            log.FilteredVerticalVelocityMps, ...
                            'Color',color,'LineWidth',1.2,'DisplayName',name);
                    end
                end
                if any(isfinite(log.ZErrorM))
                    plot(app.HistoryHeightErrorAxes,t,100*log.ZErrorM, ...
                        'Color',color,'LineWidth',1.2,'DisplayName',name);
                end
                if any(isfinite(log.VerticalVelocityErrorMps))
                    plot(app.HistoryVelocityErrorAxes,t, ...
                        log.VerticalVelocityErrorMps, ...
                        'Color',color,'LineWidth',1.2,'DisplayName',name);
                end
                if isscalar(logs)
                    controlValues = {log.VerticalPTerm,log.VerticalIResidual, ...
                        log.VerticalPIOutput,log.AppliedHeightCorrection};
                    controlLabels = {'速度P','速度I残差','PI出力','適用補正'};
                    controlColors = [0.00 0.45 0.74; 0.85 0.33 0.10; ...
                        0.47 0.20 0.60; 0.20 0.60 0.30];
                    for j = 1:numel(controlValues)
                        if any(isfinite(controlValues{j}))
                            plot(app.HistoryControlAxes,t,controlValues{j}, ...
                                'Color',controlColors(j,:), ...
                                'LineWidth',1.2,'DisplayName',controlLabels{j});
                        end
                    end
                    throttleValues = {log.BaseThrottle, ...
                        log.ThrottleBeforeLimit,log.ThrottleAfterLimit};
                    throttleLabels = {'基準','制限前','制限後'};
                    throttleColors = [0.55 0.55 0.55; 0.85 0.33 0.10; ...
                        0.00 0.45 0.74];
                    for j = 1:numel(throttleValues)
                        if any(isfinite(throttleValues{j}))
                            plot(app.HistoryThrottleAxes,t,throttleValues{j}, ...
                                'Color',throttleColors(j,:), ...
                                'LineWidth',1.2,'DisplayName',throttleLabels{j});
                        end
                    end
                    flags = {log.ToFFresh,log.ToFValid, ...
                        log.HeightValid,log.OrientationValid, ...
                        log.HeightControlEnabled,log.ThrottleSaturated};
                    flagColors = lines(numel(flags));
                    for j = 1:numel(flags)
                        if any(isfinite(flags{j}))
                            flagValue = nan(size(flags{j}));
                            known = isfinite(flags{j});
                            flagValue(known) = 2*(j-1) + ...
                                double(flags{j}(known) >= 0.5);
                            stairs(app.HistoryValidityAxes,t, ...
                                flagValue, ...
                                'Color',flagColors(j,:), ...
                                'LineWidth',1.1,'HandleVisibility','off');
                        end
                    end
                else
                    if any(isfinite(log.AppliedHeightCorrection))
                        plot(app.HistoryControlAxes,t, ...
                            log.AppliedHeightCorrection,'Color',color, ...
                            'LineWidth',1.2,'DisplayName',name);
                    end
                    if any(isfinite(log.ThrottleAfterLimit))
                        plot(app.HistoryThrottleAxes,t,log.ThrottleAfterLimit, ...
                            'Color',color,'LineWidth',1.2,'DisplayName',name);
                    end
                    if any(isfinite(log.HeightValid))
                        heightValid = nan(size(log.HeightValid));
                        known = isfinite(log.HeightValid);
                        heightValid(known) = double(log.HeightValid(known) >= 0.5);
                        stairs(app.HistoryValidityAxes,t, ...
                            heightValid, ...
                            'Color',color,'LineWidth',1.1,'DisplayName',name);
                    end
                end
                if isscalar(logs)
                    motorNames = {'FR','FL','RR','RL'};
                    motorColors = lines(4);
                    for j = 1:4
                        if any(isfinite(log.Motors(:,j)))
                            plot(app.HistoryMotorAxes,t,log.Motors(:,j), ...
                                'Color',motorColors(j,:),'LineWidth',1.1, ...
                                'DisplayName',motorNames{j});
                        end
                    end
                else
                    motorMean = mean(log.Motors,2,'omitnan');
                    if any(isfinite(motorMean))
                        plot(app.HistoryMotorAxes,t,motorMean, ...
                            'Color',color,'LineWidth',1.2,'DisplayName',name);
                    end
                end
                if any(all(isfinite(log.XYM),2))
                    xy = log.XYM;
                    origin = find(all(isfinite(xy),2),1);
                    xy = xy-xy(origin,:);
                    plot(app.HistoryXYAxes,xy(:,1),xy(:,2), ...
                        'Color',color,'DisplayName',name);
                end
                if any(isfinite(log.FlightState))
                    stairs(app.HistoryStateAxes,t,log.FlightState, ...
                        'Color',color,'LineWidth',1.2,'DisplayName',name);
                end
                summary{k,1} = char(log.Name);
                summary{k,2} = log.TotalFrames;
                summary{k,3} = round(log.DurationSeconds,1);
                summary{k,4} = round(log.HoverMeanCM,1);
                if all(isfinite(log.HeightRangeCM))
                    summary{k,5} = sprintf('%.1f–%.1f',log.HeightRangeCM);
                else
                    summary{k,5} = '—';
                end
                summary{k,6} = log.MissingFrames;
                summary{k,7} = log.CRCRejected;
            end
            app.HistorySummaryTable.Data = summary;
            % Align every diagnostic time series at each flight-state change.
            stateEvents(:,1) = round(stateEvents(:,1),2);
            stateEvents = unique(stateEvents,'rows','stable');
            stateEvents = sortrows(stateEvents,1);
            stateNames = {'待機','離陸','ホバリング','着陸','非常停止'};
            stateColors = [0.45 0.45 0.45; 0.10 0.55 0.20; ...
                0.00 0.45 0.74; 0.85 0.35 0.05; 0.75 0.10 0.10];
            lastTime = max(cellfun(@(item) item.Time(end),logs));
            for ax = timeAxes
                hasPlot = ~isempty(allchild(ax));
                labeledStates = false(1,numel(stateNames));
                for eventIndex = 1:size(stateEvents,1)
                    if ~hasPlot
                        break
                    end
                    eventTime = stateEvents(eventIndex,1);
                    stateId = stateEvents(eventIndex,2);
                    if stateId < 0 || stateId > 4 || stateId ~= fix(stateId)
                        continue
                    end
                    alignment = 'right';
                    if eventTime > 0.7*lastTime
                        alignment = 'left';
                    end
                    label = '';
                    showLabel = ax == app.HistoryHeightAxes || ...
                        ax == app.HistoryMotorAxes;
                    if showLabel && (isscalar(logs) || ~labeledStates(stateId+1))
                        label = stateNames{stateId+1};
                        labeledStates(stateId+1) = true;
                    end
                    xline(ax,eventTime,'--',label, ...
                        'Color',stateColors(stateId+1,:), ...
                        'LineWidth',1.2,'FontSize',10, ...
                        'LabelOrientation','horizontal', ...
                        'LabelVerticalAlignment','bottom', ...
                        'LabelHorizontalAlignment',alignment, ...
                        'HandleVisibility','off');
                end
                padding = max(0.2,0.02*lastTime);
                xlim(ax,[0 lastTime+padding]);
            end
            xlim(app.HistoryStateAxes,[0 lastTime+max(0.2,0.02*lastTime)]);
            for ax = axesList
                hold(ax,'off');
                if any(arrayfun(@(item) isprop(item,'DisplayName') && ...
                        ~isempty(item.DisplayName) && ...
                        strcmp(item.HandleVisibility,'on'),ax.Children))
                    legend(ax,'show','Location','best');
                end
            end
            if ~isempty(app.HistoryXYAxes.Children)
                axis(app.HistoryXYAxes,'equal');
            end
            message = sprintf('%d件表示 / %d件選択',numel(logs),numel(string(app.HistoryList.Value)));
            if omitted > 0
                message = sprintf('%s（比較上限6件）',message);
            end
            if ~isempty(errors)
                message = sprintf('%s、読込失敗%d件',message,numel(errors));
            end
            app.HistoryStatusLabel.Text = message;
            app.HistoryStatusLabel.Tooltip = char(strjoin(errors,newline));
        end
    end
end
