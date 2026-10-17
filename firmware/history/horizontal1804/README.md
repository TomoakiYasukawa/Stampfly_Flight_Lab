# 水平補助・CPU固定版1804

書き込み・照合後、2026-10-17にユーザーから問題解消・安定飛行の報告を得た版です。CPU1固定、加速度の単位修正、待機リセットの立上り化、自動記録、区間計測を含みます。SPI一括転送の高速化は含みません。

- モデルの保存コピー：[`archive/snapshots/Horizontal1804.slx`](../../../archive/snapshots/Horizontal1804.slx)
- 実機への書き込み：[`deployment.json`](deployment.json)
- 実飛行報告：[`flight_verification.json`](flight_verification.json)
- ビルド時のモデル・BIN・ソースのSHA-256：[`manifest.json`](manifest.json)

manifestはビルド時の原文です。内部の`File`は当時の`firmware/current/`を指すため、このフォルダーの同じファイル名で照合します。`Flashed`等のフラグはビルド後の書き込み・実飛行を含みません。**ビルド時の全239ソースは[sources.zip](sources.zip)へ保全**し、manifestのSHA-256と照合しています。その後に改善したPCアプリの履歴処理とは区別します。モデルを開く際は元の名前`StampFly_IMU400.slx`を使い、現在のモデルを上書きせず別の作業先へ復元してください。
