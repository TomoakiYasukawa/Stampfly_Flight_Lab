# StampFly の現在の状態（2026-10-15）

`FlightControl400`・`TakeoffHoverControl400` の分割と配線整理を含む最新の保存モデルをビルドし、USB 接続・バッテリーなしの機体へ再書き込みしました。独立した照合で `digest matched` を確認しています。現在の保存モデルと機体内のファームウェアは同じ更新版です。

## 機体に入っている版

`firmware/current/StampFly_Official_FlightTest400.bin`。SHA256 は `276049CBB0723367D9B74944E5B491F468ED289DA0A66C580672CA63510EA49B`。生成元は直下の `StampFly_Official_FlightTest400.slx`、モデルの SHA256 は `C0A492B6953C7844E05034AE93C7B90B815EA1E961A8EA488D46FA2DDA9E1BE8`、ビルド出力は `build/model_reorganization/` です。COM4 の StampFly へアプリ領域だけを書き込み、照合に成功しました。記録は `docs/control_layout_flight_deployment.json` と `docs/reorganized_flight_deployment.json`。この更新版の実飛行と実機処理時間の測定はまだ行っていません。直前に機体へ入っていた版は `firmware/history/before_control_layout_20261015_175607/` に保存しました。

前回の飛行成功版は `firmware/previous_successful/StampFly_Official_FlightTest400.bin`、SHA256 は `5A3D486B4152BB3328E481755A2E93826A5616160FB5929266D73AB4EAFC7C14` です。この旧版ではユーザーから実飛行成功とロガー正常動作の報告を受けています。旧版の USB ベンチ確認では、400 Hz タスクの最大実行時間 1994 µs、周期超過・取りこぼし 0、PWM 読み戻し 150094 Hz／8 bit、待機中のモーター実出力 0、JoyStick 受信を確認しました。150 kHz 指定との差は LEDC の分周量子化によるものです。外部計測器での PWM 波形測定は行っていません。

## 今回の保存モデル

直下の `StampFly_Official_FlightTest400.slx`。

- 最上位に IMU・下向き ToF・電池センサー、センサー補正、姿勢・高度推定、飛行制御、モーター書き込みを分離しました。
- 主要ブロックの入力・出力はそれぞれ最大 4 ポートです。関連信号をバスにまとめ、主処理とフィードバックは直接配線しました。
- Stateflow Chart は飛行状態監督、Flip、離着陸指令、最終飛行モード決定の 4 個です。すべて状態・遷移を持ち、Chart 内の MATLAB Function は 0 個です。数値計算は Simulink または独立した MATLAB Function に置き換えています。
- 自動生成の信号名末尾を説明的な名前へ変更し、日本語の説明とレイアウトを整えました。ロギング・LED・JoyStick などの補助経路には Goto/From を使用しています。

最初の飛行成功モデル `archive/FlightTest_disk_before_sensor_blocks_20261015_092114.slx` に対し、3 シナリオ・計 36,000 周期で 15 出力の値・型・サイズがすべて一致しました。離陸・ホバリング・着陸、モード変更・手動高度・Flip、センサー更新タイミング・外れ値・通信中断・OverG・リセットを含みます。証拠は `tests/final_pipeline_equivalence.mat`、再実行は `verify_final_pipeline` です。この比較は同じ入力に対する制御・推定アルゴリズムの等価性確認であり、新版の実飛行や実機処理時間の測定ではありません。

全モデルのコンパイルと接続・Stateflow 検査は成功しています。400 Hz（2.5 ms）、PWM 150 kHz 指定／8 bit の設定を維持しています。

フォルダー整理後、独立した MATLAB セッションで機体・受信機モデルのコンパイルとパス解決を確認しました。記録は `docs/project_layout_verification.json`。同一デスクトップに移動前の System object が残る場合、旧クラスのパスがキャッシュされることがあります。既存作業を保存し、次回 MATLAB を起動し直してから `run('config/startup.m')` を実行してください。

最終ビルドの出力先は `build/model_reorganization/`、再実行は `build_reorganized_flight_model` です。成功時に `tests/reorganized_flight_build.mat` と `docs/reorganized_flight_build.json` を保存します。この処理は書き込みを行いません。学生用ライブラリーへの反映と追加レイアウト調整は、ユーザーの「作業はそこそこで終了」に合わせて保留しています。

その後、指定された飛行制御部分を高度・姿勢角・角速度・モーター配分・飛行指令・診断へ分割し、日本語の入出力説明とレイアウトを整えました。整理開始時の保存モデルとの比較は3シナリオ・36,000周期・15出力すべて一致、機体モデルのコンパイルも成功しています。4個のStateflow Chartと内部MATLAB Function 0個を維持しています。PID専用ブロックの候補は周期変動・リセット時に非等価となり、本番PIDは元の構成を残しています。[詳細と比較結果](control_layout_and_pid.md)を参照してください。この更新版は ESP32-S3 ビルド、COM4 への書き込み、独立した digest 照合まで完了しました。実飛行は行っていません。

## 下向き ToF と Optical Flow

下向き ToF の同期エラーは解消済みです。core0 が I2C 通信を担当し、400 Hz 側は完成した最新値を受け取ります。実測取得は約 25 Hz。持ち上げ試験で距離 0.305〜0.345 m、ToFValid=1、status=0、読み出しエラー 0、高度推定の追従を確認しました。追加の持ち上げ確認は不要です。

前向き ToF は無効、Optical Flow は未実装で NaN／無効フラグを保持しています。目標高度初期値 0.5 m、目標範囲 0.05〜1.8 m、Duty 上限 0.95 などは元のままです。

## 操作と記録

前回成功した試験は Stabilize／Auto Altitude です。待機中の中央ボタン操作で FLIGHT、飛行中の 1 回操作で LANDING、着陸中の追加操作で PARKING へ移ります。元の押下・解放判定を保っており、中央ボタンは瞬時停止の入力ではありません。

COM9 ロガーは今回の整理で操作していません。現行パッカーの MotorValid は 0 固定なので、アプリの MotorCommands は NaN です。rawFrames の 105〜108 byte は計算指令値であり、適用した実出力の計測値ではありません。

アプリの XML はユーザーの指定に従い直下へ戻しました。`AppConfigFilename` を元の形式へ戻し、アプリ生成・ウィンドウ表示と App Designer への読み込みを確認しています。これらの確認では新しいシリアル接続を開いていません。

初回飛行ログは `recordings/StampFly_20261015_090137_551.mat`。初回はユーザーが「離陸・短いホバリング・着陸できた」「うまくいったので OK」と確認済みです。初回版の書き込み記録は `docs/flight_test_deployment.json`。整理前の状態説明は `archive/current_flight_status_before_reorganization.md` に残しています。
