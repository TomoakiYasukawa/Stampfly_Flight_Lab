# StampFly 公式制御の Simulink 移植

## 現在の機体

StampFly COM4 / MAC `70:AF:09:DF:A6:C4` には、`StampFly_Official_Bench400` の生成ファームを保存済みです。**実モーター出力は常にゼロです。バッテリーを付けても飛びません。** 公式バイナリと変更前バックアップは残してあります。JoyStick の公式ファームは変更していません。

## 開き方

MATLAB の現在のフォルダーをこのプロジェクトにして実行します。

```matlab
init_official
open_system('StampFly_Official_Bench400')
app = run_stampfly_imu_app;
```

ロガーは COM4 の USB ストリーム、または既存受信機 COM9 の ESP-NOW ストリームを使用できます。921600 baud、無線 CH3。COM4 の直接ログ取得は確認済み、COM9 の無線ログ経路と JoyStick の通信は今回まだ実機確認していません。アプリでポートを選び、接続・記録ボタンを使います。コピー元の飛行指令と PI 調整ボタンは無効です。

| モデル | 用途 |
|---|---|
| `models/StampFly_Official_Bench400.slx` | USB 検証・400 Hz 制御・センサー・PWM・50 Hz ロガー |
| `models/StampFly_PWM400_Probe.slx` | タイマー・BMI270・4ch PWM の最小検証 |
| `models/StampFly_Official_Replay400.slx` | 独立した公式 C++ 比較入力を 400 Hz で再生 |
| `models/StampFly_Official_FlightSim400.slx` | 校正→アーミング→離陸→0.5 m の入力による制御確認 |
| `models/M5Stamp_IMU_Rx.slx` | コピーした既存ログ受信機 |

`FlightSim400` はセンサー入力の既知波形を使用します。空力・モーター・機体運動を含む閉ループプラントではありません。高度の上昇波形を与えた制御再生です。

## 制御を読む順序

`OfficialTakeoffHover400` サブシステムを開くと、以下の 3 ブロックと状態保持・リセットの配線があります。アルゴリズムは MATLAB System ブロックの MATLAB コードから C に生成します。

1. `MadgwickAltitudeKalman400` → `+official/sensorStep.m`。加速度／角速度の軸変換、800サンプルの平均オフセット、各一次フィルター、Madgwick、距離の保持／外れ値処理、高度 Kalman、OverG／距離／低電圧フラグ。
2. `CalibrationArmSupervisor400` → `+official/supervisorStep.m`。INIT=0、AVERAGE=1、FLIGHT=2、PARKING=3、LANDING=5。押下と解放のチャタリング判定を保持します。
3. `TakeoffPIDMixer400` → `+official/controllerStep.m`。離陸カウンター、電圧による基準推力、高度 PID→鉛直速度 PID、姿勢角 PID→角速度 PID、モーター配分、一次フィルター、Duty 制限、8 bit整数化。

センサーは前の tick のモードと高度制御フラグを使います。公式の制御後リセットを Unit Delay で保持し、次のセンサー処理前に反映します。分割前の統合 MATLAB 実装との3,200 tick比較で Duty の差は0でした。

## 離陸からホバリング

Auto Altitude では高度指令を0.5 mに初期化し、カウンターを tick ごとに増やします。0〜499では基準Dutyを `counter/1000` と3.8 Vのトリム値で制限。500〜999では実電圧のトリム値で制限し、1000以降は電圧トリム値です。`trim(V)=-0.2448*V+1.5892`。

共通推力が公称3.7 Vに対してDuty0.1未満の間は PID とモーター出力をリセットします。以降は高度誤差から目標鉛直速度、速度誤差から共通推力補正を求めます。補正推力は基準Dutyの0.85〜1.15倍で制限します。

| PID | Kp | Ti | Td | Eta |
|---|---:|---:|---:|---:|
| 高度 | 0.38 | 10 | 0.5 | 0.125 |
| 鉛直速度 | 0.08 | 0.95 | 0.08 | 0.125 |
| Roll / Pitch角 | 5 | 4 | 0.04 | 0.125 |
| Roll角速度 | 0.65 | 0.7 | 0.01 | 0.125 |
| Pitch角速度 | 0.95 | 0.7 | 0.025 | 0.125 |
| Yaw角速度 | 3 | 0.8 | 0.01 | 0.125 |

ここで Ti と Td は公式 PID の時間定数です。一般的な並列 PID の Ki/Kd をそのまま入れる実装ではありません。`pidStep.m` は公式の台形積分・微分フィルターの漸化式を移しています。

Roll/Pitch 指令は±30°、高度指令は0.05〜1.8 m、最終Dutyは0〜0.95。モーターの順序は FR / FL / RR / RL、ピン42 / 5 / 41 / 10。8 bit値は `floor(255*Duty)`、最大242です。

