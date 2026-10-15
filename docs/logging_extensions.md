# センサーと指令のロギング

実装モデルは直下の `StampFly_PIDBlock_FlightTest400.slx`、受信機は `M5Stamp_IMU_Rx.slx` です。追加計測は飛行制御へ戻さず、ロガーへ接続しています。7個の専用PIDと離陸・ホバリングの計算は維持しています。

| ブロック | 更新 | 出力 |
|---|---|---|
| OpticalFlowSensor400 | 400 Hz | PMW3901MBの差分、品質、16 bitシャッター値、読出し時間、累積カウント |
| MagnetometerSensor400 | 最新値を400 Hzで取得／新規測定30 Hz | BMM150の補償済み磁場[µT]、更新数、データ年齢、エラー |
| OpticalFlowDistance50 | 50 Hz | 東・北の積算移動距離[m]、使用フラグ、区間移動距離[m] |
| DataLogging50 | 50 Hz | 通常計測、指令補足、センサー補足 |

BMM150の新規測定は最大30 Hzです。400 Hzブロックはcore0の最新値を待たずに読みます。ToF・電池とのI2C排他を共用し、PMW3901MBはBMI270とSPIを共用して2 MHzのMotion_Burstを1回だけ読みます。

## 光学フローの距離グラフ

400 Hzで取得した全差分を累積カウントに保存し、50 Hzの差で20 ms区間の動きを取り出します。下向きToFの距離と姿勢から高さを求め、ジャイロによる回転成分を除去して東・北のメートル値へ変換・積算します。50 Hzの結果はRate Transitionで保持してログ入力へ渡します。アプリの光学フローグラフはこのメートル値を表示します。

換算は以前の `imu.GroundFlowXYTracker` と同じ軸・床面の仮定です。385 count/radは未校正の初期換算値で、実測距離に対する校正が必要です。平らな床、十分な模様と照明、有効なToFが前提です。無効な値や速度上限を超える区間は加算せず、前回の位置を保持します。機体再起動で積算位置はゼロへ戻ります。磁気値はこの位置推定に使用していません。

## 記録の読み方

通常SFI8は従来どおり190 byteです。SFIX190とSFIY246を補足として送り、同じSequence・Time・BuildIDで対応させます。補足はグラフの時刻や通常フレームの欠落数を進めません。既存の80列は維持し、121項目の補足を別表に保存します。

```matlab
data = imu.readExtendedTelemetry("recordings/StampFly_....mat");
data(:,["TimeSeconds","XYX","XYY","FlowUsed","MagX_uT", ...
    "AltitudeReferenceM","RollReferenceRad","AppliedPWMFR"])
```

補足が無線で欠落した行はNaNです。`XYX`・`XYY`は東・北[m]、`FlowDeltaX/Y`は20 ms区間の生カウントです。`FlowLastDeltaX/Y`は400 Hzの最後の1回の値です。`MagSampleCount`と`MagAgeUs`で新規測定と保持値を区別できます。

`MotorFR/FL/RR/RL`は計算されたPWMカウントです。適用出力は補足の`AppliedPWMFR/FL/RR/RL`に保存し、回転速度の測定値ではありません。高度・姿勢・角速度指令、制御出力、制限前ミキサー、JoyStick入力・使用入力、状態、センサー補正値、温度、周期・処理時間も保存します。

## 確認結果

センサー追加前の飛行成功PID版と3シナリオ・36,000周期・15出力を比較し、値・型・サイズが一致しました（`logging_control_verification.json`）。距離換算は既存トラッカーとの100サンプル比較で差0です。距離は表示・記録専用で、飛行制御の入力を変更しません。

距離追加前の実機記録 `StampFly_20261015_213659_399.mat` は60.52秒、通常3,027・補足6,054フレーム、欠落0・CRC0。Flow更新400 Hz、磁気の新規測定30.354 Hz、ToF約25 Hz、磁気エラー0でした。USBの全400 Hzタスク計測は最大2,079 µs、周期超過・取りこぼし0。PWM読み戻しは150,094 Hz／8 bitです。補足の`TimingMaxExecUs`はタスク全体より狭い範囲を計測するため、全タスクの値にはUSBのSFTASKを用います。

距離版の書き込み結果は `logging_aircraft_deployment.json`、ビルドは `logging_build.json`、表示テストは `logger_display_verification.json` を参照してください。今回の距離・追加ロギング版の実飛行はまだ確認していません。
