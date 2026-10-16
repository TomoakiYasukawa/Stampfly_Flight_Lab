function file=stampfly_model_file(name)
%STAMPFLY_MODEL_FILE 現行モデルと、明示的に開く比較・履歴モデルの場所。
root=stampfly_project_root();
name=char(erase(string(name),'.slx'));
if strcmp(name,'StampFly_KF400')
    folder=fullfile(root,'archive','kf400');
elseif ismember(name,{'StampFly_IMU400','M5Stamp_IMU_Rx'})
    folder=root;
elseif ismember(name,{'StampFly_Basic400','StampFly_Official_FlightTest400', ...
        'StampFly_PIDBlock_FlightTest400','StampFly_Official_Bench400', ...
        'StampFly_PWM400_Probe','StampFly_Official_EstimatorReplay400', ...
        'StampFly_Official_FlightSim400','StampFly_Official_FullReplay400','PIDBlockComparison400'})
    folder=fullfile(root,'archive','aircraft');
elseif strcmp(name,'StampFly_StudentBlocks')
    folder=fullfile(root,'libraries');
elseif contains(name,'Equivalence') || startsWith(name,'Phase')
    folder=fullfile(root,'tests','models');
else
    folder=fullfile(root,'models');
end
file=fullfile(folder,[name '.slx']);
end
