# 開発・実験の履歴

現行の機体モデルは **`StampFly_IMU400.slx`**、高度推定はMATLAB FunctionのAltitudeKalmanです。[現在の使い方](../../README.md)と[モデル解説](../imu_flight_model.md)は履歴から分離しています。

| 段階 | 内容・結果 | 主な記録 |
|---|---|---|
| 公式制御の移植 | センサー、状態遷移、制御、ログをSimulinkへ移植。配線・PID構成を比較 | [公式モデル](official_simulink.md)、[PID比較](control_layout_and_pid.md) |
| ログ拡張 | 磁気・光学フロー・制御指令、移動距離の記録を追加 | [当時のログ説明](logging_before_cleanup.md)、[表示確認](logger_display_verification.json) |
| 宙返りなしの基礎版 | Flip機構を削除。ユーザーが「完璧です」と実飛行成功を報告。飛行ログなし | [基礎版](basic_flight_model.md)、[書き込み](basic_aircraft_deployment.json) |
| 標準IMU Filter版 | 姿勢とバイアス補正済み角速度を標準ブロックで推定。ユーザーが実飛行成功を報告 | [書き込み・飛行](imu_aircraft_deployment.json)、[検証](imu_flight_verification.json) |
| IMU版の階層整理 | Supervisorを最上位へ移し、推定・飛行状態・時刻・ログを整理。ユーザーが「飛行試験OKです。」と報告 | [整理前後の検証](imu_readability_verification.json)、[書き込み](imu_readability_aircraft_deployment.json) |
| 標準高度Kalman版 | 単体・全体比較、ビルド、書き込みを実施。ユーザーが「実飛行テスト、問題なしです」と報告。飛行ログなし | [比較用解説](kf_flight_model.md)、[検証](kf_flight_verification.json)、[書き込み](kf_aircraft_deployment.json) |
| 現行IMU版の再整理 | 元の高度MATLAB Functionを採用。ToFのMode入力削除、XYZベクトル化、余分な階層削除、日本語説明、配置と配布構成を整理。機体・受信機ビルドと配布用コピーのモデル・アプリ起動を確認 | [変更と検証結果](../imu_cleanup_validation.md)、[比較](../imu_cleanup_verification.json) |
| 再整理IMU版の書き込み | 検証済みBINをCOM4の機体へ書き込み・照合。USB机上確認でCRCエラー・待機PWMはゼロ。実飛行は未実施 | [書き込み](../imu_cleanup_aircraft_deployment.json)、[USB確認](../imu_cleanup_usb_startup.json) |
| 光学フロー水平補正1801 | 移動中の速度PI、中立後の減速・停止位置保持を実装。既存7 PIDを維持。単体、OFF回帰、閉ループ、条件のずれ、生成MEX、アプリ・ログを検証後に書き込み。実飛行で約5秒後の落下報告 | [操作と検証範囲](../horizontal_control.md)、[書き込み](../horizontal_aircraft_deployment.json)、[当初の検討](../horizontal_hold_review.md) |
| 落下・Z速度・記録の調査1802 | 加速度g→m/s²、待機リセットの立上り化、自動記録と公式状態表示、起動理由・USB診断を修正。書き込み後、飛ばさない待機中にCPU0 idle watchdogによる自動再起動を捕捉。実飛行の直接原因は未確定 | [調査結果](horizontal_trials/20261017_fall_review.md)、[watchdogとELFの照合](horizontal_trials/20261017_waiting_watchdog.json)、[自動記録検証](../incident_recording_verification.json) |
| CPU固定と机上試験1803 | Baserateを生成時からCPU1へ固定し、CPU間のidle時刻読取り競合を修正。90秒待機と約18秒のプロペラなしMode 2で再起動なし。ただし2.5 ms周期超過とタイマー取りこぼしが残る | [待機](../runtime1803_waiting_verification.json)、[Mode 2](../runtime1803_mode2_verification.json)、[CPU設定](../cpu_tasks.md) |
| 区間計測・安定飛行1804 | CPU1固定を維持し、既存外部関数間の区間計測を追加。書き込み・照合後、ユーザーが「問題は解消され、安定して飛びました」と実飛行成功を報告。高速化の追加前に成功版を保全 | [実飛行と保存版](../incident1804_flight_verification.json)、[区間計測](../runtime1804_sections_waiting.json) |
| ロガー表示・制御設定の整理 | 保存先選択、同時刻SFIXによる細かな制御値、診断帯、状態順、XY開始・終了、データ名を追加。未使用の操作設定を実7 PID・水平P/PIのモデル設定へ変更 | [変更理由](logger_app_20261017.md)、[アプリ操作](../logger_app.md)、[制御係数](../control_parameters.md) |

標準高度Kalman版は、予測・補正・特殊な待機リセットを標準ブロックへ合わせる周辺処理が増えました。基礎教材で読みやすいMATLAB Function版を採用し、KF版は追加配線修正を行わず、実飛行したモデルとBINを **[archive/kf400](../../archive/kf400/README.md)** に保存しています。

**今回の再整理後モデルは、過去の飛行成功モデルと別の保存版です。** 比較・ビルドの結果と、実機書き込み・飛行の確認はそれぞれの記録で区別します。旧版の飛行成功を今回の再整理版の飛行試験として扱いません。

最新の書き込み・実飛行成功版は **1804（CH 3）** です。[機体への書き込み](../incident_aircraft_deployment.json)と[実飛行報告](../incident1804_flight_verification.json)で、モデル・BINのSHA-256を確認します。成功版は `archive/snapshots/Horizontal1804.slx`・`firmware/history/horizontal1804/`へ保全しました。実飛行で落下した1801と、待機中のwatchdogを捕捉した1802も別保存しています。以前のIMU成功BINは `firmware/history/imu400_readability/`です。

`README_before_imu_cleanup.md`、`imu_model_before_cleanup.md`、`firmware_before_cleanup.md`は編集前の説明を保存したものです。当時の「現在」・「未飛行」などの表現はその時点の記録であり、最新状態はこのページと個別JSONを参照してください。移動前の場所は[移動一覧](../imu_distribution_moves.json)で確認できます。
