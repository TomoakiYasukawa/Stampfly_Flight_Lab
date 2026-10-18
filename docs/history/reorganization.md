# StampFly_Labへの整理（2026-10-18）

プロジェクト名を`StampFly_Lab`、フォルダ名を`stampfly_lab`、機体モデルを`Stampfly_Tx`、受信モデルを`M5Stamp_Rx`、アプリを`DataLogger`へ統一しました。モデルの演算・端子接続・Stateflowコードとアプリの機能・AppIdを保っています。

READMEを初めて機体を飛ばす人向けに書き直し、アプリガイドをプロジェクト直下の`DataLogger_GUIDE.md`、agentic AIの引き継ぎを`AI_CONTEXT.md`へ配置しました。

現行の説明は`docs/`、過去の検証JSON・画面・試行記録はSHA-256付きの`docs/history/records.zip`と索引へまとめています。過去の一度だけ使う編集スクリプト・モデル・BINは、比較と復元に使える記録集へ整理しました。未使用のダウンロード、同一内容の複製、生成コード・キャッシュ・MEX・作業ファイルは削除しました。ユーザー記録と固有の実機バックアップは保全しています。

新しいモデル名で両モデルのビルドが成功しています。機体BINは1,003,616バイト、受信機BINは853,888バイトです。新しい名前の周期計測ラッパーとCPU1固定を確認しています。ビルドと実機書き込みは別工程で、今回生成したBINは実機へ書き込んでいません。

アプリ・記録・表示の回帰試験83件、公式C++との数値・パケット比較、独立コピーのモデル更新・DataLogger起動・制御パラメータ操作を確認しました。検証・容量の詳細は[reorganization.json](reorganization.json)、整理に使った機械向けの記録は[reorganization_evidence.zip](reorganization_evidence.zip)と[索引](reorganization_evidence.index.json)を参照してください。整理前の原本はローカルの`backups/project_before_stampfly_lab_20261018/`へ保全しました。Gitのコミット・プッシュ・リモート設定は行っていません。

整理後のプロジェクト容量（Git履歴を除く）は約155.4 MiBです。整理前の約1281.2 MiBから約1125.9 MiB、87.9%削減しました。記録MAT15件と固有バックアップを残した状態の容量です。

stampfly_labへGit履歴を含む全内容を移し、新しい場所でモデル更新・DataLogger起動／終了・両モデルのビルドを確認しました。旧Official_setupは空ですが、このDevAI/Codexセッション自身が参照しています。参照解除後に空のフォルダだけを削除する補助処理を用意しました（8時間以内、中身が現れた場合は停止）。次回はstampfly_labから開いてください。
