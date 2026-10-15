# StampFly 公式制御の Simulink 移植

M5Stack の公式飛行制御を、学生が機能ごとに編集できる Simulink モデルへ移植したプロジェクトです。制御周期は **400 Hz（2.5 ms）**、モーター PWM は **150 kHz 指定／8 bit**。下向き ToF を使う自動離陸・高度保持を含み、前向き ToF は無効、Optical Flow は未実装です。

2026-10-15 に、機体へ専用PIDの比較版 `StampFly_PIDBlock_FlightTest400.slx` を書き込み、独立した照合で `digest matched` を確認しました。元の `StampFly_Official_FlightTest400.slx` は比較基準として保存しています。**両モデルは実モーター出力が有効です。** 比較版の実飛行は未実施です。[現在の状態](docs/current_flight_status.md)、[PID飛行比較](docs/pid_flight_experiment.md)、[書き込み記録](docs/pid_flight_deployment.json) を参照してください。

## 開き方

MATLAB の現在のフォルダーをこのリポジトリの直下にして実行します。

```matlab
run('config/startup.m');
open_system('StampFly_Official_FlightTest400.slx');
app = StampFlyIMUApp;
```

受信機モデルは `open_system('M5Stamp_IMU_Rx.slx')` で開きます。モデルとアプリの起動時にもパスとキャッシュ保存先を設定します。アプリの `StampFlyIMUApp.xml` は `.m` と同じく直下に置いてください。離着陸と操縦には公式 JoyStick、記録には受信機とロガーアプリを使います。シリアル接続はアプリ上で選択します。

現在の機体のPID比較版は `open_system('StampFly_PIDBlock_FlightTest400.slx')` で開きます。7個のPIDを専用ブロックへ置換し、ゲイン・実測Dt・単精度・400 Hz設定を引き継いでいます。元版との厳密等価性を求める変更ではありません。

## モデルと検証

最上位では、各センサー、センサー補正、姿勢・高度推定、飛行制御、モーター書き込みを分離しています。主要ブロックの入力・出力はそれぞれ最大 4 ポートで、関連信号はバスにまとめて直接配線しています。ロギング・LED・JoyStick などの補助経路では Goto/From を使います。

飛行モードを扱う 4 個の Stateflow Chart は状態と遷移で記述し、Chart 内の MATLAB Function は 0 個です。数値計算には Simulink ブロックと独立した MATLAB Function を使います。モデル内の説明は日本語です。

最初の飛行成功モデルとの比較では、3 シナリオ・36,000 周期について 15 出力の値・型・サイズがすべて一致しました。結果は `tests/final_pipeline_equivalence.mat`、整理後の機体・受信機モデルのコンパイル確認は [検証記録](docs/project_layout_verification.json) に保存しています。

`FlightControl400`と`TakeoffHoverControl400`も機能別に分割し、直接配線と名前付きバスで整理しました。この整理前後も3シナリオ・36,000周期・15出力が許容差0で一致し、機体モデルのコンパイルが成功しています。専用PIDブロックは周期変動・リセット時などに差があったため、本番のPIDは維持しています。[制御の読み方とPID比較](docs/control_layout_and_pid.md)を参照してください。

```matlab
run('config/startup.m');
open_system('StampFly_Official_FlightTest400.slx');
equivalence = verify_final_pipeline();
buildReport = build_reorganized_flight_model();
```

ビルドは書き込みを行いません。生成物は `build/model_reorganization/`、書き込み済み版は `firmware/current/`、前回の飛行成功版は `firmware/previous_successful/` にあります。[ファームウェアの説明](firmware/README.md) を参照してください。

## フォルダー

| 場所 | 内容 |
|---|---|
| 直下 | アプリ `.m`・`.xml`、機体モデル、受信機モデル |
| `code/`、`src/` | MATLAB アルゴリズム・System object、低レベルの機器ドライバー |
| `config/` | パス設定、キャッシュ設定、パーティション設定 |
| `scripts/` | 起動、ビルド、検証、解析、モデル編集履歴 |
| `models/`、`libraries/` | 代替・ベンチ・再生モデル、既存の学生用ライブラリー |
| `tests/` | 比較入力、検証結果、検証用モデル、参照コード |
| `docs/`、`resources/` | 説明・書き込み記録、表示用リソース |
| `firmware/` | 書き込み済み版と前回成功版 |
| `official_sources/`、`third_party/` | 公式ソースと依存ソース、各ライセンス |
| `archive/`、`tools/` | 以前のモデル・説明、補助ツール |

キャッシュは `build/cache/`、通常のコード生成は `build/codegen/` に保存します。`build/`、`logs/`、`recordings/`、個体別の `backups/` と生成中間ファイルは Git 管理から除外しています。`scripts/model_edit/` は過去のモデル構造を対象にした処理も含むため、現在のモデルへ一括実行しないでください。学生用ライブラリーは今回の最終モデルに合わせた更新をまだ行っていません。

## 参照元とライセンス

- [公式ファームウェア・操作ガイド](https://docs.m5stack.com/en/guide/stampfly/firmware)
- [M5StampFly 公式ソース](https://github.com/m5stack/M5StampFly)
- [StampFlyController 公式ソース](https://github.com/m5stack/Atom-JoyStick/tree/main/examples/StampFlyController)
- [移植の説明](docs/official_simulink.md)、[第三者ソースの注意事項](docs/THIRD_PARTY_NOTICES.md)

保存した公式ソースのコミットは M5StampFly `fa7b6a59c7f297d398d381840184451dce137c48`、Atom-JoyStick `e9f53fbd8a2edd25aedf987aac2ae40a52e6bea0` です。各ソースに付属するライセンスと著作権表示を保持しています。
