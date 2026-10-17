function folder=recordingFolder(app)
%RECORDINGFOLDER 概要：履歴一覧と自動・手動記録で同じ保存先を使います。
% 空の設定はプロジェクト直下のrecordingsを意味します。
folder=string(app.RecordingFolder);
if isempty(folder) || strlength(folder)==0
    folder=string(fullfile(fileparts(which('StampFlyIMUApp')),'recordings'));
end
end