## 400 Hz と150 kHz PWM

`TickStart400` は GPTimer を1 MHzに設定し、2500 µsごとにベースレートタスクを起こします。MathWorksの `Timer1` の生成・開始・停止・削除だけをローカルのリンカーラッパーで置換します。インストール済みサポートパッケージは変更していません。標準FreeRTOSタイマーの2.5 ms→2 tickへの丸めを回避します。

`PWM150kHz8bit` は起動時に LEDC のtimer0/ch0〜3を設定し、各tickでは固定4回のレジスタ更新を行います。`AllowMotorOutput=false` と入力の `MotorOutputDisabled=false` の両方で、生成コードのenable引数を0にしています。PWMタイマーをブザー／他のArduino PWMと共有しないでください。

ESP32-S3向けXtensaコンパイラーでビルドしています。コピー元のサポートパッケージはハードウェア型名にARM Cortexを使用していますが、確認した基本幅はchar8、short16、int/long/pointer32、float32、double/long long64、LittleEndianです。コンパイラーはARMではありません。

## 400 Hzを維持するための公式との差

- BMI270のODR400 Hz、±8g、±2000°/s、公式の通常フィルターは保持。APS省電力を無効化して、Bosch APIの各通信後450 µs待ちを2 µsに変更しました。
- 下向きToFのULD通信はcore0のタスクで処理。400 Hz側は `dcnt>14` と割り込みフラグで要求し、完成済みの最新距離を使用します。公式の同期呼出しに比べ、通信完了後のtickで入力が更新されます。実測取得は約25 Hzでした。
- 前向きToFは設定済みですが待機させています。公式のPARKING中の読み出しで未開始センサーを再開するとアドレスが変わり、NACKを反復したためです。離陸・高度保持には使われません。
- 電池電圧は各tickで読み出しを試みます。ToFが同じI2Cバスを使用中なら待たず、直前値を保持し、ReadValidを0にします。
- USBロガーは50 Hzで190 byte SFI8フレームをキュー投入、別タスクで送信します。公式JoyStickへは40 Hzで120 byteの公式テレメトリを返します。
- Optical Flow、宙返り、前向き障害物制御は未実装です。水平位置保持を追加したとは扱いません。
- 公式のAzをgのままKalmanへ入れる処理、Madgwickの軸とYaw180°オフセット、Kalman resetで内部推定値を保持する挙動を保存しました。ロガー表示用Quaternionだけは制御の姿勢角から作っています。

## 確認した結果と限界

| 検証 | 結果 |
|---|---|
| 公式C++制御との4,000 tick比較 | Duty差0、主要状態差0 |
| Simulink Replay400 | 4,000 tick、Duty差0 |
| 推定器2,400 tick比較 | 姿勢最大差4.7684e-7 rad、Kalman差0 |
| FlightSim400 | 校正→PARKING→FLIGHT、counter1000、高度指令0.5 m |
| 分割モデルと統合MATLAB実装 | 3,200 tick、Duty差0 |
| 最終USB実機ログ約12秒 | 4,800 tick、missed0、処理超過0、NACK0 |
| 同ログの処理時間 | 平均874〜880 µs、最大2304 µs |
| タスク開始間隔 | 最大2705 µs。タイマー周期2500 µs、開始時刻に揺れあり |
| PWM読み戻し | 150094 Hz / 8 bit、4ch書込み6〜7 µs、実出力0 |
| MATロガー | 601フレーム、50 Hz、欠落0、CRCエラー0 |

150000 Hzの指定に対する150094 HzはLEDCクロック分周の量子化による約0.063%の差です。外部計測器によるキャリア波形は未測定です。周期の保証や飛行性能の検証ではなく、このUSB・静置条件の測定結果です。

JoyStick COM6のUSB接続は確認しました。通信の実機確認と、高さを変えた実機ToF確認は確認結果を別途記録します。バッテリーなしの実測電圧を使うため、実機で離陸制御を入力した結果を飛行検証として扱えません。離陸〜ホバリングの数値比較は保存した入力トレースで確認しています。着陸・Manual/Sport切替・通信喪失遷移の全条件はまだ独立比較していません。

ログ: `logs/bench400_split_COM4.bin`。比較結果: `tests/controller_comparison.mat`、`tests/estimator_comparison.mat`、`tests/simulink_replay.mat`、`tests/flight_split_comparison.mat`。保存MATのパスは `tests/bench400_summary.mat` にあります。

ソースのMIT・Madgwick GPL・Bosch/STの扱いは `THIRD_PARTY_NOTICES.md` を参照してください。
