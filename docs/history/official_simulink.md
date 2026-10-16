# StampFly 公式制御の Simulink 移植

## 現在の書き込み状態

StampFly（書き込み時 COM4、MAC `70:AF:09:DF:A6:C4`）には `StampFly_Official_FlightTest400.bin` を書き込み済みです。**飛行試験版はモーター出力が有効**です。待機中の出力ゼロを実機ログで確認しました。モーター無効の `StampFly_Official_Bench400.bin`、公式配布バイナリ、変更前バックアップも保存しています。JoyStick の公式ファームウェアは維持しています。

下向きToFと高度推定、JoyStickの離陸指令、COM9の無線ロガーを確認しました。新ファームウェアでの実飛行結果はまだ取得していません。最新状況は [現在の状態](current_flight_status.md)、実際に書き込んだバイナリのSHA-256と試験記録は [書き込み記録](flight_test_deployment.json) にあります。

## モデルを開く

MATLAB の現在のフォルダーをこのプロジェクトにして実行します。

```matlab
init_official
open_system('StampFly_Official_FlightTest400')
open_system('StampFly_StudentBlocks')
```

ロガーアプリは `run_stampfly_imu_app` で開きます。既に `officialLoggerApp` が COM9 へ接続している場合は、そのアプリを継続して使ってください。同じポートに別の受信処理を接続しません。921600 baud、無線CH3です。飛行中はCOM9の受信機を使い、機体のUSBを外します。コピー元アプリの飛行指令・PI調整UIはこの公式制御モデルでは使いません。

| モデル | 用途 |
|---|---|
| `StampFly_Official_FlightTest400.slx` | モーター有効の飛行試験版 |
| `StampFly_Official_Bench400.slx` | モーター無効のUSB検証版 |
| `StampFly_StudentBlocks.slx` | センサー・推定・状態管理・PID・PWM・記録の再利用ライブラリ |
| `StampFly_PWM400_Probe.slx` | タイマー・BMI270・4ch PWMの最小検証 |
| `StampFly_Official_FullReplay400.slx` | 公式C++と状態遷移・Manual／Sport・Flipを比較する再生モデル |
| `StampFly_Official_FlightSim400.slx` | 離陸を模した既知のセンサー入力で制御を再生するモデル |
| `M5Stamp_IMU_Rx.slx` | コピーした既存無線ログ受信機 |

モデルは `models/` にあります。`FlightSim400` は空力・モーター・機体運動を含む閉ループシミュレーションではありません。与えた高度上昇波形に対する制御再生です。

## 学生が編集するブロック

トップレベルには、センサー入力、姿勢・高度と飛行制御、モーター出力、データロガー、JoyStickへの返信、LED／ブザー、観測バスを配置しています。機能別のサブシステムと日本語の説明を開いて読み進められます。

1. `SensorInputs400`：BMI270、下向きToF、電池電圧、JoyStickを個別の取得ブロックで読みます。低レベルの通信はC++ドライバーが担当します。
2. `OfficialTakeoffHover400` のセンサー処理：軸変換、800点校正、フィルター、Madgwick、鉛直加速度、ToF保持・外れ値処理、高度Kalman、センサーフラグを個別に配置しています。
3. 状態管理：Stateflowの飛行状態管理とFlipシーケンスが、校正・待機・離陸・飛行・着陸の遷移を決めます。
4. 制御：高度PID→鉛直速度PID、姿勢角PID→角速度PID、指令生成、推力制限、モーター配分を分離しています。7個のPIDはSum／Gain／Product／Unit Delayなどの標準ブロックで構成されています。
5. `MotorOutput400`：FR／FL／RR／RLの4指令を、PWM150 kHz指定・8 bitへ書き込みます。
6. 記録・通信・表示：50 Hzロガー、40 Hz公式JoyStickテレメトリ、LED／ブザーを独立して配置しています。

ライブラリの棚には、これらの単体ブロックと、配線済みのサブシステムをコピーしています。新しいモデルではサンプル時間、入力の型・次元、リセット信号の接続を維持してください。MATLAB Function／Stateflowブロックのアルゴリズムもモデル内にあります。`model_algorithms/` はその生成用ソース、`+official/*Step.m` は比較・参照用のMATLAB実装です。実行時にPCから制御値を送る構成ではありません。

