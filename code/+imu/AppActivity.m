classdef AppActivity < handle
    %APPACTIVITY Show ongoing work without blocking the logger's controls.
    properties
        Enabled (1,1) logical = true
    end
    properties (Access = private)
        Parent
        Window = []
        Label = []
        Activities (1,1) struct = struct()
        HiddenByUser (1,1) logical = false
        Refreshing (1,1) logical = false
    end
    methods
        function obj = AppActivity(parent)
            obj.Parent = parent;
        end
        function start(obj,name,message,showNow)
            if nargin<4,showNow=true;end
            activities=obj.Activities;
            if ~isfield(activities,name)
                if isempty(fieldnames(activities)),obj.HiddenByUser=false;end
                activity=struct('Message',char(message),'Started',tic,'Immediate',logical(showNow));
            else
                activity=activities.(name);
                activity.Message=char(message);
                activity.Immediate=activity.Immediate || logical(showNow);
            end
            % Keep all state for one operation in one atomic struct update.
            % UIFigure creation can run queued completion callbacks.
            activities.(name)=activity;obj.Activities=activities;
            obj.refresh();
        end
        function finish(obj,name)
            if isfield(obj.Activities,name)
                obj.Activities = rmfield(obj.Activities,name);
            end
            obj.refresh();
        end
        function delete(obj)
            if isgraphics(obj.Window), delete(obj.Window); end
        end
        function update(obj)
            obj.refresh();
        end
        function active=isActive(obj,name)
            active=isfield(obj.Activities,name);
        end
    end
    methods (Access = private)
        function refresh(obj)
            if obj.Refreshing,return;end
            obj.Refreshing=true;
            cleanup=onCleanup(@()obj.endRefresh()); %#ok<NASGU>
            try
                obj.refreshWindow();
            catch
                % A UIFigure can be closed while its web view is updating.
                % Work and app shutdown must not depend on this notification.
                if ~isvalid(obj),return;end
                if isgraphics(obj.Window)
                    try,delete(obj.Window);catch,end
                end
                obj.Window=[];obj.Label=[];
            end
        end
        function endRefresh(obj)
            if isvalid(obj),obj.Refreshing=false;end
        end
        function refreshWindow(obj)
            activities=obj.Activities;names=fieldnames(activities);
            if isempty(names) || ~obj.Enabled || ~isgraphics(obj.Parent) ...
                    || strcmp(obj.Parent.Visible,'off')
                if isgraphics(obj.Window) && strcmp(obj.Window.Visible,'on')
                    obj.Window.Visible='off';
                end
                return
            end
            ready=false;
            for k=1:numel(names)
                activity=activities.(names{k});
                ready=ready || activity.Immediate || toc(activity.Started)>=.35;
            end
            if ~ready || obj.HiddenByUser,return;end
            if isempty(obj.Window) || ~isgraphics(obj.Window)
                position = obj.Parent.Position;
                obj.Window = uifigure('Name','StampFly 作業中', ...
                    'Position',[position(1)+max(0,(position(3)-340)/2), ...
                    position(2)+max(0,(position(4)-110)/2),340,110], ...
                    'Resize','off','WindowStyle','normal','Tag','StampFlyActivity', ...
                    'CloseRequestFcn',@(~,~)obj.hide());
                grid = uigridlayout(obj.Window,[2 1], ...
                    'RowHeight',{'1x',20},'Padding',[10 8 10 8],'RowSpacing',2);
                obj.Label = uilabel(grid,'WordWrap','on','FontSize',12);
                uilabel(grid,'Text','完了すると自動で閉じます。','FontSize',10);
            end
            % Construction may have dispatched a completion. Read current
            % state again before presenting the notification.
            if ~isvalid(obj) || ~isgraphics(obj.Parent),return;end
            activities=obj.Activities;names=fieldnames(activities);
            if isempty(names)
                if strcmp(obj.Window.Visible,'on'),obj.Window.Visible='off';end
                return
            end
            messages=cell(numel(names),1);
            for k=1:numel(names),messages{k}=activities.(names{k}).Message;end
            message=strjoin(messages,newline);
            if ~strcmp(obj.Label.Text,message),obj.Label.Text=message;end
            if strcmp(obj.Window.Visible,'off'),obj.Window.Visible='on';end
        end
        function hide(obj)
            obj.HiddenByUser=true;
            if isgraphics(obj.Window),obj.Window.Visible='off';end
        end
    end
end
