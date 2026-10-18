classdef ControlSettings
    %CONTROLSETTINGS 概要：現行モデルのPID・水平P/PI設定を読み書きします。
    % 係数だけを変更し、配線・実行条件・機体通信は扱いません。
    % 反映後のモデルは未保存です。機体へ反映するには保存と再ビルド・書き込みが必要です。
    methods (Static)
        function settings=read(model)
            % 1. 現行モデルを読み、制御対象名からPIDを特定します。
            if nargin<1,model='Stampfly_Tx';end
            if ~bdIsLoaded(model)
                load_system(fullfile(stampfly_project_root(),[char(model) '.slx']));
            end
            assert(strcmp(get_param(model,'SimulationStatus'),'stopped'), ...
                'imu:ModelRunning','モデルを停止してから設定を読み込んでください。');
            settings=struct('Model',char(model),'ModelFile',get_param(model,'FileName'), ...
                'PIDNames',{{'AltitudePID','VerticalSpeedPID','RollAnglePID','PitchAnglePID', ...
                'RollRatePID','PitchRatePID','YawRatePID'}}, ...
                'PIDLabels',{{'高度','鉛直速度','Roll 姿勢','Pitch 姿勢', ...
                'Roll 角速度','Pitch 角速度','Yaw 角速度'}}, ...
                'PIDPaths',{cell(7,1)},'PIDExpressions',{cell(7,4)},'PIDValues',zeros(7,4), ...
                'HorizontalPaths',{cell(8,1)},'HorizontalExpressions',{cell(8,1)}, ...
                'HorizontalValues',zeros(8,1));
            settings.PIDParameters={'P','I','D','N'};
            blocks=find_system(model,'LookUnderMasks','all','FollowLinks','on', ...
                'MatchFilter',@Simulink.match.allVariants,'Name','DedicatedPID');
            assert(numel(blocks)==7,'imu:PIDTopology','現行モデルの7個のDedicatedPIDを確認できません。');
            for row=1:7
                selected=blocks(cellfun(@(p)strcmp(get_param(get_param(p,'Parent'),'Name'),settings.PIDNames{row}),blocks));
                assert(isscalar(selected),'imu:PIDTopology','%sを一意に確認できません。',settings.PIDNames{row});
                path=selected{1};settings.PIDPaths{row}=path;
                assert(strcmp(get_param(path,'Form'),'Ideal') && ...
                    strcmp(get_param(path,'ControllerParametersSource'),'internal'), ...
                    'imu:PIDForm','%sは対応するIdeal形式のPIDではありません。',path);
                for column=1:4
                    expression=get_param(path,settings.PIDParameters{column});
                    settings.PIDExpressions{row,column}=expression;
                    settings.PIDValues(row,column)=imu.ControlSettings.resolve(expression,path);
                end
            end
            % 2. 水平位置Pと速度PI、その制限値を実ブロックから読みます。
            settings.HorizontalParameters={'PositionGainPerS','ProportionalGainPerS', ...
                'IntegralGainPerS2','MaxSpeedMps','CommandAccelerationMps2', ...
                'MaxAccelerationMps2','IntegralLimitMps2','AccelerationSlewMps3'};
            settings.HorizontalLabels={'位置 P [1/s]','速度 P [1/s]','速度 I [1/s²]', ...
                '移動速度上限 [m/s]','速度目標の加速度 [m/s²]', ...
                '補正加速度上限 [m/s²]','積分上限 [m/s²]','加速度変化率 [m/s³]'};
            command=imu.ControlSettings.systemBlock(model,'horizontal.Command');
            velocity=imu.ControlSettings.systemBlock(model,'horizontal.VelocityPI');
            usesCommand=[true false false true true false false false];
            for row=1:8
                if usesCommand(row),path=command;else,path=velocity;end
                settings.HorizontalPaths{row}=path;
                expression=get_param(path,settings.HorizontalParameters{row});
                settings.HorizontalExpressions{row}=expression;
                settings.HorizontalValues(row)=imu.ControlSettings.resolve(expression,path);
            end
        end

        function updated=apply(settings,pidValues,horizontalValues)
            % 3. 全入力と読み出し後のモデル変更を確認してから、変更値だけを反映します。
            imu.ControlSettings.validate(pidValues,horizontalValues);
            model=settings.Model;
            assert(bdIsLoaded(model) && strcmp(get_param(model,'FileName'),settings.ModelFile), ...
                'imu:ModelChanged','設定を読んだモデルを開き、再読込してください。');
            assert(strcmp(get_param(model,'SimulationStatus'),'stopped'), ...
                'imu:ModelRunning','モデルを停止してから設定を反映してください。');
            current=imu.ControlSettings.read(model);
            assert(isequal(current.PIDExpressions,settings.PIDExpressions) && ...
                isequal(current.HorizontalExpressions,settings.HorizontalExpressions), ...
                'imu:SettingsChanged','モデル側の設定が変わっています。再読込してから編集してください。');
            paths={};parameters={};old={};values={};
            for row=1:7
                for column=1:4
                    if pidValues(row,column)==settings.PIDValues(row,column),continue;end
                    paths{end+1}=settings.PIDPaths{row}; %#ok<AGROW>
                    parameters{end+1}=settings.PIDParameters{column}; %#ok<AGROW>
                    old{end+1}=settings.PIDExpressions{row,column}; %#ok<AGROW>
                    values{end+1}=sprintf('single(%.17g)',pidValues(row,column)); %#ok<AGROW>
                end
            end
            for row=1:8
                if horizontalValues(row)==settings.HorizontalValues(row),continue;end
                paths{end+1}=settings.HorizontalPaths{row}; %#ok<AGROW>
                parameters{end+1}=settings.HorizontalParameters{row}; %#ok<AGROW>
                old{end+1}=settings.HorizontalExpressions{row}; %#ok<AGROW>
                values{end+1}=sprintf('%.17g',horizontalValues(row)); %#ok<AGROW>
            end
            % 4. エラー時は係数を戻します。保存や機体への送信はここでは行いません。
            originalDirty=get_param(model,'Dirty');changed=0;
            try
                for k=1:numel(paths)
                    imu.ControlSettings.configure(model,paths{k},parameters{k},values{k});changed=k;
                end
                if changed>0,set_param(model,'SimulationCommand','update');end
                updated=imu.ControlSettings.read(model);
                updated.ChangedParameterCount=changed;
            catch err
                for k=changed:-1:1
                    imu.ControlSettings.configure(model,paths{k},parameters{k},old{k});
                end
                set_param(model,'Dirty',originalDirty);
                rethrow(err);
            end
        end

        function validate(pidValues,horizontalValues)
            % Ideal形式ではI=1/Ti、D=Tdです。Parallel形式のKi/Kdとは異なります。
            validateattributes(pidValues,{'double','single'},{'real','finite','size',[7 4],'nonnegative'});
            validateattributes(horizontalValues,{'double','single'},{'real','finite','size',[8 1],'nonnegative'});
            assert(all(pidValues(:,4)>0) && all(isfinite(single(pidValues)),'all'), ...
                'imu:PIDRange','Nは正、PID係数は単精度で有限な値にしてください。');
            assert(all(horizontalValues([1 2 4 5 6 8])>0) && ...
                all(isfinite(single(horizontalValues))), ...
                'imu:HorizontalRange','位置P・速度P・速度／加速度上限・変化率は正にしてください。');
        end
    end
    methods (Static,Access=private)
        function configure(model,path,parameter,value)
            % 利用者の明示操作による係数変更だけを対象にします。
            % Toolkitがある環境は共通編集APIを使い、配布先では標準Simulink APIで設定します。
            % reorg.editは同梱ラッパーなので、Toolkit本体の公開APIも確認します。
            if ~isempty(which('reorg.edit')) && ~isempty(which('model_edit')) && ...
                    ~isempty(which('model_read')) && ~isempty(which('library.settingsLookup'))
                id=['blk_' extractAfter(Simulink.ID.getSID(path),':')];
                parent=Simulink.ID.getSID(get_param(path,'Parent'));
                if strcmp(parent,model),scope='root';else,scope=['blk_' extractAfter(parent,':')];end
                reorg.edit(model,scope,{reorg.configure(id,struct(parameter,value))});
            else
                set_param(path,parameter,value);
            end
        end
        function path=systemBlock(model,className)
            blocks=find_system(model,'LookUnderMasks','all','FollowLinks','on', ...
                'MatchFilter',@Simulink.match.allVariants, ...
                'BlockType','MATLABSystem','System',className);
            assert(isscalar(blocks),'imu:HorizontalTopology','%sを一意に確認できません。',className);
            path=blocks{1};
        end
        function value=resolve(expression,path)
            value=slResolve(expression,path);
            if isa(value,'Simulink.Parameter'),value=value.Value;end
            validateattributes(value,{'numeric'},{'real','finite','scalar'});
            value=double(value);
        end
    end
end
