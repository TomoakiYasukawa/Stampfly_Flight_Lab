# ファームウェアの保存先

現行モデルは `StampFly_IMU400.slx` です。通常利用では[セットアップ](../docs/setup.md)から自分の専用CHを設定してビルド・書き込みします。配布BINには生成時のCHが入っているため、CHを変更する場合はモデルから作り直してください。

| 場所 | 内容 |
|---|---|
| `current/` | 今回の整理後IMUモデルから作成したBIN、ブートローダー、パーティションとmanifest |
| `history/imu400_readability/` | 再整理前の実飛行成功IMU版。Revision 1701、CH 3 |
| `history/imu400/` | 最初にIMU Filterへ置き換えた実飛行成功版 |
| `history/basic400/` | Flipを削除した基礎版 |
| `history/logging400/`、`pid_experiment/`など | 過去のPID・公式制御・ログ拡張版 |
| `../archive/kf400/firmware/` | 標準高度Kalmanの比較・実飛行版。Revision 1801、CH 3 |

今回の生成物と過去の成功版を混同しないよう、モデル・BINのSHA-256をmanifestで確認します。機体への最新の書き込み履歴は [docs/history/README.md](../docs/history/README.md) にまとめています。過去の成功報告は各保存版の結果です。

現行IMU版は[機体へ書き込み・USB机上確認済み](../docs/imu_cleanup_aircraft_deployment.json)です。実飛行は未実施です。`manifest.json`の確認フラグはビルドした時点の記録で、実機の確認結果は書き込み記録に保存しています。

通常の生成コードはGit管理外の`build/`、機体から読み出したバックアップは`backups/`です。以前の詳しい版情報は [firmware_before_cleanup.md](../docs/history/firmware_before_cleanup.md) に保存しています。
