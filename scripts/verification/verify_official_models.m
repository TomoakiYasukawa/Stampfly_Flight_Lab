function result=verify_official_models()
%VERIFY_OFFICIAL_MODELS Independent official reference and Simulink replay.
init_official;root=stampfly_project_root();addpath(fullfile(root,'tests'));
result.FullSequence=compare_full_model();
result.EdgeCases=compare_full_edges();
result.Estimator=compare_embedded_estimators();
result.LoggerCRC=verify_logger_crc();
result.LoggerPackets=verify_logger_packets();
result.BottomLogger=verify_bottom_logger();
save(fullfile(root,'tests','verification_summary.mat'),'result');disp(result);
end
