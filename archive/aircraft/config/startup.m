% アーカイブしたモデルを単独で開く場合も、現行プロジェクトを初期化する。
% archive 自体は通常の MATLAB パスには追加しない。
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
run(fullfile(root,'config','startup.m'));
configure_stampfly_archive();
