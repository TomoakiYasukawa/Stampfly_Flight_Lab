# アーカイブ

現行の機体実装は直下の **`StampFly_IMU400.slx`** です。直下の **`M5Stamp_IMU_Rx.slx`** はログ受信機です。以下は過去の比較・再生・実験用として保存しています。

| フォルダー | 内容 |
|---|---|
| [aircraft](aircraft/README.md) | 基礎版、FlipありPID版、公式版、机上・再生モデル |
| [kf400](kf400/README.md) | 標準高度Kalman版、比較時のIMU基準モデル、書き込み済みBIN |
| snapshots | センサー・Stateflow・配線整理などの各時点のモデルコピー |
| maintenance | 過去の構築・比較・ビルド・書き込みスクリプト |
| logging_before_20261015、before_tof_tilt_20261015 | 過去のロガー、モデル、ファームウェアのセット |
| logger_packers | 旧ログ形式と比較するためのパッカー |

プロジェクトを開いて対象SLXを直接開きます。アーカイブ全体を通常のMATLABパスへ追加しないでください。同名IMUモデルが存在します。古いモデルの設定・モーター出力条件はモデルごとに異なります。

保守スクリプトを調べる場合は[maintenance/README.md](maintenance/README.md)、検討と飛行報告は[履歴](../docs/history/README.md)を参照してください。
