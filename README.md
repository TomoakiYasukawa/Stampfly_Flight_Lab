# StampFly_Lab

M5Stack StampFlyをSimulinkで制御し、センサー・制御量をDataLoggerで記録するプロジェクトです。操縦にはM5StackのJoyStickを使います。このREADMEは、初めてこのプロジェクトで機体を飛ばす人向けの手順です。

| ファイル | 用途 |
|---|---|
| [StampFly_Lab.prj](StampFly_Lab.prj) | MATLABプロジェクト。最初に開くファイル |
| [Stampfly_Tx.slx](Stampfly_Tx.slx) | StampFly機体に書き込む400 Hz制御・テレメトリー送信モデル |
| [M5Stamp_Rx.slx](M5Stamp_Rx.slx) | PCへログを渡すM5StampS3受信機のモデル |
| [DataLogger.m](DataLogger.m)／[DataLogger.xml](DataLogger.xml) | モニター、制御パラメータ編集、記録・履歴表示アプリ |
| [DataLogger_GUIDE.md](DataLogger_GUIDE.md) | アプリの詳しい操作説明 |

`Tx`は機体のログ送信側、`Rx`はログ受信側です。JoyStickの送信機ファームウェアはM5Stack公式版を使います。

## 1. 必要なもの

- StampFly、対応バッテリー、JoyStick、データ通信可能なUSBケーブル。
- 無線で飛行ログを取る場合は、ログ受信機用のM5StampS3。机上では機体USBへ直接接続して観測できます。
- MATLAB、Simulink、Stateflow、Simulink Coder、Embedded Coder、Navigation Toolbox。
- Simulink Support Package for Arduino Hardware。ハードウェアセットアップまで実施してください。

確認環境は **Windows／MATLAB R2026b／Arduinoサポートパッケージ26.2.3** です。DataLoggerの`.m`＋`.xml`形式にはR2026bが必要です。Parallel Computing Toolboxはアプリの保存・履歴読込を別プロセスで処理するための任意製品で、利用できない環境でも動きます。[製品と同梱コードの詳細](docs/dependencies.md)

フォルダ **`stampfly_lab`** 全体を取得してください。モデルだけを取り出すと独自ブロック・ドライバーが不足します。プロジェクト内に必要な独自コードを含み、他の個人用プロジェクトへのパスは不要です。

## 2. プロジェクトを開く

MATLABで`stampfly_lab/StampFly_Lab.prj`を開きます。プロジェクトのスタートアップが検索パスを設定し、生成物の保存先を`build/`へ揃えます。

プロジェクトのショートカットから機体モデル、受信モデル、DataLogger、操作説明を開けます。コマンドで起動する場合はプロジェクトを開いてから次を実行します。

```matlab
open_system('Stampfly_Tx.slx');
app = run_datalogger();
```

`archive/`全体を検索パスへ追加しないでください。過去版は必要なときにファイルを指定して開きます。

## 3. USBと専用チャンネルを準備する

書き込みと最初の机上確認は、**機体のバッテリーとプロペラを外して**USB給電で行います。CW／CCWの位置を控え、フレーム・配線・モーターを確認してください。

WindowsのデバイスマネージャーでUSBの抜き差しを確認し、**機体、JoyStick、ログ受信機それぞれのCOM**を控えます。モデルに保存されたCOMは開発環境の値なので、自分の番号へ変更します。

同じ場所で使う人と相談し、1システムに1つの未使用CHを割り当てて機体・受信機へラベルを付けます。範囲は **1～13**、保存済み初期値は **3** です。下の3か所を同じ値にしてください。

| モデルとブロック | 設定 |
|---|---|
| `Stampfly_Tx` → JoystickCommand → BasicJoystick | Channel = `uint8(自分のCH)` |
| `Stampfly_Tx` → DataLogging50 → RadioUSBTransport50 | 同じChannel |
| `M5Stamp_Rx` → ESPNowReceiverUSB | 同じChannel |

