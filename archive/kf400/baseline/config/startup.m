% 保存済みIMU基準モデルの共通設定を準備する。
archiveTaskRoot=fileparts(mfilename('fullpath'));
archiveTaskRoot=fileparts(archiveTaskRoot);
archiveTaskRoot=fileparts(archiveTaskRoot);
archiveTaskRoot=fileparts(archiveTaskRoot);
archiveTaskRoot=fileparts(archiveTaskRoot);
run(fullfile(archiveTaskRoot,'config','startup.m'));
