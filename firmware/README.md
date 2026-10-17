# ファームウェアの保存先

現行モデルは `StampFly_IMU400.slx` です。通常利用では[セットアップ](../docs/setup.md)から自分の専用CHを設定してビルド・書き込みします。配布BINには生成時のCHが入っているため、CHを変更する場合はモデルから作り直してください。

| 場所 | 内容 |
|---|---|
| `current/` | 安定飛行の報告があるRevision 1804。機体BIN、受信機BIN、ブートローダー、パーティションとmanifest |
| `history/horizontal1801/` | 実飛行で落下した水平補助版。1801の機体BINとビルド時manifestを保全 |
| `history/horizontal1802/` | 待機中にCPU0 idle watchdogによる再起動を捕捉した診断版。BIN・manifest・当時の記録を保全 |
| `history/horizontal1804/` | CPU1固定・区間計測版の安定飛行後に保全したBIN・manifest・書き込み・実飛行記録 |
| `history/imu_cleanup1701/` | 水平補助追加前の整理後IMU版。USB確認済み |
| `history/imu400_readability/` | 再整理前の実飛行成功IMU版。Revision 1701、CH 3 |
| `history/imu400/` | 最初にIMU Filterへ置き換えた実飛行成功版 |
| `history/basic400/` | Flipを削除した基礎版 |
| `history/logging400/`、`pid_experiment/`など | 過去のPID・公式制御・ログ拡張版 |
| `../archive/kf400/firmware/` | 標準高度Kalmanの比較・実飛行版。Revision 1801、CH 3 |

今回の生成物と過去の成功版を混同しないよう、モデル・BINのSHA-256をmanifestで確認します。機体への最新の書き込み履歴は [docs/history/README.md](../docs/history/README.md) にまとめています。過去の成功報告は各保存版の結果です。

`history/horizontal1801/manifest.json`は当時の原文を保全しているため、内部の`File`は旧保存先`firmware/current/`を指します。1801の照合には同じファイル名を`history/horizontal1801/`から読み、機体モデルは`archive/snapshots/Horizontal1801.slx`を使います。`tools/verify_incident_artifacts.py`で現行版と保存版の対応を確認できます。

CPU1固定を維持した1804の書き込み・照合後、ユーザーから問題解消・安定飛行の報告を得ました。[最新書き込み](../docs/incident_aircraft_deployment.json)・[実飛行結果](../docs/incident1804_flight_verification.json)・[調査履歴](../docs/history/horizontal_trials/20261017_fall_review.md)で実装版と確認範囲を区別します。`manifest.json`の`Flashed`等はビルド時点の値で、その後の結果は書き込み・実飛行記録を参照してください。

通常の生成コードはGit管理外の`build/`、機体から読み出したバックアップは`backups/`です。以前の詳しい版情報は [firmware_before_cleanup.md](../docs/history/firmware_before_cleanup.md) に保存しています。
