# 必要な製品と同梱コード

現行の `StampFly_IMU400.slx`、`M5Stamp_IMU_Rx.slx`、`StampFlyIMUApp` を使う場合の依存関係です。リポジトリ全体を取得し、`StampFly_Official.prj`を開いて使用します。

## インストールする製品

| 製品 | 用途 |
|---|---|
| MATLAB、Simulink | モデル・アプリ・シミュレーション |
| Stateflow | 飛行状態、離着陸の状態遷移 |
| Simulink Coder、Embedded Coder | ESP32-S3用コードと`ert.tlc`のビルド |
| Navigation Toolbox | 標準IMU Filter |
| Simulink Support Package for Arduino Hardware | ESP32-S3のツールチェーン、USB展開、Arduinoライブラリー |

確認環境は **R2026b／Arduinoサポートパッケージ26.2.3** です。異なるリリースのモデル変換・ビルド互換性は未確認です。標準Kalman比較版を調べる場合は、そのブロックを提供するControl System ToolboxまたはSystem Identification Toolboxも必要です。

## リポジトリに含めているもの

| 場所 | 内容 |
|---|---|
| `code/+stampfly`、`code/+official`、`code/+basic` | センサー、通信、タイマー、モーター、ログのSystemブロック |
| `code/+imu` | アプリの表示・記録・ログ解読、ログ受信機 |
| `src/bmi270`、`src/bmm150`、`src/pmw3901` | BMI270、BMM150、PMW3901のドライバーと接続処理 |
| `src/vl53l3cx`、`third_party/M5StampFly_official_5d6c3417` | ST VL53L3CXのドライバーと公式版ULD |
| `src/official_*`、`src/imu_*` | 無線、USB、GPIO/PWM、I2C排他、非同期取得、周期実行 |
| `official_sources/` | 比較・出典として保存したM5Stackソースとライセンス |
| `libraries/` | プロジェクト内の教材ブロックライブラリー |

独自ドライバーやアプリは、隣接する個人用プロジェクトを参照せず、このチェックアウト内で解決します。Arduinoの **SPI／Wire** とESP32の実行基盤はサポートパッケージ側のインストールを使用します。製品・サポートパッケージ自体はリポジトリへコピーしません。

プロジェクトのパスは`config/configure_stampfly_project.m`で設定し、ルートはファイル自身の場所から求めます。キャッシュ・生成コードは`build/`へ保存します。アーカイブの同名モデルが混ざらないよう、`archive/`は通常の検索パスに追加しません。

両モデルのビルドでプロジェクト外の独自ソース参照がないことを確認しています。検索パスを初期化した別フォルダーのコピーでもモデル更新とアプリ起動を確認しました。[確認結果と範囲](imu_cleanup_validation.md)

## 保守・検証だけで使うもの

モデル構造の編集スクリプトは **Simulink Agentic Toolkit** を使用します。保存済みモデルの閲覧、GUIからの設定・ビルド・書き込み、アプリ利用には必要ありません。

Pythonのシリアル・書き込み補助ツールを使う場合はPython、pyserial、esptoolが必要です。通常の操作はSimulink画面から行えます。過去の構築・展開ツールは`archive/maintenance/`に保存しています。

第三者コードの再配布条件・著作権表示は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) と各ソースのヘッダー・LICENSEを参照してください。
