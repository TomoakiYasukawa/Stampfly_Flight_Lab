# SensorProcessing400 の構成変更

対象は `StampFly_Official_FlightTest400/OfficialTakeoffHover400/SensorProcessing400`。この範囲の計算用 Stateflow Chart 9個を、標準 Simulink サブシステム4個と MATLAB Function 5個に置き換えました。

| ブロック | 役割 | 実装 |
|---|---|---|
| IMUAxisConversion | BMI270の軸を機体座標へ合わせ、加速度をg単位へ変換 | Selector、Product |
| IMUBiasCalibration | 静止時800周期の平均からジャイロXYZ・加速度Zの校正値を求める | MATLAB Function |
| IMUFiltering | ジャイロの校正値を引き、加速度・角速度・Z加速度差分のノイズを減らす | Sum、一次フィルター7系統 |
| MadgwickAttitude | 加速度と角速度からクォータニオン、Roll/Pitch/Yawを推定 | MATLAB Function |
| VerticalAcceleration | Z加速度差分の符号を反転し、鉛直方向の入力を平滑化 | Gain、一次フィルター |
| ToFHoldOutlierFilter | 下向きToFの新着距離を保持し、外れ値を処理 | MATLAB Function |
| AltitudeKalman | ToF距離と鉛直加速度から高度・鉛直速度・加速度バイアスを推定 | MATLAB Function |
| SensorFlags | 過加速度、距離・高度異常、低電圧を判定 | MATLAB Function |
| SensorDiagnosticPack | 推定値と校正値を記録用ベクトルへまとめる | Data Type Conversion、Mux |

## IMUFiltering・MadgwickAttitude・AltitudeKalman の違い

IMUFilteringは推定器へ渡す信号を整えます。加速度3軸と校正後ジャイロ3軸には時定数3 ms、校正後Z加速度差分には100 msの一次フィルターを適用します。加速度XYZすべてから重力を除去する処理ではありません。

MadgwickAttitudeは機体の向きを求めます。ジャイロで回転を追い、加速度の重力方向で主にRoll/Pitchのずれを補正します。磁気センサーを使わないため、Yawの絶対方位は保証されません。公式の固定400 Hz、β=0.1、軸対応・Yawオフセット・逆平方根近似を維持しています。

AltitudeKalmanは機体の高さと上下の動きを求めます。状態は `[鉛直速度; 高度; 加速度バイアス]`。下向きToFは低速更新で、その最新保持値と鉛直加速度を400 Hzで使います。高度制御へ高度を、鉛直速度制御へ速度を渡します。

現行の公式互換構成では、Madgwickの姿勢を用いて加速度を地面座標へ回転する処理はありません。VerticalAccelerationは校正したZ加速度を符号反転・平滑化し、公式と同じくg単位のままKalmanへ渡します。今回はこの単位と処理順も変更していません。

## 等価性の確認

変更開始時のメモリー上のモデルを `archive/FlightTest_before_sensor_blocks_20261015_092114.slx` に保存し、比較基準にしました。ディスク上の変更前モデルも別途保存しています。

`verify_sensor_replacement.m` が旧・新センサー処理を同じ入力で並列実行します。固定周期2.5 ms、3ケース各6,000周期、合計18,000周期を比較しました。

- BootTakeoffResets：起動、800点校正、待機、飛行、着陸、待機再進入、Flip、推定器リセット。
- StartInFlight：飛行状態から開始し、INIT/AVERAGEへの戻りと繰り返しリセット。
- TimingAndRangeEdges：Dt変化、ToFの飛び・ゼロ・20 mm未満・負値、過加速度、低電圧、飛行中reset。

全7出力（姿勢、角速度、高度、鉛直速度、状態フラグ、クォータニオン、診断）の値・型・サイズが一致し、最大数値差0、不一致数0でした。許容誤差で丸めず比較しています。これは上記入力条件でのシミュレーション結果であり、すべての可能な入力や実機処理時間を実測した結果ではありません。

MATLAB Function 5個の本文・persistent状態は変更前の関数と同じです。標準一次フィルターも `前回値*T/(T+Dt) + 入力*Dt/(T+Dt)` の演算順序とsingle型を保ちます。待機への遷移でフィルターをゼロから更新し、mode<=1では出力を保持します。

結果は `tests/sensor_equivalence_summary.mat`、各ケースの入出力は `tests/sensor_equivalence_*.mat`、比較ハーネスは `models/SensorProcessingEquivalence400.slx` に保存しています。

`build_sensor_replacement.m` によるESP32-S3向けコード生成・コンパイル・リンク・bin生成も成功しました。固定周期2.5 ms、PWM150000 Hz指定、8 bitを確認しています。対象外のChartの名前重複、診断バス名、single量子化に関する既存警告は残っています。

ビルド結果は `build/sensor_replacement/`、記録は `logs/sensor_replacement_build.log` と `tests/sensor_replacement_build.mat`。新binのSHA256は `5a3d486b4152bb3328e481755a2e93826a5616160fb5929266d73ab4eafc7c14` です。`tests/sensor_scope_preservation.json` は対象外のブロック・接続、Chartの関数本文・状態ラベル、コンフィギュレーションが変わらないことを記録します。

## 編集モデルと機体の区別

ユーザーの実機確認の指示により、2026-10-15に `build/sensor_replacement/StampFly_Official_FlightTest400.bin` をCOM4のStampFlyへ書き込みました。アプリ領域0x10000のみを書き換え、書き込み後に全969200 byteの読み取り照合が成功しています。ブートローダー・パーティションは変更していません。

USB給電・バッテリーなしで30秒確認し、400 Hzの全処理最大1994 µs、周期超過0、タイマー取りこぼし0、PWM読み戻し150094 Hz／8 bit、待機中の4モーター実出力0を確認しました。JoyStick指令の受信と、ユーザーによるロガー正常動作の確認も済んでいます。記録は `logs/sensor_replacement_usb_boot_COM4.bin`、`.summary.json`、`.telemetry.json`。実飛行の結果はこのUSB確認とは別に記録します。

現在の書き込み記録は `sensor_replacement_deployment.json`。`flight_test_deployment.json` とルートの `StampFly_Official_FlightTest400.bin`（SHA256 `1be3fd208a48e28de03acec995c71c9858a9d721ee789479e976b68f71d06d43`）は初回飛行版の履歴として保持しています。

変更範囲外の状態監督・飛行制御・入出力は従来の構成です。MATLAB Functionは内部APIではStateflow.EMChartとして扱われますが、ここには状態・遷移を持つStateflow Chartはありません。

`prepare_official_flight_test` はBenchモデルからFlightTestモデルを作り直すため、実行すると今回の構成変更を上書きします。今回のモデルを維持してビルドする際は、この再作成関数を使わず、保存済みFlightTestモデルを直接ビルドしてください。
