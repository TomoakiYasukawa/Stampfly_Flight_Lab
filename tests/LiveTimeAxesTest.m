classdef LiveTimeAxesTest < matlab.unittest.TestCase
    properties
        Figure
        Axes
        Line
        View
    end
    methods (TestMethodSetup)
        function createView(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
            testCase.Figure=uifigure('Visible','off');
            testCase.addTeardown(@()delete(testCase.Figure));
            testCase.Axes=uiaxes(testCase.Figure);
            testCase.Line=plot(testCase.Axes,[10 11 12],[1 2 3]);
            testCase.View=imu.LiveTimeAxes(testCase.Axes,{testCase.Line},10);
        end
    end
    methods (Test)
        function scrollingPreservesTimestampsAndCorrectScreenPositions(testCase)
            testCase.View.update(12.4,false);
            testCase.verifyEqual(testCase.Axes.XLim,[0 10]);
            testCase.verifyEqual(testCase.Line.XData,[10 11 12]);
            world=testCase.Line.Parent.Matrix*[testCase.Line.XData;testCase.Line.YData;zeros(1,3);ones(1,3)];
            testCase.verifyEqual(world(1,:),[7.6 8.6 9.6],'AbsTol',1e-12);
            labels=testCase.View.TickLabels;
            testCase.verifyEqual(string({labels.String}),["2.4" "4.4" "6.4" "8.4" "10.4" "12.4"]);
            testCase.verifyEqual(labels(1).HorizontalAlignment,'left');
            testCase.verifyEqual(labels(end).HorizontalAlignment,'right');
            testCase.View.update(12.5,false);
            testCase.verifyEqual(testCase.Axes.XLim,[0 10]);
            testCase.verifyEqual(testCase.Line.XData,[10 11 12]);
            testCase.verifyEqual(labels(end).String,'12.5');
        end
        function exactRefreshAndResetRestoreStandardAxes(testCase)
            testCase.View.update(25,false);testCase.View.update(25.02,true);
            testCase.verifyFalse(testCase.View.RelativeMode);
            testCase.verifyEqual(testCase.Axes.XLim,[15.02 25.02],'AbsTol',1e-12);
            testCase.verifyEqual(testCase.Line.Parent.Matrix,eye(4));
            testCase.verifyEqual(testCase.Axes.XTickMode,'auto');
            testCase.verifyTrue(all(strcmp({testCase.View.TickLabels.Visible},'off')));
            testCase.View.update(26,false);testCase.View.reset();
            testCase.verifyEqual(testCase.Axes.XLim,[0 10]);
            testCase.verifyEqual(testCase.Line.Parent.Matrix,eye(4));
        end
        function initialAndLongSessionsShowConnectionRelativeSeconds(testCase)
            testCase.View.update(.02,false);
            testCase.verifyEqual(testCase.View.TickLabels(1).String,'0.0');
            testCase.verifyEqual(testCase.View.TickLabels(end).String,'10.0');
            testCase.View.update(86400.2,false);
            testCase.verifyEqual(testCase.View.TickLabels(1).String,'86390.2');
            testCase.verifyEqual(testCase.View.TickLabels(end).String,'86400.2');
            testCase.verifyEqual(testCase.Line.XData,[10 11 12]);
        end
    end
end
