# 履歴の要約と原文記録集

現行の操作は[README](../../README.md)、開発は[development.md](../development.md)を使います。このページは過去の判断と結果を探す入口です。検証・書き込み・実飛行は、それぞれ記録された版の結果です。

## 主な経緯

| 段階 | 判明したこと・結果 | 原文の名前（records.zip内） |
|---|---|---|
| 公式制御の移植・PID整理 | 公式C++とSimulinkを比較。状態・配線・PIDを確認 | `docs/history/official_simulink.md`、`docs/history/control_layout_and_pid.md` |
| 基礎版・IMU Filter版 | 宙返りを除いた版、標準IMU Filter版でユーザーから飛行成功報告 | `docs/history/basic_flight_model.md`、`docs/history/imu_aircraft_deployment.json` |
| 標準高度Kalman比較 | 比較・書き込み・ユーザー飛行成功。現行は読みやすいMATLAB Function版を採用 | `docs/history/kf_flight_model.md`、`docs/history/kf_aircraft_deployment.json` |
| IMU構造の再整理 | 36,000時刻・36出力を整理前後で比較。生成依存元と配布先起動を確認 | `docs/imu_cleanup_verification.json`、`docs/imu_cleanup_build.json` |
| 水平補助1801 | 速度PI・停止位置保持を追加。机上試験後の実飛行で約5秒後の落下報告 | `docs/history/horizontal_trials/20261017_fall_review.md`、`docs/horizontal_aircraft_deployment.json` |
| 高度・待機・診断1802 | g→m/s²、待機リセットの立上り化。飛ばさない待機でもCPU0 idle watchdog再起動を捕捉 | `docs/history/horizontal_trials/20261017_waiting_watchdog.json` |
| CPU固定1803 | BaserateをCPU1へ固定し、idle時刻のCPU間競合を修正。待機とプロペラなしMode 2で再起動なし。周期問題は残る | `docs/runtime1803_waiting_verification.json`、`docs/runtime1803_mode2_verification.json` |
| 区間計測・成功1804 | CPU1固定・watchdog維持。ユーザーが問題解消・安定飛行を報告 | `docs/incident1804_flight_verification.json`、`docs/runtime1804_sections_waiting.json` |
| DataLoggerの応答・描画改善 | 保存キュー、履歴キャッシュ、空フォルダ、連続削除、方向・凡例、3面投影、並列再起動を改善 | `docs/app_responsiveness_verification.md`、`build/tests/app_regression/latest_all_app_tests.json` |
| 2026-10-18の最新書き込み | 整理前モデルをCOM4へ照合して書き込み、USB起動・校正・待機PWMゼロを確認。新たな実飛行は行っていない | `docs/latest_aircraft_build.json`、`docs/latest_aircraft_deployment.json`、`docs/latest_verified_usb_startup.json` |
| StampFly_Labへの整理 | 名称・参照・プロジェクトを更新。モデル演算・接続・Stateflowを保持して新しい名前で両モデルをビルド。アプリと新しい場所の起動を検証 | [整理結果](reorganization.md) |

1804の安定飛行はユーザー報告です。飛行時間や性能を裏付ける飛行ログはその報告に添付されていません。USB診断で2.5 ms周期超過が残ることと、安定飛行の報告を分けて扱います。

## 必要な記録だけを開く

**[records.zip](records.zip)**には旧説明・検証JSON・モデル画面・試験計測を原文のまま保全しています。**[index.json](index.json)**に元のパス、ZIP内の場所、サイズ、SHA-256があります。内容の旧モデル名・COM・保存場所は作成時の記録です。

```matlab
file = stampfly_record_file('docs/latest_aircraft_deployment.json');
record = jsondecode(fileread(file));
```

```powershell
python tools/history_records.py list --contains 1804
python tools/history_records.py show docs/incident1804_flight_verification.json
```

`stampfly_record_file`は`build/history/records/`へ展開します。新しい検証結果は`build/reports/`へ保存し、過去の記録を上書きしません。

## 復元・比較するファイル

- 水平補助の基準、失敗1801、成功1804：`archive/snapshots/`。
- 標準高度Kalmanの飛行したモデル・BINと比較基準：`archive/kf400/`。
- 成功1804のBIN・manifest・ソース保全：`firmware/history/horizontal1804/`。
- 整理前のモデル・BINと最新書き込みBIN：`firmware/history/before_stampfly_lab_20261018.zip`。
- それより古いBIN：`firmware/history/earlier_firmware.zip`。索引に元パスとSHA-256。
- 過去の構築・モデル編集スクリプト：`archive/development_history.zip`。旧モデル一式：`archive/model_history.zip`。

個別のモデル名・ハッシュ対応を確認してから使います。古い展開スクリプトのMACやCOMを新しい購入機へそのまま適用しません。
