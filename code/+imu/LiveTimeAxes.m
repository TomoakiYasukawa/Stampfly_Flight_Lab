classdef LiveTimeAxes < handle
    %LIVETIMEAXES Scroll a fixed ten-second viewport without axes relayout.
    % Line XData remains the connection-relative timestamp. Only its graphics
    % transform changes. Lightweight text preserves absolute time labels.
    properties (SetAccess = private)
        Axes
        Transforms
        TickLabels
        RelativeMode (1,1) logical = false
    end
    properties (Access = private)
        WindowSeconds (1,1) double = 10
        TickOffsets double
        LastOrigin (1,1) double = NaN
        LastLabels double = []
    end
    methods
        function obj=LiveTimeAxes(axesList,lineGroups,windowSeconds)
            obj.Axes=axesList;obj.WindowSeconds=windowSeconds;
            obj.TickOffsets=linspace(0,windowSeconds,6);
            obj.Transforms=gobjects(1,numel(axesList));
            obj.TickLabels=gobjects(numel(axesList),6);
            for i=1:numel(axesList)
                ax=axesList(i);obj.Transforms(i)=hgtransform('Parent',ax);
                for line=lineGroups{i},line.Parent=obj.Transforms(i);end
                for k=1:6
                    alignment='center';
                    if k==1,alignment='left';elseif k==6,alignment='right';end
                    obj.TickLabels(i,k)=text(ax,(k-1)/5,-.025,'', ...
                        'Units','normalized','HorizontalAlignment',alignment, ...
                        'VerticalAlignment','top','FontName',ax.FontName, ...
                        'FontSize',ax.FontSize,'Color',ax.XColor, ...
                        'Interpreter','none','Clipping','off','Visible','off', ...
                        'HitTest','off','PickableParts','none','HandleVisibility','off', ...
                        'Tag',sprintf('LiveTimeTick%d',k));
                end
            end
        end

        function update(obj,right,exactLimits)
            right=max(obj.WindowSeconds,right);
            if exactLimits
                % Explicit programmatic refresh retains ordinary axes and
                % exact absolute limits for inspection/export.
                if obj.RelativeMode
                    for i=1:numel(obj.Axes)
                        obj.Transforms(i).Matrix=eye(4);
                        set(obj.TickLabels(i,:),'Visible','off');
                        obj.Axes(i).XTickMode='auto';obj.Axes(i).XTickLabelMode='auto';
                    end
                    obj.RelativeMode=false;obj.LastOrigin=NaN;obj.LastLabels=[];
                end
                bounds=[right-obj.WindowSeconds right];
                for ax=obj.Axes,if ~isequal(ax.XLim,bounds),ax.XLim=bounds;end;end
                return
            end
            if ~obj.RelativeMode
                for i=1:numel(obj.Axes)
                    ax=obj.Axes(i);ax.XLim=[0 obj.WindowSeconds];
                    ax.XTick=obj.TickOffsets;ax.XTickLabel=repmat({' '},1,6);
                    set(obj.TickLabels(i,:),'Visible','on');
                end
                obj.RelativeMode=true;obj.LastOrigin=NaN;obj.LastLabels=[];
            end
            origin=right-obj.WindowSeconds;
            if origin~=obj.LastOrigin
                transform=eye(4);transform(1,4)=-origin;
                for transformHandle=obj.Transforms,transformHandle.Matrix=transform;end
                obj.LastOrigin=origin;
            end
            labelTimes=round((origin+obj.TickOffsets)*10)/10;
            if ~isequal(labelTimes,obj.LastLabels)
                labels=compose('%.1f',labelTimes);
                for i=1:numel(obj.Axes)
                    for k=1:6,obj.TickLabels(i,k).String=labels{k};end
                end
                obj.LastLabels=labelTimes;
            end
        end

        function reset(obj)
            obj.update(obj.WindowSeconds,true);
        end
    end
end
