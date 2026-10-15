# 飛行制御の整理とPIDの比較（2026-10-15）

`StampFly_Official_FlightTest400/FlightControl400` と、その中の `TakeoffHoverControl400` を整理しました。制御の演算・単精度・状態・1周期遅延・保持・リセットは維持し、関連信号をバスにまとめています。専用PIDブロックへの直接置き換えは等価にならなかったため、本番のPIDは既存のSimulinkブロック構成を残しました。

整理後の保存モデルを ESP32-S3 用にビルドし、2026-10-15 に USB 接続・バッテリーなしの COM4 の機体へ再書き込みしました。独立した照合も成功しています。記録は [control_layout_flight_deployment.json](control_layout_flight_deployment.json) です。

## ブロックの読み方

主な流れは「推定値と操縦入力 → 飛行モード → 高度・姿勢・角速度の制御 → 4モーターの指令」です。主制御の配線は直接接続し、名前付きバスで束ねています。ロガー・LED・JoyStickの補助経路は従来どおりです。

| ブロック | 役割 |
|---|---|
| `OfficialFlightSupervisor` | 待機、校正、飛行、着陸、通信断などをStateflowの状態・遷移で扱う |
| `OfficialFlipSequence` | Flipのフェーズと専用指令を作る |
| `TakeoffHoverControl400` | 下表の機能別ブロックをつなぎ、モーター指令を作る |
| `PreviousCycle400` | 元のUnit Delayと型変換を保持し、前周期のモード・リセットなどを戻す |

`TakeoffHoverControl400` の入力は4本、出力は2本です。内部の機能ブロックも入力・出力をそれぞれ4本以下にまとめました。Stateflow Chartの個別信号は内部に保持しています。

| 内部ブロック | 役割 |
|---|---|
| `FlightCommand400` | 離陸・高度目標・着陸の指令、モード確定、PIDの実行・リセット条件を作る |
| `AltitudeControl400` | 高度PID → 鉛直速度PID → 共通推力 |
| `AttitudeControl400` | 操縦入力と姿勢角から角速度の指令を作る |
| `BodyRateControl400` | ロール・ピッチ・ヨーの角速度PIDから3軸のトルクを作る |
| `MotorAllocation400` | 共通推力と3軸トルクを4モーターへ配分し、補正・制限・8 bit変換する |
| `FlightDiagnostics400` | ロガー用の診断値を元と同じ順序でまとめる |

バスの主な内容は次のとおりです。フィールド名はBus Selectorを開くと確認できます。

| バス | 内容 |
|---|---|
| `PilotInput` | `Sticks`, `BatteryVoltage`, `RangeFlag`, `OverG` |
| `MeasuredState` | `Angles`, `AngularRate`, `Altitude`, `Velocity` |
| `FlightContext` | `Branch`, `PreMode`, `FlipPhase`, `FlipThrust`, `FlipRate`, `FlipStart`, `FlipDone`, `FlipAngleReset` |
| `FlightCommand` | `HeightReference`, `BaseThrust`, `RampCounter`, `RawThrust`, `AltitudeEnabled`, `ManualAltitude`, `ControlMode` |
| `SharedControlContext` | 実行・リセット条件、飛行状態、操縦入力、確定モード、実測Dt、前回誤差、推力要求、姿勢モード |
| `MotorCommand` | `Duty`, `Counts` |
| `ControlStatus` | `Diagnostics`, `AltitudeEnabled`, `FlipPhase`, `Reset`, `RateReference`, `Mode` |

4個のStateflow Chartは飛行モード・フェーズ用で、Chart内部のMATLAB Functionは0個です。PWMの実書き込みは最上位の別ブロックに残しています。

## 整理前後の等価性

変更開始時に保存した、ユーザーの未保存変更を含むモデル `archive/FlightTest_before_control_layout_20261015_145343.slx` を基準にしました。ディスクにあった旧保存版は別のスナップショットとして残しています。

基準モデルと整理後モデルに同じ入力を与え、センサー処理・推定・制御・診断までの実際のモデル部分を比較しました。

| シナリオ | 周期数 | 結果 |
|---|---:|---|
| 起動・離陸・ホバリング・着陸 | 12,000 | 15出力すべて一致 |
| モード切り替え・Flip | 12,000 | 15出力すべて一致 |
| センサー更新タイミング・通信中断など | 12,000 | 15出力すべて一致 |

合計36,000周期。許容差0で値・型・サイズが一致し、最大差も0でした。比較出力はモーターDuty・8 bit指令・モード・姿勢角・角速度・高度・鉛直速度・四元数・フラグ・診断・前周期モード・高度制御フラグ・通信状態・Flipフェーズです。

最終の機能分割後に独立したMATLABプロセスで比較と機体モデル全体のコンパイルを行い、成功しました。その後は表示・位置・配線経路だけを調整しています。最終表示の接続検査とStateflow検査も成功しています。

