function configure_stampfly_archive()
%CONFIGURE_STAMPFLY_ARCHIVE 過去版を明示的に開く場合の初期化・保守用パス。
% アーカイブSLX自体はパスへ追加しない。同名IMUモデルの混在を避ける。
root=stampfly_project_root();configure_stampfly_project();
base=fullfile(root,'archive','maintenance','scripts');
for folder={'setup','model_edit','verification','build'}
    addpath(fullfile(base,folder{1}),'-end');
end
end