機体の2か所と受信機の設定を保存し、それぞれビルド・書き込みします。マスクの中は右クリック **［マスク］→［マスク内を表示］** から開けます。アプリのCH設定はUSB接続した受信機へ送る設定です。機体のCHを変えたらJoyStickを再ペアリングします。

**BuildIDは機体固有のIDではありません。** CHを合わせ、自分の機体を動かしたときにだけ値が対応することを確認します。

## 4. モデルをビルド・書き込みする

まず`Stampfly_Tx.slx`を開きます。

1. **Ctrl+E → Hardware Implementation**で **ESP32-S3 Series (Arduino Compatible)** を選びます。
2. Solverは **Fixed-step／discrete、0.0025 s**、Code GenerationのSystem target fileは **`ert.tlc`** を確認します。
3. **Hardware board settings → Build options → Build action = Build**にして保存し、**Ctrl+D**でモデルを更新します。
4. **Ctrl+B**、またはEmbedded Coderのビルド操作を実行します。診断ビューアーの成功を確認します。
5. アプリなどが機体COMを使用中なら切断します。**Host-board connection → Application download**で機体のCOMを選びます。
6. **Build action = Build, load and run**へ切り替え、**［ハードウェア］→［ビルド、展開、起動］**を実行します。
7. 通常起動へ戻し、水平に静置して校正を待ちます。次のビルド用に**Build actionをBuildへ戻して保存**します。

受信機は`M5Stamp_Rx.slx`、離散ステップ **0.01 s**、**受信機自身のCOM**で同様に書き込みます。Simulinkの **［実行］**はPC上のシミュレーションです。実機への書き込みにはビルド・展開操作を使います。

接続待ちになる場合は、機体StampS3の中央ボタンを押しながらUSBを接続してダウンロードモードに入り、変化したCOMを選び直します。[設定画面・USB・エラー対処の詳細](docs/setup.md)

開発者用のビルド関数`build_stampfly_lab()`は両モデルを**ビルドのみ**実行し、`firmware/current/`にBINとSHA-256付きmanifestを保存します。GUIからの書き込みと使い分けてください。

## 5. JoyStickを用意してペアリングする

