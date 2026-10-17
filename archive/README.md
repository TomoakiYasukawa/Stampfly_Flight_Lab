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

`snapshots/HorizontalBaseline.slx`は水平補助追加前の保存モデルです。補助OFFでの比較に使い、対応するRevision 1701のBINは`firmware/history/imu_cleanup1701/`に保存しています。この整理後版の実飛行成功は未確認です。以前にユーザーが飛行成功を報告したIMU版は`kf400/baseline/StampFly_IMU400.slx`と`firmware/history/imu400_readability/`で区別します。

`snapshots/Horizontal1801.slx`と`firmware/history/horizontal1801/`は、落下を報告された水平補助版を保全したものです。直下の現行1802は高度・記録・診断を修正した机上版で、実機未確認です。[調査結果と確認範囲](../docs/history/horizontal_trials/20261017_fall_review.md)

保守スクリプトを調べる場合は[maintenance/README.md](maintenance/README.md)、検討と飛行報告は[履歴](../docs/history/README.md)を参照してください。
