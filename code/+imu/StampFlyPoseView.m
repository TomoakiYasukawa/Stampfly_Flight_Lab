classdef StampFlyPoseView < handle
    %STAMPFLYPOSEVIEW Draw the RoadRunner StampFly mesh on an app UIAxes.
    % Source STL: Z forward, X left, Y up (millimetres).
    % Filter quaternion describes the NED frame relative to the FRD body.
    % rotmat(q,'point') maps body vectors into NED for display.

    properties (SetAccess = private)
        Axes
        BodyPatch
        BodyAxes
        GroundPatch
        GroundPath
        PathStart
        PathEnd
        VerticalPath
    end

    properties
        VerticalProjectionsEnabled (1,1) logical = true
    end

    properties (Access = private)
        MeshVertices double
        BodyTransform
        PoseTitle
        PoseTitleText = ''
        LastOrientation (1,4) double = [NaN NaN NaN NaN]
        LastHorizontalSign (1,1) double = NaN
        MeshRotation double = eye(3)
        LastPositionENU (1,3) double = [0 0 0]
        ViewCenterEN (1,2) double = [0 0]
        ViewBaseHeightM (1,1) double = 0
    end

    methods
        function obj = StampFlyPoseView(axesHandle,meshFile)
            if nargin < 2
                root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
                meshFile = fullfile(root,'resources','stampfly_mesh', ...
                    'stampfly_v1.stl');
            end
            assert(isfile(meshFile),'imu:MeshMissing', ...
                'StampFly mesh not found: %s',meshFile);
            obj.Axes = axesHandle;
            mesh = stlread(meshFile);
            % The STL coordinates are millimetres; the UI uses metres.
            obj.MeshVertices = double(mesh.Points)*1e-3;
            boundsCenter = (min(obj.MeshVertices,[],1) + ...
                max(obj.MeshVertices,[],1))/2;
            obj.MeshVertices = obj.MeshVertices - boundsCenter;
            hold(axesHandle,'on');
            obj.BodyTransform = hgtransform('Parent',axesHandle);
            obj.BodyPatch = patch(axesHandle, ...
                'Parent',obj.BodyTransform, ...
                'Faces',mesh.ConnectivityList, ...
                'Vertices',obj.MeshVertices, ...
                'FaceColor',[0.72 0.76 0.80], ...
                'EdgeColor','none', ...
                'FaceLighting','gouraud');
            obj.BodyAxes = gobjects(1,3);
            axisColors = [0.85 0.18 0.18;0.18 0.60 0.25;0.15 0.35 0.85];
            % The body directions share the mesh transform. In source STL
            % coordinates: Z forward, X left, Y up. Their local data is fixed.
            axisEnds = .06*[0 1 0;0 0 1;1 0 0];
            for k = 1:3
                obj.BodyAxes(k) = line('Parent',obj.BodyTransform, ...
                    'XData',[0 axisEnds(1,k)],'YData',[0 axisEnds(2,k)], ...
                    'ZData',[0 axisEnds(3,k)],'Color',axisColors(k,:), ...
                    'LineWidth',2,'HitTest','off','PickableParts','none');
            end
            obj.GroundPatch = patch(axesHandle, ...
                'XData',[-0.25 0.25 0.25 -0.25], ...
                'YData',[-0.25 -0.25 0.25 0.25], ...
                'ZData',[0 0 0 0], ...
                'FaceColor',[0.58 0.70 0.60], ...
                'FaceAlpha',0.10,'EdgeColor','none');
            obj.GroundPath = plot3(axesHandle,nan,nan,nan, ...
                'Color',[0 .45 .74],'LineWidth',1.3,'Tag','GroundXYPath', ...
                'DisplayName','Optical Flow XY（床面）');
            obj.PathStart = plot3(axesHandle,nan,nan,nan,'o', ...
                'Color',[0 .45 .74],'MarkerFaceColor',[0 .45 .74], ...
                'MarkerSize',7,'Tag','XYStart','DisplayName','開始');
            obj.PathEnd = plot3(axesHandle,nan,nan,nan,'x', ...
                'Color',[.85 .33 .1],'MarkerSize',9,'LineWidth',1.8, ...
                'Tag','XYEnd','DisplayName','最新');
            obj.VerticalPath=plot3(axesHandle,nan,nan,nan, ...
                'Color',[.47 .67 .19],'LineWidth',1.1,'Tag','VerticalPlanePaths', ...
                'DisplayName','YZ / ZX: 北N・東Eと高さU');
            grid(axesHandle,'on');
            axis(axesHandle,'equal');
            xlabel(axesHandle,'東 E [m]');
            ylabel(axesHandle,'北 N [m]');
            zlabel(axesHandle,'上 U [m]');
            obj.PoseTitle = title(axesHandle,'姿勢: データ待機中');
            obj.PoseTitleText = '姿勢: データ待機中';
            view(axesHandle,35,25);
            camlight(axesHandle,'headlight');
            obj.update(single([1 0 0 0]),true);
            obj.setTitle('姿勢: データ待機中');
            axis(axesHandle,[-0.25 0.25 -0.25 0.25 0 0.5]);
        end

        function update(obj,orientation,isValid,positionENU,horizontalSign)
            if ~isValid
                obj.setTitle('姿勢: データ待機中');
                return
            end
            if nargin >= 4
                p = double(positionENU(:).');
                if numel(p) == 3 && all(isfinite(p))
                    obj.LastPositionENU = p;
                end
            end
            p = obj.LastPositionENU;
            q = double(orientation(:).');
            qNorm = norm(q);
            if numel(q) ~= 4 || ~all(isfinite(q)) || qNorm < 1e-8
                obj.setTitle('姿勢: 無効');
                return
            end
            q = q/qNorm;
            if nargin < 5,horizontalSign=1;end
            if ~isequal(q,obj.LastOrientation) || horizontalSign~=obj.LastHorizontalSign
                bodyToNED = rotmat(quaternion(q),'point');
                % Apply the same horizontal frame change as the position/path.
                bodyToNED(1:2,:) = horizontalSign*bodyToNED(1:2,:);
                meshToBody = [0 0 1;-1 0 0;0 -1 0];
                nedToENU = [0 1 0;1 0 0;0 0 -1];
                obj.MeshRotation = nedToENU * bodyToNED * meshToBody;
                obj.LastOrientation=q;obj.LastHorizontalSign=horizontalSign;
            end
            transform=[obj.MeshRotation p';0 0 0 1];
            if ~isequal(obj.BodyTransform.Matrix,transform),obj.BodyTransform.Matrix=transform;end
            % Exact position/height already appears in the monitor readout.
            % A stable title prevents relayout on every centimetre of motion.
            obj.setTitle('機体3D / XY・YZ・ZX軌跡');
            obj.followPosition(p);
        end

        function updatePath(obj,xy,height)
            % Reuse the same bounded history on all three projections.
            % NaNs preserve gaps; invalid ToF never becomes a height sample.
            if nargin<3,height=nan(size(xy,1),1);end
            floorZ=obj.ViewBaseHeightM+.001;
            valid=all(isfinite(xy),2);
            set(obj.GroundPath,'XData',xy(:,1),'YData',xy(:,2), ...
                'ZData',floorZ*ones(size(xy,1),1));
            if obj.VerticalProjectionsEnabled && numel(height)==size(xy,1)
                height=height(:);
                height(~valid)=NaN;
                wallE=obj.Axes.XLim(1)+.001;
                wallN=obj.Axes.YLim(2)-.001;
                fixedE=wallE*ones(size(height));fixedN=wallN*ones(size(height));
                set(obj.VerticalPath,'XData',[fixedE;NaN;xy(:,1)], ...
                    'YData',[xy(:,2);NaN;fixedN],'ZData',[height;NaN;height]);
            else
                set(obj.VerticalPath, ...
                    'XData',nan,'YData',nan,'ZData',nan);
            end
            if ~any(valid)
                set([obj.PathStart obj.PathEnd],'XData',nan,'YData',nan,'ZData',nan);
                return
            end
            first=find(valid,1);last=find(valid,1,'last');
            set(obj.PathStart,'XData',xy(first,1),'YData',xy(first,2),'ZData',floorZ);
            set(obj.PathEnd,'XData',xy(last,1),'YData',xy(last,2),'ZData',floorZ);
        end

        function reset(obj)
            obj.LastPositionENU = [0 0 0];
            obj.ViewCenterEN = [0 0];
            obj.ViewBaseHeightM = 0;
            obj.setViewBounds();
            obj.update([1 0 0 0],true,[0 0 0]);
            obj.updatePath(zeros(0,2));
            obj.setTitle('姿勢・位置: データ待機中');
        end
    end

    methods (Access = private)
        function setTitle(obj,text)
            % Reuse the Text handle; title() also validates and lays out axes.
            if ~strcmp(obj.PoseTitleText,text)
                obj.PoseTitle.String=text;obj.PoseTitleText=text;
            end
        end

        function followPosition(obj,p)
            % Follow in steps to keep the 0.5 m cube stable while moving.
            center = obj.ViewCenterEN;
            horizontalPosition = p(1:2);
            shift = abs(horizontalPosition-center) > 0.18;
            center(shift) = horizontalPosition(shift);
            base = obj.ViewBaseHeightM;
            if p(3) > base+0.46 || (base > 0 && p(3) < base+0.04)
                base = max(0,p(3)-0.25);
            end
            if any(center ~= obj.ViewCenterEN) || base ~= obj.ViewBaseHeightM
                obj.ViewCenterEN = center;
                obj.ViewBaseHeightM = base;
                obj.setViewBounds();
            end
        end

        function setViewBounds(obj)
            east = obj.ViewCenterEN(1)+[-0.25 0.25];
            north = obj.ViewCenterEN(2)+[-0.25 0.25];
            xlim(obj.Axes,east);
            ylim(obj.Axes,north);
            zlim(obj.Axes,obj.ViewBaseHeightM+[0 0.5]);
            obj.GroundPatch.XData = east([1 2 2 1]);
            obj.GroundPatch.YData = north([1 1 2 2]);
            obj.GroundPatch.ZData = repmat(obj.ViewBaseHeightM,1,4);
        end
    end
end
