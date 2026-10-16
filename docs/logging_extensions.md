# 飛行ログの読み方

現行機体 `StampFly_IMU400.slx` の **DataLogging50** は、生センサー・推定・操縦指令・モーター・診断を50 Hzで送ります。`M5Stamp_IMU_Rx.slx`を書き込んだ別の受信機をPCへUSB接続し、StampFlyIMUAppで記録します。[接続・記録手順](../README.md#joystickとアプリを使う)

## 表示と記録項目

| 項目 | 意味 |
|---|---|
| 生加速度／角速度 | BMI270のセンサーXYZ。m/s²、rad/s |
| Roll／Pitch／Yaw、Quaternion | IMU Filterで推定した姿勢。QuaternionはWXYZ |
| FilteredGyro | 機体XYZに戻した、PIDへ渡すバイアス補正済み角速度 |
| ToF斜距離／補正高さ | 生距離と傾き補正。高度Kalmanの推定高度とは別の値 |
| 高度／鉛直速度 | AltitudeKalmanの出力 |
| 電池電圧 | V。読み出し有効性と合わせて確認 |
| 光学フロー | 生差分・品質と、平面上の東・北移動距離 |
| 磁気 | BMM150の補償済みセンサーXYZ、µT |
| MotorFR／FL／RR／RL | 計算されたPWMカウント |
| AppliedPWMFR／FL／RR／RL | 適用したPWMカウント。モーター回転数の測定値ではない |
| 欠落／CRC／対象外 | 通常フレームの欠落、破損、別BuildIDの数 |

記録は`recordings/StampFly_日時.mat`です。**［記録停止］**後の保存完了を確認し、**［履歴・比較］→［一覧更新］**で開きます。別フォルダーの記録は **［MATを追加］** で追加できます。

MATLABで詳しく確認する場合は、保存ファイルを指定します。

```matlab
data = imu.readExtendedTelemetry("recordings/StampFly_日時.mat");
data(:,["TimeSeconds","XYX","XYY","FlowUsed","MagX_uT", ...
        "AltitudeReferenceM","RollReferenceRad","AppliedPWMFR"])
```

## 光学フローと磁気

PMW3901は400 Hzで差分を累積し、**OpticalFlowDistance50** が20 ms区間の移動を取り出します。下向きToF、姿勢、角速度から回転成分を除き、[東, 北]の距離へ換算します。平らな床・模様・照明・有効なToFが前提で、**385 count/radは未校正の初期値**です。無効な区間は加算せず位置を保持し、再起動でゼロに戻ります。

BMM150の新規測定は約30 Hz、モデルは400 Hzで最新値を受け取ります。`MagSampleCount`、`MagAgeUs`、Freshなどで新規値と保持値を区別します。磁気・光学フローの移動距離は、姿勢PIDや水平位置保持には使っていません。

## 通信形式と対応づけ

通常 **SFI8は190 byte**、指令補足 **SFIXは190 byte**、センサー補足 **SFIYは246 byte**。同じSequence・Time・BuildIDで対応づけ、CRCを確認します。従来の通常80列に補足121項目を別表で保存し、補足が届かない項目はNaNになります。

BuildID 1401はプログラムの識別子です。同じCHの同じプログラムを持つ複数機体を区別できないため、[専用CH](../README.md#自分専用のチャンネルをそろえる)を割り当てます。受信機のQueuedなどはキュー投入の指標で、電波到達は受信データで確認します。

補足の`TimingMaxExecUs`は計測範囲がタスク全体より狭い値です。全400 Hzタスクの時間はUSB診断の`SFTASK`で確認します。過去の取得レート・飛行・表示テストは[履歴](history/README.md)に保存しています。
