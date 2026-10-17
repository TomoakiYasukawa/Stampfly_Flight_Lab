classdef ControlSettingsTest < matlab.unittest.TestCase
    % 実モデルの読出し、無変更、入力異常、実係数の反映・復元を機器なしで検証。
    properties
        Settings
    end
    methods (TestMethodSetup)
        function loadModel(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(root,'config'));configure_stampfly_project();
            ensure_simulink_toolkit();assert(library.settingsLookup().gatePass);
            testCase.Settings=imu.ControlSettings.read();
            testCase.addTeardown(@()testCase.restore());
        end
    end
    methods (Test)
        function actualPIDAndHorizontalValuesAreRead(testCase)
            testCase.verifySize(testCase.Settings.PIDValues,[7 4]);
            testCase.verifyEqual(testCase.Settings.PIDValues(:,1), ...
                [.38;.08;5;5;.65;.95;3],'AbsTol',1e-6);
            testCase.verifyEqual(testCase.Settings.HorizontalValues, ...
                [.8;1.8;.5;.3;.6;.6;.25;2],'AbsTol',1e-8);
        end
        function unchangedApplyKeepsExpressions(testCase)
            state=imu.ControlSettings.apply(testCase.Settings, ...
                testCase.Settings.PIDValues,testCase.Settings.HorizontalValues);
            testCase.verifyEqual(state.ChangedParameterCount,0);
            testCase.verifyEqual(state.PIDExpressions,testCase.Settings.PIDExpressions);
        end
        function changesReachTheirActualBlocksAndRemainUnsaved(testCase)
            pid=testCase.Settings.PIDValues;horizontal=testCase.Settings.HorizontalValues;
            pid(1,1)=.39;horizontal(2)=1.9;
            state=imu.ControlSettings.apply(testCase.Settings,pid,horizontal);
            testCase.verifyEqual(state.ChangedParameterCount,2);
            testCase.verifyEqual(state.PIDValues(1,1),double(single(.39)));
            testCase.verifyEqual(state.HorizontalValues(2),1.9);
            testCase.verifyEqual(get_param(state.Model,'Dirty'),'on');
        end
        function invalidValuesDoNotPartiallyApply(testCase)
            pid=testCase.Settings.PIDValues;pid(1,4)=0;
            testCase.verifyError(@()imu.ControlSettings.apply(testCase.Settings,pid, ...
                testCase.Settings.HorizontalValues),'imu:PIDRange');
            after=imu.ControlSettings.read();
            testCase.verifyEqual(after.PIDExpressions,testCase.Settings.PIDExpressions);
        end
    end
    methods (Access=private)
        function restore(testCase)
            if bdIsLoaded(testCase.Settings.Model),close_system(testCase.Settings.Model,0);end
        end
    end
end