結果は [control_layout_verification.json](control_layout_verification.json)、`tests/control_layout_equivalence.mat`、比較モデルは `tests/models/ControlLayoutEquivalence400.slx` です。

この結果は同じ入力に対する数値計算の比較です。今回の実飛行、実機の最大処理時間、PWM波形の測定は行っていません。400 Hz（2.5 ms）、PWM 150 kHz指定／8 bitの設定は維持しています。

## PID専用ブロックの比較結果

現行の7個のPIDについて、SimulinkのDiscrete PID Controllerで近い設定を作りました。Ideal形式、台形積分、台形の微分フィルター、外部Dt、単精度、積分状態の上下限±30000、停止中の出力保持を設定しています。

ゲインの対応は `P = Kp`, `I = 1/Ti`, `D = Td`, `N = 1/(Eta*Td)` です。各PIDで6条件、各800周期を比較しました。

| 条件 | 結果 |
|---|---|
| Dtが常に2.5 ms | 非常に近いが、厳密一致ではない。最大差は約1.1×10⁻⁷〜4.8×10⁻⁶ |
| Dtが±16%変動 | 明確な差。高度PIDの最大差は約0.157、姿勢角PIDは約0.193 |
| 動作中のリセット | 再開する計算の出力に差がある |
| 停止中のリセット | 内部状態を消去するタイミングが異なる |
| 前回誤差を指定してリセット | 候補ブロックは現行の任意の前回誤差指定を再現していない |
| 積分状態の上限・下限に達する入力 | 差がある。境界確認用に大きな誤差入力を与えた試験で、通常飛行の入力ではない |

これらはPID出力の差です。高度が同じメートル数だけずれることを示す値ではありません。PIDごとに出力の意味・スケールも異なるため、軸間の最大差をそのまま比べて性能を判断できません。

PIDは現在の誤差だけでなく、積分状態、微分フィルター状態、前回誤差、前回出力を記憶します。現行実装は、リセットを先に処理し、実行が許可されていればその周期の計算へ進みます。停止中でも必要な内部状態をリセットし、出力は別の記憶で保持します。候補のEnabled Subsystem内に置いた専用PIDでは、停止中のリセットと任意の前回誤差の初期化を再現できていません。周期変動時の計算と、単精度の計算順序にも差があります。

現行の計算は次の形です。`e`は誤差、`h`は実測Dt、`i`と`d`は内部状態です。

```matlab
i = clamp(i + h*(e + previousError)/2/Ti, -30000, 30000);
d = (2*Eta*Td - h)*d/(2*Eta*Td + h) ...
    + 2*Td*(e - previousError)/(2*Eta*Td + h);
y = Kp*(e + i + d);
```

今回の比較で分かったのは、試した設定の専用PIDへそのまま置き換えると等価にならないことです。追加の補正や状態管理を付けたすべての構成が不可能、という結論ではありません。元の動作を保つため、本番は既存のSum・Gain・Unit DelayなどのPIDサブシステムを残しました。

結果は [pid_block_comparison.json](pid_block_comparison.json)、`tests/pid_block_comparison.mat`。検討用モデルは `models/PIDBlockComparison400.slx` で、機体モデルには接続していません。再実行に必要なゲインとブロックIDは `tests/pid_comparison_metadata.mat` に保存しています。

## 再実行

比較スクリプトはUSB・シリアルへアクセスしません。機体全体のコンパイル確認はStopTime=0です。既存デスクトップのロガーやクラスキャッシュを触らず、独立したMATLABプロセスで実行できます。

```matlab
run('config/startup.m');
run_control_layout_checks();
```

PIDの結果だけ再現する場合は次のとおりです。

```matlab
run('config/startup.m');
verify_pid_block400();
```

`create_pid_comparison400` は検討用モデルを新規作成する処理です。既に開いている比較モデルがある場合は、新規作成を行わず保存済みモデルを使ってください。`scripts/model_edit`の段階別スクリプトは当時のブロックIDを対象にした履歴です。現在のモデルへ一括で再実行しないでください。

## 機体に入っているファームウェア

今回の変更を含む最新の保存モデルが機体に入っています。配布用の版は `firmware/current/StampFly_Official_FlightTest400.bin`、SHA256は `276049cbb0723367d9b74944e5b491f468ed289da0a66c580672ca63510ea49b` です。400 Hz、PWM 150 kHz 指定／8 bit のビルドに成功し、COM4 のアプリ領域へ書き込んで `digest matched` を確認しました。JoyStickは公式 `StampFlyController_V1.2.0_20260610.bin` のままです。今回の更新版の実飛行は未実施です。

参考：[MathWorks Discrete PID Controller](https://www.mathworks.com/help/releases/R2026b/simulink/slref/discretepidcontroller.html)、`code/+official/pidStep.m`、`official_sources/M5StampFly/src/pid.cpp`。