センサー処理は前のtickのモード・高度制御・Flipフラグを使います。公式の制御後リセットをUnit Delayで保持し、次のセンサー処理前に反映します。これらの遅延を移動すると公式との更新順序が変わります。

## 離陸から高度保持

Auto Altitudeでは高度指令を0.5 mに初期化し、カウンターをtickごとに増やします。0〜499は基準Dutyを `counter/1000` と3.8 Vのトリム値で制限します。500〜999は実電圧のトリム値で制限し、1000以降は電圧トリム値を使います。トリム式は `trim(V)=-0.2448*V+1.5892` です。1000 tickは公称2.5秒ですが、その時点で離陸や高度収束を保証する値ではありません。

共通推力が公称3.7 V換算のDuty0.1未満の間は、PIDとモーター出力をリセットします。その後、高度誤差から目標鉛直速度、速度誤差から共通推力補正を求めます。補正推力は基準Dutyの0.85〜1.15倍で制限します。姿勢角PID→角速度PIDで求めた補正を4モーターへ配分します。

| PID | Kp | Ti | Td | Eta |
|---|---:|---:|---:|---:|
| 高度 | 0.38 | 10 | 0.5 | 0.125 |
| 鉛直速度 | 0.08 | 0.95 | 0.08 | 0.125 |
| Roll／Pitch角 | 5 | 4 | 0.04 | 0.125 |
| Roll角速度 | 0.65 | 0.7 | 0.01 | 0.125 |
| Pitch角速度 | 0.95 | 0.7 | 0.025 | 0.125 |
| Yaw角速度 | 3 | 0.8 | 0.01 | 0.125 |

TiとTdは公式PIDの時間定数です。台形積分と微分フィルターを含む漸化式を移植しています。並列PIDのKi／Kdへそのまま入力する値ではありません。

Roll／Pitch指令は±30°、高度指令は0.05〜1.8 m、最終Dutyは0〜0.95です。モーター順序はFR／FL／RR／RL、ピン42／5／41／10、8 bit指令は `floor(255*Duty)` で最大242です。

FLIGHT中の中央ボタンでLANDINGへ移り、鉛直速度指令を−0.15 m/sにします。推定高度0.1 m未満、またはLANDING中の追加ボタン操作でPARKINGへ戻ります。押下・解放のチャタリング判定があるため、追加ボタンも瞬時停止ではありません。通信喪失時の着陸遷移、OverG、Manual／Sport、Flipもモデルで再現しています。初回試験はStabilize／Auto Altitudeを使います。

Optical Flowは未実装です。中立の右スティックで水平姿勢を目指しますが、水平位置保持はありません。ヨー指令は角速度で、絶対方位の保持ではありません。

## 400 HzとPWM

`TickStart400` は1 MHz GPTimerを2500 µs周期で動かし、生成コードのベースレートタスクを起こします。サポートパッケージのTimer1の生成・開始・停止・削除を、ローカルのリンカーラッパーで置換しています。インストール済みパッケージは変更していません。FreeRTOSソフトウェアタイマーの2.5 msから整数tickへの丸めを回避しています。

`official.MotorPWM400` は起動時にLEDC timer0／ch0〜3を設定し、400 Hzで4chのレジスタを更新します。ベンチ版は定数Enable=falseとAllowMotorOutput=falseで出力ゼロ、飛行試験版は両方trueです。PWMタイマーはブザーや別のArduino PWMと共有しません。

PWM読み戻しは150094 Hz／8 bitです。150000 Hz指定に対する約0.063%の差は分周の量子化によります。外部計測器でキャリア波形は未測定です。タイマー周期が2500 µsでも、タスク開始時刻には揺れがあります。`SFTASK` は生成step全体、`SFTIMING` は一部区間を計測します。

XtensaコンパイラーでESP32-S3向けにビルドしています。サポートパッケージのハードウェア型名にARM Cortexを使用していますが、確認した幅はchar8、short16、int／long／pointer32、float32、double／long long64、LittleEndianです。

## センサー周期と低レベル処理の差

