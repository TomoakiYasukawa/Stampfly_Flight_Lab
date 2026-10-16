% 比較用KFモデルを開いたとき、共通設定と過去版の初期化関数を準備する。
archiveTaskRoot=fileparts(mfilename('fullpath'));
archiveTaskRoot=fileparts(archiveTaskRoot);
archiveTaskRoot=fileparts(archiveTaskRoot);
archiveTaskRoot=fileparts(archiveTaskRoot);
run(fullfile(archiveTaskRoot,'config','startup.m'));
configure_stampfly_archive();
