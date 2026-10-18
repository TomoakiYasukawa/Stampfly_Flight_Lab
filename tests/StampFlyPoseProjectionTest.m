classdef StampFlyPoseProjectionTest < matlab.unittest.TestCase
    properties
        Figure
        View
    end
    methods (TestMethodSetup)
        function createView(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
            testCase.Figure=uifigure('Visible','off');
            testCase.addTeardown(@()delete(testCase.Figure));
            testCase.View=imu.StampFlyPoseView(uiaxes(testCase.Figure));
        end
    end
    methods (Test)
        function projectsSameSamplesOntoEveryPlaneWithoutJoiningGaps(testCase)
            p=[.01 .02 .10;.03 .04 .12;NaN NaN NaN;.05 .06 .15;.07 .08 NaN];
            view=testCase.View;
            view.update([1 0 0 0],true,p(4,:));
            view.updatePath(p(:,1:2),p(:,3));
            testCase.verifyEqual(view.GroundPath.XData,p(:,1)');
            testCase.verifyEqual(view.GroundPath.YData,p(:,2)');
            testCase.verifyEqual(view.GroundPath.ZData,.001*ones(1,5),'AbsTol',1e-12);
            testCase.verifyEqual(view.VerticalPath.XData, ...
                [(view.Axes.XLim(1)+.001)*ones(1,5) NaN p(:,1)'],'AbsTol',1e-12);
            testCase.verifyEqual(view.VerticalPath.YData, ...
                [p(:,2)' NaN (view.Axes.YLim(2)-.001)*ones(1,5)],'AbsTol',1e-12);
            testCase.verifyEqual(view.VerticalPath.ZData,[p(:,3)' NaN p(:,3)']);
        end
        function projectionsFollowBoundsAndReset(testCase)
            view=testCase.View;
            view.update([1 0 0 0],true,[1 2 1.2]);
            view.updatePath([.9 1.9;1 2],[1.1;1.2]);
            testCase.verifyEqual(view.VerticalPath.XData(1:2),repmat(view.Axes.XLim(1)+.001,1,2),'AbsTol',1e-12);
            testCase.verifyEqual(view.VerticalPath.YData(end-1:end),repmat(view.Axes.YLim(2)-.001,1,2),'AbsTol',1e-12);
            testCase.verifyEqual(view.GroundPath.ZData,repmat(.951,1,2),'AbsTol',1e-12);
            view.reset();
            testCase.verifyEmpty(view.GroundPath.XData);
            testCase.verifyTrue(all(isnan(view.VerticalPath.ZData)));
        end

        function bodyDirectionsUseMeshTransformThroughRotationAndFrameChange(testCase)
            view=testCase.View;
            q=[.6 .2 -.3 .7];q=q/norm(q);position=[.1 -.15 .35];
            for horizontalSign=[1 -1]
                view.update(q,true,position,horizontalSign);
                transform=view.BodyPatch.Parent.Matrix;
                bodyToNED=rotmat(quaternion(q),'point');
                bodyToNED(1:2,:)=horizontalSign*bodyToNED(1:2,:);
                directions=.06*[0 1 0;1 0 0;0 0 -1]*bodyToNED*diag([1 -1 -1]);
                for k=1:3
                    axis=view.BodyAxes(k);
                    world=transform*[axis.XData;axis.YData;axis.ZData;1 1];
                    testCase.verifyEqual(world(1:3,:),[position' position'+directions(:,k)],'AbsTol',1e-12);
                    testCase.verifyEqual(axis.Parent,view.BodyPatch.Parent);
                end
            end
        end

        function cachedPoseUpdatesRecoverFromInvalidOrientationAndReset(testCase)
            view=testCase.View;view.update([1 0 0 0],true,[.03 .04 .2],-1);
            first=view.BodyPatch.Parent.Matrix;title=view.Axes.Title;
            view.update([1 0 0 0],true,[.03 .04 .2],-1);
            testCase.verifyEqual(view.BodyPatch.Parent.Matrix,first);
            testCase.verifyEqual(view.Axes.Title,title);
            view.update([NaN 0 0 0],true);
            testCase.verifyEqual(view.Axes.Title.String,'姿勢: 無効');
            view.update([1 0 0 0],true,[.01 .02 .3],1);
            testCase.verifyEqual(view.BodyPatch.Parent.Matrix(1:3,4),[.01;.02;.3]);
            view.reset();testCase.verifyEqual(view.BodyPatch.Parent.Matrix(1:3,4),zeros(3,1));
            testCase.verifyTrue(contains(view.Axes.Title.String,'待機中'));
        end
    end
end
