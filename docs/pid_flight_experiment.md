# 専用PIDブロックの飛行比較（2026-10-15）

現在の機体に書き込んだモデルは、直下の `StampFly_PIDBlock_FlightTest400.slx` です。`StampFly_Official_FlightTest400.slx` の保存版をコピーし、高度・鉛直速度・ロール角・ピッチ角・ロール角速度・ピッチ角速度・ヨー角速度の7個のPIDを専用ブロックへ置き換えました。元モデルのSHA256は変更前後とも `C0A492B6953C7844E05034AE93C7B90B815EA1E961A8EA488D46FA2DDA9E1BE8` です。

各PIDサブシステム内の `EnabledPID/DedicatedPID` が Simulink の Discrete PID Controller です。以前に比較した `models/PIDBlockComparison400.slx` の構成を使用しています。Ideal形式、台形積分・台形微分フィルター、実測Dt入力、単精度、積分上下限±30000、外部Resetとゼロ初期値を設定しています。ゲインは元PIDの `P=Kp`、`I=1/Ti`、`D=Td`、`N=1/(Eta*Td)` を引き継ぎました。

Enable停止中は状態と出力を保持します。その間のResetは反映されず、PreviousError入力は使用しません。周期変動時の計算にも既知の差があります。この版は、その差が実飛行にどれだけ出るかを見る実験版です。センサー処理、状態遷移、離陸ランプ、目標高度0.5 m、推力制限、モーター配分、ロガーは基準モデルから引き継ぎました。

## 確認済みの範囲

| 確認 | 結果 |
|---|---|
| 接続・Stateflow検査、全モデルのコンパイル | 成功 |
| 同じ離陸・ホバリング・着陸入力、固定Dt、12,000周期 | 8 bitモーター指令・モードが全周期一致 |
| 同比較のDuty最大差 | 約3.58×10⁻⁷ |
| センサー推定などの比較 | 値・型・サイズ一致、非有限値なし |
| ESP32-S3ビルド | 成功、400 Hz・PWM150 kHz指定／8 bit |
| COM4への書き込みと独立した照合 | 成功、digest matched |
| USB待機中の6秒間 | タスク最大1,426 µs、周期超過・取りこぼし0 |
| PWM読み戻し・待機中実出力 | 150,094 Hz／8 bit、4モーターとも0 |

固定入力による比較は、機体の動きが制御へ戻る実飛行を再現していません。実飛行への影響はまだ測定していません。待機中のUSB確認ではJoyStick受信0のため、操縦通信は今回の測定対象に含みません。PWM周波数の指定との差は既存のLEDC分周量子化によるものです。

## 飛行結果の比較

これまでと同じ Stabilize／Auto Altitude、目標0.5 m、短い離陸・ホバリング・着陸を記録し、最高高度、ホバリング中の高度の揺れ、ロール・ピッチ角、角速度の振動、着陸の様子を比較します。実験の録画や機体の位置・床面・電池条件も合わせて記録すると判断しやすくなります。ロガーのMotorCommandsは既存仕様でNaNなので、そこから実出力を判断できません。

機体に書き込んだモデルの記録は [pid_flight_deployment.json](pid_flight_deployment.json)、検証は [pid_flight_verification.json](pid_flight_verification.json)、ビルドは [pid_flight_build.json](pid_flight_build.json) です。基準ファームウェアは `firmware/current/StampFly_Official_FlightTest400.bin`、実験版は `firmware/pid_experiment/` に保存しています。

再ビルドは `verify_pid_flight400(); build_pid_flight400();` です。モデルの再作成・ゲイン設定の履歴は `scripts/model_edit/configure_pid_flight_copy400.m` にあります。生成Cコードは編集していません。モデル名に応じたタスク時間計測だけを低レベルのビルド処理へ追加しています。
