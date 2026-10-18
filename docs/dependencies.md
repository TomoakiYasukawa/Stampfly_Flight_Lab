# 必要な製品と同梱コード

現行の `Stampfly_Tx.slx`、`M5Stamp_Rx.slx`、`DataLogger` を使う場合の依存関係です。リポジトリ全体を取得し、`StampFly_Lab.prj`を開いて使用します。

## インストールする製品

| 製品 | 用途 |
|---|---|
| MATLAB、Simulink | モデル・アプリ・シミュレーション |
| Stateflow | 飛行状態、離着陸の状態遷移 |
| Simulink Coder、Embedded Coder | ESP32-S3用コードと`ert.tlc`のビルド |
| Navigation Toolbox | 標準IMU Filter |
| Parallel Computing Toolbox（任意） | DataLoggerのMAT保存・履歴読込の別プロセス実行。利用不可でも同期処理で動作 |
| Simulink Support Package for Arduino Hardware | ESP32-S3のツールチェーン、USB展開、Arduinoライブラリー |

確認環境は **R2026b／Arduinoサポートパッケージ26.2.3** です。異なるリリースのモデル変換・ビルド互換性は未確認です。標準Kalman比較版を調べる場合は、そのブロックを提供するControl System ToolboxまたはSystem Identification Toolboxも必要です。

## リポジトリに含めているもの

| 場所 | 内容 |
|---|---|
| `code/+stampfly`、`code/+official`、`code/+basic` | センサー、通信、タイマー、モーター、ログのSystemブロック |
| `code/+imu` | アプリの表示・記録・ログ解読、ログ受信機 |
| `code/+horizontal` | 水平速度・相対位置推定、速度目標、速度PI、姿勢選択、IMU読出し状態、ログの負荷分散 |
| `src/bmi270`、`src/bmm150`、`src/pmw3901` | BMI270、BMM150、PMW3901のドライバーと接続処理 |
| `src/vl53l3cx`、`third_party/M5StampFly_official_5d6c3417` | ST VL53L3CXのドライバーと公式版ULD |
| `src/official_*`、`src/imu_*` | 無線、USB、GPIO/PWM、I2C排他、非同期取得、周期実行 |
| `official_sources/` | 比較・出典として保存したM5Stackソースとライセンス |
| `libraries/` | プロジェクト内の教材ブロックライブラリー |

独自ドライバーやアプリは、隣接する個人用プロジェクトを参照せず、このチェックアウト内で解決します。Arduinoの **SPI／Wire** とESP32の実行基盤はサポートパッケージ側のインストールを使用します。製品・サポートパッケージ自体はリポジトリへコピーしません。

プロジェクトのパスは`config/configure_stampfly_project.m`で設定し、ルートはファイル自身の場所から求めます。キャッシュ・生成コードは`build/`へ保存します。アーカイブの同名モデルが混ざらないよう、`archive/`は通常の検索パスに追加しません。

両モデルのビルドでプロジェクト外の独自ソース参照がないことを確認しています。検索パスを初期化した別フォルダーのコピーでもモデル更新とアプリ起動を確認しました。[確認結果と範囲](development.md)

## 保守・検証だけで使うもの

モデル構造の編集スクリプトは **Simulink Agentic Toolkit** を使用します。保存済みモデルの閲覧、GUIからの設定・ビルド・書き込み、アプリ利用には必要ありません。アプリの制御パラメータ反映は、Toolkitがある環境では共通編集API、配布先では標準Simulink APIを使います。

Pythonのシリアル・書き込み補助ツールを使う場合はPython、pyserial、esptoolが必要です。依存名は`tools/requirements.txt`にあります。通常の操作はSimulink画面から行えます。水平補助のモデル試験はSimulink TestとSimulink Agentic Toolkit、生成MEX比較はMATLAB Coderと対応C/C++コンパイラーを使用します。通常の機体ビルド・アプリ利用にはこれらの追加試験製品は不要です。過去の構築・展開ツールは`archive/development_history.zip`にまとめています。

第三者コードの再配布条件・著作権表示は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) と各ソースのヘッダー・LICENSEを参照してください。
