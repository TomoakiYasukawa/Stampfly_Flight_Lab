# セットアップとSimulink画面からの書き込み

現行機体は `StampFly_IMU400.slx`、ログ受信機は `M5Stamp_IMU_Rx.slx` です。[README](../README.md)の手順を、設定画面ごとに補足します。

## 機体と送信機の準備

機体の電源を外して、フレーム・モーター・配線とプロペラの位置を確認します。CW／CCWの位置を控えてからプロペラを外し、書き込みと机上確認はバッテリーも外してUSB給電で行います。

Windowsの **［デバイスマネージャー］→［ポート（COMとLPT）］** でUSBの抜き差しによる変化を確認し、機体・JoyStick・ログ受信機それぞれのCOMを控えます。プロジェクトに保存されたCOM番号は開発環境の例なので、自分の番号を選び直してください。

JoyStickの更新が必要な場合は[M5Stack公式ファームウェアガイド](https://docs.m5stack.com/en/guide/stampfly/firmware)に従います。

1. M5Burnerの **STAMPS3 → StampFly Controller Firmware** を選びます。JoyStick v1.1は対応するv1.2.0以降を選びます。
2. JoyStickをUSB接続し、側面のリセットボタンを緑のランプが点くまで押して、離します。
3. **［Burn］** でJoyStickのCOMを選んで書き込み、通常起動へ戻します。
4. 対応バッテリーを充電し、USBを外しても操作画面が表示されることを確認します。

## 専用CHとペアリング

利用場所の担当者と、他のシステムが使っていない **CH 1～13** を割り当てます。機体側の **JoystickCommand → BasicJoystick** と **DataLogging50 → RadioUSBTransport50** を開き、両方の **Channel** に同じ `uint8(CH番号)` を設定します。ソースコードを編集する必要はありません。

受信機の **ESPNowReceiverUSB → Channel** も同じ値にして、それぞれ再ビルド・書き込みします。アプリのCH変更は受信機の再起動まで有効です。毎回同じCHで起動させるには、受信機モデルの設定も保存して書き込んでください。

機体のCHを書き換えた後に、JoyStickを再ペアリングします。

1. プロペラを外し、近くのほかのStampFlyを停止します。
2. **中央液晶ボタンを押したままJoyStickの電源を入れます。**
3. 案内が出たら離し、画面の指示に従ってもう一度押します。
4. 自分のStampFlyをリセットしてペアリング信号を送らせます。
5. ペアリング完了と **Stabilize／Auto Altitude、Stick Mode 2** を確認します。

機体を水平に置いて校正を待ち、ゆっくり持ち上げてJoyStickのALTとアプリのToFが自分の動きに対応することを確認します。自分の機体を停止した後もログのフレーム数が増え続ける場合は、ほかの機体のデータを受信していないかCHを見直します。

## モデル設定

MATLABで **`StampFly_Official.prj`** を開き、機体モデルを開いて **Ctrl+D**。続いて **Ctrl+E（モデル設定）** を開きます。

| 設定画面 | 機体 | ログ受信機 |
|---|---|---|
| Solver → Type | Fixed-step | Fixed-step |
| Solver → Solver | discrete (no continuous states) | 同左 |
| Solver → Fixed-step size | `Official.Step`（0.0025 s） | 0.01 s |
| Hardware Implementation → Hardware board | ESP32-S3 Series (Arduino Compatible) | 同左 |
| Hardware board settings → Build options | Build | Build |
| Code Generation → System target file | `ert.tlc` | `ert.tlc` |
| Code Generation → Toolchain | ESP32 | ESP32 |
| Code Generation → Generate code only | オフ | オフ |

モデル内のToF呼び出しも **SampleTime = Official.Step** です。センサーの測定条件はドライバーでMedium・33 msに設定し、完成した値を非同期で受け取ります。IMUの推定周期やPIDの実測dtとは役割が異なります。

## ビルドと展開

まず **Build action = Build**、保存、**［アプリ］→［Embedded Coder］→［Cコード］→［ビルド］（Ctrl+B）** で実行形式を作ります。ビルドログに表示される出力先で `StampFly_IMU400.bin` の生成を確認してください。生成コードとキャッシュは通常`build/`へ保存されます。

書き込みは、機体のバッテリー・プロペラを外し、USB接続した状態で行います。

1. アプリやシリアルモニターが機体COMを使っていれば切断します。
2. **Ctrl+E → Hardware Implementation → Hardware board settings → Host-board connection → Application download** を開きます。
3. **Set host COM port = Manually Select → Refresh → Host COM port** で機体のCOMを選びます。まず **Baud rate = 921600(Default)** を使います。
4. **Build options → Build action = Build, load and run →［適用］→［OK］**。
5. **［ハードウェア］→［ビルド、展開、起動］（Build, Deploy & Start）** を押します。タブがなければ **［アプリ］→［ハードウェアボード］** を開きます。
6. 完了後は通常起動し、水平に静置して校正を待ちます。**Build actionをBuildへ戻して保存** します。

接続待ちになった場合は、USBを外し、機体StampS3の中央ボタンを押しながらUSBを接続してダウンロードモードにします。ボタンを離し、変化したCOMを選び直します。受信機もBOOTボタンで同様に接続できます。

受信機をビルド・展開するときは、モデル・COMともに受信機へ切り替えます。JoyStickには公式送信機ファームウェアを使います。

## エラーを確認する

| 表示・症状 | 確認箇所 |
|---|---|
| `Official`／`IMUFlight`が未定義 | プロジェクトを開き、現行モデルでCtrl+D。初期化が失敗したら診断ビューアーの最初のエラーを確認 |
| IMU Filter／`imufilter`が見つからない・ライセンスエラー | Navigation Toolboxのインストールと利用可能なライセンス |
| ボード・ESP32ツールが見つからない | Arduinoサポートパッケージのハードウェアセットアップ |
| COMへ接続できない | USBケーブル、対象COM、ほかのアプリによるポート使用、ダウンロードモード |
| ログが来ない | 機体の2か所と受信機・アプリのCH、機体の通常起動 |
| 下向き距離が無効 | 床・距離・遮蔽物、BottomRangeStatus、Fresh、初期化診断 |

モデルやドライバーを変更した後は、モデル更新とビルドを行い、机上確認から進めます。製品の取り扱い・バッテリー充電はM5Stackの案内に従ってください。