| 項目 | 現在の実装 |
|---|---|
| BMI270ジャイロ／加速度 | ODR400 Hz、取得・フィルター400 Hz、±2000°/s／±8g |
| Madgwick | 400 Hz更新、公式の軸・Yaw180°オフセットを保持 |
| 下向きToF | Medium、33000 µs予算、readyとdcnt>14、実測約25 Hz |
| 高度Kalman | 最新保持距離と鉛直加速度で400 Hz更新 |
| 電池電圧 | core0がI2C取得、400 Hz側は最新キャッシュを読む |
| 前向きToF | XSHUT GPIO9=LOWで無効 |
| Optical Flow | 未実装 |

BMI270はAPS省電力を無効にし、Bosch APIの通信後待ち時間を450 µsから2 µsへ変更しています。下向きToFはcore0でI2C処理を行い、主タスクは待たずに完成済み結果を使います。公式の同期処理に比べ、通信完了後のtickで値が更新されます。起動時にStartMeasurementを重複させたことで起きていたULDストリーム同期エラー−20を修正しました。

電池は最新の読み出しが成功し、100 ms以内なら有効です。失敗時も最後の数値は保持します。JoyStickは正常な25 byte指令だけが飛行通信監視を更新します。宛先、ペアリング相手、有限の数値、加算チェックサムを確認し、ロガーの別パケットは飛行リンクを更新しません。

公式のAzをgのままKalmanへ入れる処理、Kalman resetで内部推定値を保持する挙動も保存しています。ログ表示用Quaternionは制御の姿勢角から作ります。単位を変える改良は公式との一致を確認してから別の変更として扱います。

## ロガー

`stampfly_imu_monitor` からSFI8パケット、無線受信、MAT保存アプリをコピーしています。400 Hz信号を50 Hzで記録し、USB送信は別タスクへキュー投入します。公式JoyStickへは40 Hzで120 byteテレメトリを返します。

ToFValidは距離>0かつstatus=0です。50 Hzロガーの前回観測から完了カウントが変わった場合にToFFreshを立てます。無効距離の数値もrawデータと状態に残し、アプリのグラフでは無効値をNaNにします。Optical FlowはNaN／無効フラグです。

**現行のMotorValidは0固定です。** アプリのMotorCommandsがNaNでも、飛行試験版のモーターが無効という意味ではありません。rawFramesの105〜108 byteに残る値は計算Dutyの整数化結果で、実際の適用値ではありません。適用値はUSB診断のappliedで確認しています。

## 検証結果と限界

| 検証 | 結果 |
|---|---|
| 公式C++との全シーケンス比較9000 tick | Duty最大差1.7881e−7、状態／高度モード／Flip／分岐の不一致0 |
| 中断・通信喪失・OverG・Manual／Sportなど5ケース×4500 tick | 全ケース合格、Duty最大差約2.4e−7 |
| 組み込み推定器2400 tick | 姿勢最大差4.7684e−7 rad、高度Kalman差0 |
| ロガー7形式とCRC | 比較合格 |
| 下向きToF持ち上げ試験10秒 | 0.305〜0.345 m、status0、エラー0、高度推定へ反映 |
| 同試験のMATログ | 500フレーム、50 Hz、欠落0、CRC0 |
| core0電池取得後のベンチ30秒 | 全タスク最大1988 µs、超過0、取りこぼし0 |
| 飛行用書き込み後のUSB静置6秒 | 全タスク最大2053 µs、超過0、取りこぼし0、待機中実出力0 |
| PWM読み戻し | 150094 Hz／8 bit |
| 実装C++の無線回帰試験 | 正常指令・不正チェックサム・相手違い・ロガー隔離・通信喪失・復帰が合格 |

保存入力に対する数値一致とUSB静置条件での測定結果です。飛行の安定性、バッテリー駆動・モーター負荷時の最大処理時間、水平位置保持を保証する結果ではありません。新ファームウェアの実飛行ログは初回試験で取得します。

`verify_official_models` は数値比較・再生・ロガー試験を行います。`build_official_bench` はモーター無効版をビルド、`prepare_official_flight_test(true)` は最新ベンチから飛行試験版を作りビルドします。いずれも書き込みは行いません。モデル編集には復旧済みのmodel_read／model_editを使用します。

ソースのMIT、Madgwick GPL、Bosch／STの通知は [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)、ツール復旧は [toolkit_recovery.md](toolkit_recovery.md) を参照してください。
