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
    end

    properties (Access = private)
        MeshVertices double
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
            obj.BodyPatch = patch(axesHandle, ...
                'Faces',mesh.ConnectivityList, ...
                'Vertices',obj.MeshVertices, ...
                'FaceColor',[0.72 0.76 0.80], ...
                'EdgeColor','none', ...
                'FaceLighting','gouraud');
            obj.BodyAxes = gobjects(1,3);
            axisColors = [0.85 0.18 0.18;0.18 0.60 0.25;0.15 0.35 0.85];
            for k = 1:3
                obj.BodyAxes(k) = plot3(axesHandle,[0 0],[0 0],[0 0], ...
                    'Color',axisColors(k,:), 'LineWidth',2);
            end
            obj.GroundPatch = patch(axesHandle, ...
                'XData',[-0.25 0.25 0.25 -0.25], ...
                'YData',[-0.25 -0.25 0.25 0.25], ...
                'ZData',[0 0 0 0], ...
                'FaceColor',[0.58 0.70 0.60], ...
                'FaceAlpha',0.10,'EdgeColor','none');
            grid(axesHandle,'on');
            axis(axesHandle,'equal');
            xlabel(axesHandle,'東 E [m]');
            ylabel(axesHandle,'北 N [m]');
            zlabel(axesHandle,'上 U [m]');
            title(axesHandle,'姿勢: データ待機中');
            view(axesHandle,35,25);
            camlight(axesHandle,'headlight');
            obj.update(single([1 0 0 0]),true);
            title(axesHandle,'姿勢: データ待機中');
            axis(axesHandle,[-0.25 0.25 -0.25 0.25 0 0.5]);
        end

        function update(obj,orientation,isValid,positionENU)
            if ~isValid
                title(obj.Axes,'姿勢: データ待機中');
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
                title(obj.Axes,'姿勢: 無効');
                return
            end
            q = q/qNorm;
            bodyToNED = rotmat(quaternion(q),'point');
            % The source STL has Y up. Match the conversion used by the
            % RoadRunner project before applying the filter orientation.
            meshToBody = [0 0 1;-1 0 0;0 -1 0];
            nedToENU = [0 1 0;1 0 0;0 0 -1];
            meshToENU = nedToENU * bodyToNED * meshToBody;
            obj.BodyPatch.Vertices = (meshToENU*obj.MeshVertices.').'+p;
            % Draw the labeled FRD body directions, not the STL axes.
            % Red: forward (+X), green: left (-Y), blue: up (-Z).
            bodyToENU = nedToENU * bodyToNED;
            axisEnds = 0.06*bodyToENU*diag([1 -1 -1]);
            for k = 1:3
                obj.BodyAxes(k).XData = [p(1) p(1)+axisEnds(1,k)];
                obj.BodyAxes(k).YData = [p(2) p(2)+axisEnds(2,k)];
                obj.BodyAxes(k).ZData = [p(3) p(3)+axisEnds(3,k)];
            end
            title(obj.Axes,sprintf( ...
                '姿勢・位置  E %.2f  N %.2f  高さ %.2f m',p));
            obj.followPosition(p);
        end

        function reset(obj)
            obj.LastPositionENU = [0 0 0];
            obj.ViewCenterEN = [0 0];
            obj.ViewBaseHeightM = 0;
            obj.setViewBounds();
            obj.update([1 0 0 0],true,[0 0 0]);
            title(obj.Axes,'姿勢・位置: データ待機中');
        end
    end

    methods (Access = private)
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
        end
    end
end
