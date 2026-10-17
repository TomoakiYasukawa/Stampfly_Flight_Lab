# 飛行ログの読み方

現行機体 `StampFly_IMU400.slx` の **DataLogging50** は、生センサー・推定・操縦指令・モーター・診断を50 Hzで送ります。`M5Stamp_IMU_Rx.slx`を書き込んだ別の受信機をPCへUSB接続し、StampFlyIMUAppで記録します。[接続・記録手順](../README.md#joystickとアプリを使う)

## 表示と記録項目

| 項目 | 意味 |
|---|---|
| 生加速度／角速度 | BMI270のセンサーXYZ。m/s²、rad/s |
| Roll／Pitch／Yaw、Quaternion | IMU Filterで推定した姿勢。QuaternionはWXYZ |
| FilteredGyro | 機体XYZに戻した、PIDへ渡すバイアス補正済み角速度 |
| ToF斜距離／補正高さ | 生距離と傾き補正。高度Kalmanの推定高度とは別の値 |
| 高度／鉛直速度 | AltitudeKalmanの出力。m／m/s、上昇＋。速度はPIDへ直接入力 |
| ToF高度変化率 | 新規・傾き補正済みToFの直前0.25秒の傾き。比較用で、制御入力ではない |
| 電池電圧 | V。読み出し有効性と合わせて確認 |
| 光学フロー | 生差分・品質と、平面上の東・北移動距離 |
| 水平補助 | 局所[基準機首, 右]の位置・速度・目標・PI積分・状態・観測の有効性 |
| 磁気 | BMM150の補償済みセンサーXYZ、µT |
| MotorFR／FL／RR／RL | 計算されたPWMカウント |
| AppliedPWMFR／FL／RR／RL | 適用したPWMカウント。モーター回転数の測定値ではない |
| 欠落／CRC／対象外 | 通常フレームの欠落、破損、別BuildIDの数 |

記録は`recordings/StampFly_日時.mat`です。飛行制御（2）・自動着陸（5）で自動開始し、直前2秒と待機復帰後1秒を保存します。接続時に飛行中でも開始します。手動記録は机上確認用です。保存完了を確認し、**［履歴・比較］→［一覧更新］**で開きます。別フォルダーの記録は **［MATを追加］** で追加できます。

状態は **0=初期化、1=800サンプル校正、2=飛行制御、3=待機、5=自動着陸** です。Mode 2はモーター立上げを含み、ホバリングの開始ではありません。最初の飛行の0秒はMode 2／5を最初に観測した時刻で、直前記録は負値です。実際に浮上した瞬間は高度・モーターと合わせて読みます。

保存終了理由は待機復帰・通信途絶・機体時刻リセット・手動停止・切断などを区別します。再起動前後や長い欠測を線で結びません。単独の古い／重複パケットは履歴から除き、生データには残します。時刻リセットだけでは電源断・ウォッチドッグ・手動操作を区別できません。

固定PID版の旧`RawVerticalVelocityMps`と`FilteredVerticalVelocityMps`は**同じKalman速度の重複列**です。別のLPFは通っておらず、アプリも重複表示しません。ToF変化率は新規値だけを用い、150 msを超える欠測・無効値・時刻逆転をまたぎません。高度推定が使う斜距離と、表示用の鉛直投影も区別します。

MATLABで詳しく確認する場合は、保存ファイルを指定します。

```matlab
data = imu.readExtendedTelemetry("recordings/StampFly_日時.mat");
data(:,["TimeSeconds","XYX","XYY","FlowUsed","MagX_uT", ...
        "AltitudeReferenceM","RollReferenceRad","AppliedPWMFR"])
```

## 光学フローと磁気

PMW3901は400 Hzで差分を累積し、**OpticalFlowDistance50** が20 ms区間の移動を取り出します。下向きToF、姿勢、角速度から回転成分を除き、[東, 北]の距離へ換算します。平らな床・模様・照明・有効なToFが前提で、**385 count/radは未校正の初期値**です。無効な区間は加算せず位置を保持し、再起動でゼロに戻ります。

BMM150の新規測定は約30 Hz、モデルは400 Hzで最新値を受け取ります。`MagSampleCount`、`MagAgeUs`、Freshなどで新規値と保持値を区別します。磁気は表示・記録用です。水平制御は別の **HorizontalMotionEstimation** で局所XY速度を推定し、表示用の東・北移動距離とは別の経路を使います。[水平補助](horizontal_control.md)

## 通信形式と対応づけ

通常 **SFI8は190 byte**、指令補足 **SFIXは190 byte**、センサー補足 **SFIYは246 byte**、水平補足 **SFIHは182 byte**。同じSequence・Time・BuildIDで対応づけ、CRCを確認します。通常80列と補足161項目を別表で保存し、補足が届かない項目はNaNになります。補足表はヘッダー5列＋161項目の166列です。旧記録も読めます。

DataLogging50のTelemetryPacker50／RadioUSBTransport50は400 Hz内で負荷を分散し、指令補足を2.5 ms後、センサー補足を5 ms後、通常ログを10 ms後に送ります。Revision 1802の水平補足は15 ms後に作成、17.5 ms後に送信します。全フレームは同じ50 Hz時点の値を保存しており、到着時刻ではなくヘッダーの保存時刻・Sequenceで結合します。

Revision 1802以降はSFIY最後の予約バイトにESP32の起動理由を保存します。`imu.readExtendedTelemetry`の`ResetReason`で読み、旧版はNaNです。再起動を確認した自動記録は`info.RecordingStop.NewBoot.ResetReason`にも保存します。6はタスクウォッチドッグ、4は例外・パニック、9は電圧低下です。過去の未収録の理由を補完することはできません。

BuildID 1401はプログラムの識別子です。同じCHの同じプログラムを持つ複数機体を区別できないため、[専用CH](../README.md#自分専用のチャンネルをそろえる)を割り当てます。受信機のQueuedなどはキュー投入の指標で、電波到達は受信データで確認します。

補足の`TimingMaxExecUs`は計測範囲がタスク全体より狭い値です。全400 Hzタスクの時間はUSB診断の`SFTASK`で確認します。過去の取得レート・飛行・表示テストは[履歴](history/README.md)に保存しています。

USBの`SFRUNTIME`は起動理由、両CPUのidle経過時間、制御タスクの最小残りスタック（byte）、空きheap、実行core、idle-hook登録結果を1秒ごとに出します。診断を追加してもウォッチドッグ設定は変更していません。パケットCRCの成功と、2.5 ms内の処理完了・飛行成功は別の確認です。
