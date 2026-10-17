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
            folder = imu.recordingFolder(app);
            app.HistoryFolderLabel.Text = char("保存先: " + folder);
            app.HistoryFolderLabel.Tooltip = char(folder);
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
                app.HistoryStatusLabel.Text = '選択した保存先にMAT記録がありません';
                app.HistorySummaryTable.Data = cell(0,8);
                imu.RecordingHistoryView.show(app);
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
            folder = imu.recordingFolder(app);
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
                % HandleVisibility='off'の診断線も消し、一覧更新で重ねません。
                delete(allchild(ax));
                cla(ax);
                legend(ax,'off');
                grid(ax,'on');
                hold(ax,'on');
            end
            title(app.HistoryHeightAxes,'高度: 制御用推定 / ToF');
            xlabel(app.HistoryHeightAxes,'飛行制御開始からの時間 (s、負値は直前記録)');
            ylabel(app.HistoryHeightAxes,'高さ (cm)');
            title(app.HistoryVerticalSpeedAxes,'鉛直速度: 推定 / 高度変化率 / 目標（上昇＋）');
            xlabel(app.HistoryVerticalSpeedAxes,'時間 (s)');
            ylabel(app.HistoryVerticalSpeedAxes,'上昇速度 (m/s)');
            title(app.HistoryHeightErrorAxes,'高度誤差');
            xlabel(app.HistoryHeightErrorAxes,'時間 (s)');
            ylabel(app.HistoryHeightErrorAxes,'誤差 (cm)');
            title(app.HistoryVelocityErrorAxes,'鉛直速度誤差');
            xlabel(app.HistoryVelocityErrorAxes,'時間 (s)');
            ylabel(app.HistoryVelocityErrorAxes,'誤差 (m/s)');
            title(app.HistoryControlAxes,'高度制御: 基準からの共通推力差');
            xlabel(app.HistoryControlAxes,'時間 (s)');
            ylabel(app.HistoryControlAxes,'デューティ相当 (0–1)');
            title(app.HistoryThrottleAxes,'スロットル: 基準 / 共通推力 / モーター平均');
            xlabel(app.HistoryThrottleAxes,'時間 (s)');
            ylabel(app.HistoryThrottleAxes,'デューティ指令 (0–1)');
            ylim(app.HistoryThrottleAxes,[0 1]);
            title(app.HistoryMotorAxes,'モーター指令: 単独は4軸 / 比較は平均');
            xlabel(app.HistoryMotorAxes,'飛行制御開始からの時間 (s)');
            ylabel(app.HistoryMotorAxes,'指令値 (0–255)');
            ylim(app.HistoryMotorAxes,[0 255]);
            title(app.HistoryXYAxes,'相対XY (区間開始=0)');
            xlabel(app.HistoryXYAxes,'ΔX (m)');
            ylabel(app.HistoryXYAxes,'ΔY (m)');
            title(app.HistoryStateAxes,'飛行状態');
            xlabel(app.HistoryStateAxes,'飛行制御開始からの時間 (s)');
            states=imu.flightStatePresentation();
            app.HistoryStateAxes.YTick = states.Levels;
            app.HistoryStateAxes.YTickLabel = states.Names;
            ylim(app.HistoryStateAxes,[-0.3 numel(states.Codes)-0.7]);
            title(app.HistoryValidityAxes,'診断: 各帯の下=OFF・上=ON、空白=未記録');
            xlabel(app.HistoryValidityAxes,'時間 (s)');
            ylabel(app.HistoryValidityAxes,'状態');
            app.HistorySummaryTable.Data = cell(0,8);
            app.HistorySummaryTable.ColumnName={'記録','フレーム','期間(s)', ...
                '飛行平均高度(cm)','高度範囲(cm)','欠落','CRC','保存終了理由'};
            app.HistoryDataLabel.Text = '表示データ: 未選択';
            for ax=axesList
                ax.Subtitle.String='表示データ: 未選択';
                ax.Subtitle.Interpreter='none';
                ax.Title.Interpreter='none';
                ax.UserData=struct('SourceFiles',strings(0,1));
            end
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
                    logs{end+1,1} = imu.readRecordingHistory( ...
                        selected(k),mode,5000,double(app.ExpectedBuildID)); %#ok<AGROW>
                catch err
                    errors(end+1,1) = string(err.message); %#ok<AGROW>
                end
            end
            if isempty(logs)
                app.HistoryStatusLabel.Text = '選択したMATファイルを読めません';
                app.HistoryStatusLabel.Tooltip = char(strjoin(errors,newline));
                return
            end
            display=imu.flightStatePresentation(logs{1}.StateSchema);
            sameSchema=all(cellfun(@(item)strcmp(item.StateSchema,logs{1}.StateSchema),logs));
            if ~sameSchema,display=imu.flightStatePresentation('unknown');end
            app.HistoryStateAxes.YTick=display.Levels;
            app.HistoryStateAxes.YTickLabel=display.Names;
            ylim(app.HistoryStateAxes,[-.3 numel(display.Codes)-.7]);
            fileNames=string(cellfun(@(item)char(item.Name),logs,'UniformOutput',false));
            sourceLabel="表示データ: "+strjoin(fileNames," / ");
            app.HistoryDataLabel.Text=char(sourceLabel);
            app.HistoryDataLabel.Tooltip=char(strjoin(selected,newline));
            for ax=axesList
                ax.Subtitle.String=char(sourceLabel);
                ax.Subtitle.FontSize=9;
                ax.UserData=struct('SourceFiles',selected);
            end
            if logs{1}.IsOfficialFixedPID
                app.HistoryControlAxes.Subtitle.String=char(sourceLabel);
                app.HistoryControlAxes.UserData.Note= ...
                    'SFIXのThrustCommand/3.7−BaseDuty。10ms平滑化・制限後の差で、PIDのP/I/D個別項ではありません。';
            else
                title(app.HistoryControlAxes,'旧高度制御: P / I / PI / 適用補正');
                ylabel(app.HistoryControlAxes,'補正 (PWM)');
                title(app.HistoryThrottleAxes,'旧スロットル: 基準 / 制限前 / 制限後');
            end
            if isscalar(logs)
                title(app.HistoryHeightAxes,'高度: 制御用推定 / ToF斜距離 / ToF鉛直投影');
                title(app.HistoryMotorAxes,'モーター指令: FR / FL / RR / RL');
                app.HistoryValidityAxes.YTick = (0:5)*3+.35;
                app.HistoryValidityAxes.YTickLabel = { ...
                    'ToF新規','ToF有効','推定高度','姿勢','高度制御','スロットル飽和'};
                ylim(app.HistoryValidityAxes,[-.5 16.2]);
            else
                title(app.HistoryHeightAxes,'制御用推定高度の比較');
                title(app.HistoryMotorAxes,'モーター指令の平均値');
                title(app.HistoryValidityAxes,'記録別の推定高度: 下=無効・上=有効');
                app.HistoryValidityAxes.YTick = (0:numel(logs)-1)*3+.35;
                app.HistoryValidityAxes.YTickLabel = cellstr("記録 "+string(1:numel(logs)));
                ylim(app.HistoryValidityAxes,[-.5 3*(numel(logs)-1)+1.2]);
            end
            colors = lines(numel(logs));
            summary = cell(numel(logs),8);
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
                plotLog=imu.RecordingHistoryView.breakLines(log);
                tp=plotLog.Time;
                color = colors(k,:);
                stateNow = log.FlightState(:);
                changed = find(isfinite(stateNow) & ...
                    [false;stateNow(2:end) ~= stateNow(1:end-1)]);
                if isfinite(stateNow(1))
                    changed = [1;changed]; %#ok<AGROW>
                end
                stateEvents = [stateEvents; t(changed) stateNow(changed)]; %#ok<AGROW>
                if isscalar(logs) && any(isfinite(log.ToFM))
                    plot(app.HistoryHeightAxes,tp,100*plotLog.ToFM, ...
                        'Color',[0.35 0.35 0.35],'LineWidth',1.1, ...
                        'DisplayName','ToF斜距離');
                    plot(app.HistoryHeightAxes,tp,100*plotLog.CorrectedToFM, ...
                        ':','Color',[.20 .55 .20],'LineWidth',1.1, ...
                        'DisplayName','ToF鉛直投影（傾き補正）');
                end
                if any(isfinite(log.HeightM))
                    plot(app.HistoryHeightAxes,tp,100*plotLog.HeightM, ...
                        'Color',color,'LineWidth',1.4,'DisplayName',[name ' 推定']);
                end
                if any(isfinite(log.ZReferenceM))
                    if isscalar(logs)
                        referenceName = '目標高度';
                        referenceColor = [0.10 0.10 0.10];
                    else
                        referenceName = [name ' 目標'];
                        referenceColor = color;
                    end
                    plot(app.HistoryHeightAxes,tp,100*plotLog.ZReferenceM, ...
                        '--','Color',referenceColor,'LineWidth',1.0, ...
                        'DisplayName',referenceName);
                end
                if isscalar(logs)
                    if any(isfinite(log.RawVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,tp,plotLog.RawVerticalVelocityMps, ...
                            'Color',[0.00 0.45 0.74],'LineWidth',1.4, ...
                            'DisplayName','機体の速度推定（Kalman）');
                    end
                    if any(isfinite(log.FilteredVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,tp,plotLog.FilteredVerticalVelocityMps, ...
                            'Color',[0.00 0.45 0.74],'LineWidth',1.4, ...
                            'DisplayName','フィルター後');
                    end
                    if any(isfinite(log.VerticalVelocityReferenceMps))
                        plot(app.HistoryVerticalSpeedAxes,tp, ...
                            plotLog.VerticalVelocityReferenceMps,'k--', ...
                            'LineWidth',1.0,'DisplayName','目標速度');
                    end
                    if any(isfinite(log.ToFVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,tp,plotLog.ToFVerticalVelocityMps, ...
                            'o-','Color',[.85 .33 .10],'MarkerSize',3, ...
                            'LineWidth',.8,'DisplayName','ToF高度変化率（直前0.25秒）');
                    end
                else
                    if any(isfinite(log.RawVerticalVelocityMps))
                        plot(app.HistoryVerticalSpeedAxes,tp, ...
                            plotLog.RawVerticalVelocityMps, ...
                            'Color',color,'LineWidth',1.2,'DisplayName',name);
                    end
                end
                if any(isfinite(log.ZErrorM))
                    plot(app.HistoryHeightErrorAxes,tp,100*plotLog.ZErrorM, ...
                        'Color',color,'LineWidth',1.2,'DisplayName',name);
                end
                if any(isfinite(log.VerticalVelocityErrorMps))
                    plot(app.HistoryVelocityErrorAxes,tp, ...
                        plotLog.VerticalVelocityErrorMps, ...
                        'Color',color,'LineWidth',1.2,'DisplayName',name);
                end
                if isscalar(logs)
                    if log.IsOfficialFixedPID
                        controlValues={plotLog.CommonThrustCorrection,plotLog.MotorCommandSpread};
                        controlLabels={'共通推力−基準（平滑化・制限後）','モーター最大−最小（姿勢補正）'};
                    else
                        controlValues = {plotLog.VerticalPTerm,plotLog.VerticalIResidual, ...
                            plotLog.VerticalPIOutput,plotLog.AppliedHeightCorrection};
                        controlLabels = {'速度P','速度I残差','PI出力','適用補正'};
                    end
                    controlColors = [0.00 0.45 0.74; 0.85 0.33 0.10; ...
                        0.47 0.20 0.60; 0.20 0.60 0.30];
                    for j = 1:numel(controlValues)
                        if any(isfinite(controlValues{j}))
                            plot(app.HistoryControlAxes,tp,controlValues{j}, ...
                                'Color',controlColors(j,:), ...
                                'LineWidth',1.2,'DisplayName',controlLabels{j});
                        end
                    end
                    if log.IsOfficialFixedPID
                        throttleValues={plotLog.BaseThrottle,plotLog.CommonThrustDuty, ...
                            plotLog.ThrottleBeforeLimit,plotLog.ThrottleAfterLimit};
                        throttleLabels={'基準','共通推力 / 3.7','モーター平均（制限前）','モーター平均（制限後）'};
                    else
                        throttleValues = {plotLog.BaseThrottle, ...
                            plotLog.ThrottleBeforeLimit,plotLog.ThrottleAfterLimit};
                        throttleLabels = {'基準','制限前','制限後'};
                    end
                    throttleColors = [0.55 0.55 0.55; 0.85 0.33 0.10; ...
                        0.47 0.20 0.60;0.00 0.45 0.74];
                    for j = 1:numel(throttleValues)
                        if any(isfinite(throttleValues{j}))
                            plot(app.HistoryThrottleAxes,tp,throttleValues{j}, ...
                                'Color',throttleColors(j,:), ...
                                'LineWidth',1.2,'DisplayName',throttleLabels{j});
                        end
                    end
                    flags = {plotLog.ToFFresh,plotLog.ToFValid, ...
                        plotLog.HeightValid,plotLog.OrientationValid, ...
                        plotLog.HeightControlEnabled,plotLog.ThrottleSaturated};
                    flagColors = lines(numel(flags));
                    for j = 1:numel(flags)
                        yline(app.HistoryValidityAxes,3*(j-1),':', ...
                            'Color',[.75 .75 .75],'HandleVisibility','off');
                        yline(app.HistoryValidityAxes,3*(j-1)+.7,':', ...
                            'Color',[.75 .75 .75],'HandleVisibility','off');
                        if any(isfinite(flags{j}))
                            flagValue = nan(size(flags{j}));
                            known = ismember(flags{j},[0 1]);
                            flagValue(known) = 3*(j-1) + .7*flags{j}(known);
                            stairs(app.HistoryValidityAxes,tp, ...
                                flagValue, ...
                                'Color',flagColors(j,:), ...
                                'LineWidth',1.5,'HandleVisibility','off', ...
                                'Tag',sprintf('DiagnosticFlag%d',j));
                        end
                    end
                else
                    if log.IsOfficialFixedPID
                        controlValue=plotLog.CommonThrustCorrection;
                    else
                        controlValue=plotLog.AppliedHeightCorrection;
                    end
                    if any(isfinite(controlValue))
                        plot(app.HistoryControlAxes,tp, ...
                            controlValue,'Color',color, ...
                            'LineWidth',1.2,'DisplayName',name);
                    end
                    if any(isfinite(log.ThrottleAfterLimit))
                        plot(app.HistoryThrottleAxes,tp,plotLog.ThrottleAfterLimit, ...
                            'Color',color,'LineWidth',1.2,'DisplayName',name);
                    end
                    if any(isfinite(log.HeightValid))
                        heightValid = nan(size(plotLog.HeightValid));
                        known = ismember(plotLog.HeightValid,[0 1]);
                        heightValid(known) = 3*(k-1)+.7*plotLog.HeightValid(known);
                        stairs(app.HistoryValidityAxes,tp, ...
                            heightValid, ...
                            'Color',color,'LineWidth',1.1,'DisplayName',name);
                    end
                end
                if isscalar(logs)
                    motorNames = {'FR','FL','RR','RL'};
                    motorColors = lines(4);
                    for j = 1:4
                        if any(isfinite(log.Motors(:,j)))
                            plot(app.HistoryMotorAxes,tp,plotLog.Motors(:,j), ...
                                'Color',motorColors(j,:),'LineWidth',1.1, ...
                                'DisplayName',motorNames{j});
                        end
                    end
                else
                    motorMean = mean(plotLog.Motors,2,'omitnan');
                    if any(isfinite(motorMean))
                        plot(app.HistoryMotorAxes,tp,motorMean, ...
                            'Color',color,'LineWidth',1.2,'DisplayName',name);
                    end
                end
                if any(all(isfinite(log.XYM),2))
                    xy = plotLog.XYM;
                    origin = find(all(isfinite(xy),2),1);
                    xy = xy-xy(origin,:);
                    plot(app.HistoryXYAxes,xy(:,1),xy(:,2), ...
                        'Color',color,'DisplayName',name);
                    last=find(all(isfinite(xy),2),1,'last');
                    plot(app.HistoryXYAxes,xy(origin,1),xy(origin,2),'o', ...
                        'Color',color,'MarkerFaceColor',color,'MarkerSize',7, ...
                        'Tag','XYStart','DisplayName',[name ' 開始']);
                    plot(app.HistoryXYAxes,xy(last,1),xy(last,2),'x', ...
                        'Color',color,'MarkerSize',9,'LineWidth',1.8, ...
                        'Tag','XYEnd','DisplayName',[name ' 終了']);
                end
                if any(isfinite(log.FlightState))
                    levels=nan(size(plotLog.FlightState));
                    [matched,index]=ismember(plotLog.FlightState,display.Codes);
                    levels(matched)=display.Levels(index(matched));
                    stairs(app.HistoryStateAxes,tp,levels, ...
                        'Color',color,'LineWidth',1.2,'DisplayName',name);
                end
                summary{k,1} = char(log.Name);
                summary{k,2} = log.TotalFrames;
                summary{k,3} = round(log.DurationSeconds,1);
                summary{k,4} = round(log.FlightMeanHeightCM,1);
                if all(isfinite(log.HeightRangeCM))
                    summary{k,5} = sprintf('%.1f–%.1f',log.HeightRangeCM);
                else
                    summary{k,5} = '—';
                end
                summary{k,6} = log.MissingFrames;
                summary{k,7} = log.CRCRejected;
                summary{k,8} = log.RecordingStopName;
            end
            app.HistorySummaryTable.Data = summary;
            % Align every diagnostic time series at each flight-state change.
            stateEvents(:,1) = round(stateEvents(:,1),2);
            stateEvents = unique(stateEvents,'rows','stable');
            stateEvents = sortrows(stateEvents,1);
            stateNames = display.Names;
            stateCodes = display.Codes;
            stateColors = display.Colors;
            firstTime = min(cellfun(@(item) item.Time(1),logs));
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
                    stateIndex=find(stateCodes==stateId,1);
                    if isempty(stateIndex)
                        continue
                    end
                    alignment = 'right';
                    if eventTime > 0.7*lastTime
                        alignment = 'left';
                    end
                    label = '';
                    showLabel = ax == app.HistoryHeightAxes || ...
                        ax == app.HistoryMotorAxes;
                    if showLabel && (isscalar(logs) || ~labeledStates(stateIndex))
                        label = stateNames{stateIndex};
                        labeledStates(stateIndex) = true;
                    end
                    xline(ax,eventTime,'--',label, ...
                        'Color',stateColors(stateIndex,:), ...
                        'LineWidth',1.2,'FontSize',10, ...
                        'LabelOrientation','horizontal', ...
                        'LabelVerticalAlignment','bottom', ...
                        'LabelHorizontalAlignment',alignment, ...
                        'HandleVisibility','off');
                end
                padding = max(0.2,0.02*(lastTime-firstTime));
                xlim(ax,[firstTime lastTime+padding]);
            end
            xlim(app.HistoryStateAxes,[firstTime lastTime+max(0.2,0.02*(lastTime-firstTime))]);
            for ax = axesList
                hold(ax,'off');
                if any(arrayfun(@(item) isprop(item,'DisplayName') && ...
                        ~isempty(item.DisplayName) && ...
                        strcmp(item.HandleVisibility,'on'),ax.Children))
                    legend(ax,'show','Location','best');
                end
            end
            if isempty(findall(app.HistoryControlAxes,'Type','line'))
                text(app.HistoryControlAxes,.5,.5,'制御補足データ（SFIX）が未記録です', ...
                    'Units','normalized','HorizontalAlignment','center', ...
                    'Interpreter','none','Tag','ControlDataMissing');
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
            if isscalar(logs)
                message=sprintf('%s / 保存終了: %s',message,logs{1}.RecordingStopName);
                if strcmp(logs{1}.RecordingStopReason,'firmware_restart')
                    message=sprintf('%s / 起動理由: %s',message,logs{1}.RestartReasonName);
                end
                if ~logs{1}.Complete,message=[message ' / 保存未完了'];end
            end
            if any(cellfun(@(item)strcmp(item.TimeZeroSource,'recording_start'),logs))
                for ax=[timeAxes app.HistoryStateAxes],xlabel(ax,'記録開始からの時間 (s)');end
            end
            app.HistoryStatusLabel.Text = message;
            note=['0秒は飛行制御開始です。浮上・ホバリング達成とは異なります。' ...
                '機体の速度推定は直接測定値ではありません。ToF変化率は直前0.25秒の比較値です。' ...
                '共通推力差はSFIXのThrustCommand/3.7−BaseDuty、平滑化・制限後の値です。' ...
                'モーター幅は最大−最小で、姿勢・角速度補正の大きさを示します。' ...
                '診断は各帯の下がOFF、上がON。空白は未記録です。ToF新規は通常点滅します。' ...
                '高度制御ONは正常、スロットル飽和ONは制限への到達です。'];
            app.HistoryStatusLabel.Tooltip = char(strjoin([string(note);errors],newline));
        end
    end
    methods (Static,Access=private)
        function output=breakLines(log)
            % すべての時系列に共通の欠測区間を挿入し、再起動前後を接続しません。
            output=log;breaks=find(log.PlotBreakBefore);
            if isempty(breaks),return;end
            n=numel(log.Time);positions=(1:n)'+cumsum(log.PlotBreakBefore);
            names=fieldnames(log);
            for k=1:numel(names)
                values=log.(names{k});
                if ~isnumeric(values) || size(values,1)~=n,continue;end
                expanded=nan(n+numel(breaks),size(values,2));
                expanded(positions,:)=values;output.(names{k})=expanded;
            end
            output.Time(positions(breaks)-1)=log.Time(breaks);
        end
    end
end
