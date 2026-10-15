function file=stampfly_model_file(name)
%STAMPFLY_MODEL_FILE Resolve main, library and verification model locations.
root=stampfly_project_root();
name=char(erase(string(name),'.slx'));
if ismember(name,{'StampFly_Official_FlightTest400','M5Stamp_IMU_Rx'})
    folder=root;
elseif strcmp(name,'StampFly_StudentBlocks')
    folder=fullfile(root,'libraries');
elseif contains(name,'Equivalence') || startsWith(name,'Phase')
    folder=fullfile(root,'tests','models');
else
    folder=fullfile(root,'models');
end
file=fullfile(folder,[name '.slx']);
end