[M5Stack公式ファームウェアガイド](https://docs.m5stack.com/en/guide/stampfly/firmware)に従い、JoyStickに **StampFly Controller Firmware**を入れます。JoyStick v1.1は対応版のv1.2.0以降を使います。

プロペラを外した状態で、**中央液晶ボタンを押しながらJoyStickの電源を入れ**、画面の指示に従ってペアリングします。自分のStampFlyを再起動して登録し、**Stabilize／Auto Altitude、Stick Mode 2**を確認します。ペアリング中は近くのほかの機体を停止します。

水平静置で校正した後、ゆっくり持ち上げてJoyStickのALTやDataLoggerのToFが自分の動きへ対応することを確認します。

## 6. DataLoggerで通信・記録を確認する

1. プロジェクトの**DataLogger**ショートカット、または`run_datalogger()`で起動します。
2. モニターで**ログ受信機のCOM、921600 baud、自分のCH**を選びます。
3. **［接続］→［CHを設定］**を押し、応答と増え続けるフレーム数を確認します。機体USBへ直接つなぐ机上確認ではCH設定を使いません。
4. 通常は自動記録です。飛行制御（Mode 2）または着陸（Mode 5）で開始し、直前2秒と待機復帰後1秒を含めてMATへ保存します。
5. **［履歴・飛行］→［保存先を指定］**で保存・表示するフォルダを選びます。初期値はプロジェクトの`recordings/`です。机上記録には **［手動記録開始］／［記録停止］**を使います。

保存・読込・プール起動に時間がかかる場合は作業ウィンドウを表示します。終了操作では保存完了を待ちます。履歴は最大6件の比較、範囲切替、選択MATの削除に対応します。詳しい操作とグラフの読み方は **[DataLogger_GUIDE.md](DataLogger_GUIDE.md)** を参照してください。

制御パラメータタブは、**PCのモデルにある7 PIDと水平P／PI**を読み書きします。リアルタイム受信中も再読込できます。機体へ係数を反映するには **モデル保存 → 更新 → 再ビルド → 書き込み**が必要です。[係数の意味と変更方法](docs/control_parameters.md)

## 7. 最初の飛行

机上確認が終わったら電源を外し、正しい位置へプロペラを戻します。人・物へ接触しない空間、平らで模様のある床、十分な照明を用意してください。機体USBを外し、充電したバッテリーで起動して水平静置の校正を待ちます。

最初は **Stabilize／Auto Altitude**で、離陸 → 短いホバリング → 着陸 → ログ確認を行います。初期高度目標は **0.5 m**です。

| Stick Mode 2の操作 | ボタン・スティック |
|---|---|
| 離陸／着陸 | **中央液晶ボタンを押して離す** |
| 高度目標 | 左スティック上下 |
| 機首方向（Yaw） | 左スティック左右 |
| 前後（Pitch） | 右スティック上下 |
| 左右（Roll） | 右スティック左右 |
| Stabilize／Sport | 左前面ボタン |
| Auto／Manual Altitude | 右前面ボタン |

飛行中に中央液晶ボタンを再度押して離すと着陸へ移ります。**中央ボタンは押した瞬間の緊急停止ボタンではありません。** 宙返り操作は使いません。停止を確認してからバッテリーを外してください。

水平補助は、Stabilize／Auto Altitudeで高さ0.20 m以上、正常な観測、スティック中立が0.5秒続くと有効になります。右スティックは機首基準の速度指令となり、離すと減速して**新しい停止位置**を保持します。初期速度上限は0.3 m/sです。フロー・ToFが無効な場合は従来の傾き操縦へ移り、正常な測定と中立が1秒続いてから復帰します。[動作条件と調整](docs/horizontal_control.md)

履歴の0秒は **Mode 2開始**で、離陸完了時刻ではありません。鉛直速度は上昇が＋です。Optical FlowのXYは相対位置で、磁気による絶対方位校正は未実装です。

Revision 1804ではユーザーから安定飛行の報告を得ています。今回の名称・フォルダ整理では制御内容を維持しています。過去の飛行結果、USB診断、今回のビルド・確認は[履歴の要約](docs/history/README.md)で区別できます。

## 開発するときに読むもの

- [docs/README.md](docs/README.md)：現行の説明を目的別に案内。
- [モデル構造](docs/imu_flight_model.md)、[CPUと周期](docs/cpu_tasks.md)、[ログ形式](docs/logging_extensions.md)。
- [開発・検証手順](docs/development.md)：試験、MEX、生成物、過去資料の開き方。
- **[AI_CONTEXT.md](AI_CONTEXT.md)**：agentic AI向けの技術的引き継ぎ。これまで判明した制御・軸・通信・性能・実機検証の注意点を記載。入口は[AGENTS.md](AGENTS.md)。

| フォルダ | 内容 |
|---|---|
| `config/` | ルート解決、起動、生成物・記録集の参照 |
| `code/`、`src/` | MATLABブロック・ロガー処理、C／C++実機ドライバー |
| `libraries/` | 教材ブロックライブラリー |
| `tests/`、`scripts/`、`tools/` | 再利用できる試験・解析・ビルド・USB補助 |
| `resources/` | プロジェクト設定と3D機体メッシュ |
| `third_party/`、`official_sources/` | 実機依存コード、公式比較ソースとライセンス |
| `firmware/` | 最新ビルドと、復元・調査に必要な保存版 |
| `docs/history/`、`archive/` | 履歴の要約、検索用索引、原文記録集、比較モデル |
| `build/` | 再生成できるコード・キャッシュ・MEX・試験結果 |
| `recordings/`、`logs/`、`backups/` | ローカルの記録と実機復元用バックアップ |

通常の飛行・アプリ利用に配布済みMEXは必要ありません。比較試験ではC++ソースから`build/tests/mex/`へ生成します。第三者コードの条件は[THIRD_PARTY_NOTICES.md](docs/THIRD_PARTY_NOTICES.md)と各LICENSEを参照してください。
