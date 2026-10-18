# ファームウェアと保存版

通常は[READMEの手順](../README.md)で自分のCH・COMを設定し、モデルからビルド・書き込みします。BINには作成時のCHが入っています。

| 場所 | 内容 |
|---|---|
| `current/` | 新しい名前でビルドした`Stampfly_Tx`と`M5Stamp_Rx`のBIN・ブートローダー・パーティション・manifest |
| `history/horizontal1804/` | 安定飛行の報告がある1804の元BIN・manifest・ソース・結果 |
| `history/before_stampfly_lab_20261018.zip` | 整理直前モデル・BIN、2026-10-18に照合して書き込んだ機体BIN |
| `history/earlier_firmware.zip` | 1801・1802、IMU・公式・PID等の過去BIN。対応索引に元パス・サイズ・SHA-256 |
| `history/official_firmware.zip` | 比較で用いた旧公式ファームウェアと検証用抽出物 |
| `../archive/kf400/firmware/` | 標準高度Kalman比較の飛行したBIN |

`current/manifest.json`のハッシュが保存済みモデル・BINの対応です。**この名称・フォルダ整理で作ったBINは実機へ書き込んでいません。** 最新の実機書き込みは整理前名の2026-10-18の記録で、[履歴](../docs/history/README.md)から原文を参照できます。

ビルド時の`Flashed=false`と、その後の書き込み照合・USB・実飛行の記録を区別します。アーカイブ内の旧manifestは原文を保持するため、当時の保存場所を指します。ZIP索引でファイル名・SHA-256の対応を確認してください。

通常の生成コードは`build/`、機体から読み出した復元用バックアップは`backups/`です。現在のフラッシュ構成は4MiB設定、各アプリ区画0x140000バイトです。今回パーティションや容量設定を変更していません。
