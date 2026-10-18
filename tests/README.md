# 再利用できる試験

アプリ・ログの回帰試験は`*Test.m`、通信形式・水平推定の比較は`verify_*.m`です。いずれも機器を接続せず確認するための入口です。実機書き込みは行いません。

| 場所 | 用途 |
|---|---|
| `DataLoggerDisplayTest`／`DataLoggerResponsivenessTest` | 受信・描画・保存・履歴・連続削除・終了・並列再起動 |
| `FlightRecorderTest`／`RecordingHistoryTest` | 自動記録とログ境界、履歴解析 |
| `FlowDisplayFrameTest`／`LiveTimeAxesTest`／`StampFlyPoseProjectionTest` | 表示方向、時刻、3面投影 |
| `ControlSettingsTest` | 現行モデルの7 PID・水平係数の読出し・反映 |
| `reference/` | 公式C++比較ソースとログ互換基準。MEXは`build/tests/mex/`へ生成 |
| `models/` | 現行の水平推定・制御・閉ループ・Gherkinハーネス |
| `reference/model_regressions.zip` | 過去のモデル比較ハーネス。`stampfly_model_file`で必要時に展開 |
| `reference/horizontal_timing_baseline.zip` | 周期改善前の数値比較基準。コード生成の回帰確認で利用 |
| `+horizontaltest/` | 閉ループ試験用の簡易剛体。実機同定値ではない |
| `radio_stubs/`、`radio_link_test.cpp` | 無線リンクのホスト試験 |

実行例と必要な製品は[docs/development.md](../docs/development.md)を参照してください。試験の出力は`build/`に保存し、過去の検証記録は[docs/history](../docs/history/README.md)から参照します。
