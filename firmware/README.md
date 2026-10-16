# ファームウェアの版

現在の COM4 の機体は、階層・配線・配置を整理したIMU版 **`imu400_readability/StampFly_IMU400.bin`**（Revision 1701、CH 3）です。2026-10-16に986,400 byteのアプリ領域を書き込み、独立した全体digest照合とUSB起動確認を完了しました。SHA256は `D6FA440FCFB5CC5E6D9B15B0D590A15F42EDEEB6B1FF68126FB94C161D60DEAB`。整理後もユーザーから **「飛行試験OKです。」** と報告を受けています。飛行ログによる数値評価は未実施です。[今回の書き込み記録](../docs/imu_readability_aircraft_deployment.json)を参照してください。

整理前の飛行成功版は **`imu400/StampFly_IMU400.bin`** に保存しています。同日にユーザーからIMU版で「実機飛行しました。問題ありません。」の報告がありました。飛行ログによる数値評価は未実施です。整理前後の36,000周期・36出力が完全一致し、Stateflow・時刻処理、磁気・光学フロー・ToFを含む3種のログパケットも一致しました。今回のUSB再計測は15秒間CRCエラーゼロ、PWMゼロ、姿勢正常。処理時間は平均1.611 ms、最大2.546 ms、6,000周期中3回の2.5 ms超過、取りこぼしゼロです。初回に受信した2件の途中切れUSBパケットも記録に残しています。[検証](../docs/imu_readability_verification.json)、[ビルド](../docs/imu_readability_build.json)、[USB記録](../docs/imu_readability_usb_startup.json)を参照してください。

直前の基礎版 **`basic400/StampFly_Basic400.bin`** はFlipを削除した学生向けの版です。2026-10-16 に980,272 byte全体の書き込み・独立したdigest照合を完了しました。BuildID 1401、FirmwareRevision 1601、CH 3です。10秒間のUSBログで基礎版、待機状態、適用PWMゼロを確認しました。同日にユーザーから実飛行成功（「完璧です」）の報告があります。飛行ログは未取得です。IMU版の書き込み前にも機体とのdigest一致を確認し、復元用に保存しています。記録は [docs/basic_aircraft_deployment.json](../docs/basic_aircraft_deployment.json)。SHA256は `FCCC066A953F4CF17F1E8C986948FE901EE26577AEDDD401EEF60175B423A7DE` です。

基礎版の直前の機体は `logging400/StampFly_PIDBlock_FlightTest400.bin`（Revision 1502、Flipあり）でした。書き込み前に機体と保存BINのdigestが一致することを確認し、`backups/`へ復元用のコピーを残しています。

`imu400/StampFly_IMU400.bin` は基礎版をコピーしてMadgwickを標準IMU Filterへ置き換えた版です。PIDへ渡す角速度も残留バイアス補正済みです。BuildID 1401、FirmwareRevision 1701、CH 3、986,656 byte、SHA256 `12C1DC6A8B5CFB897D1649A048EE25E7D59BDF898F43E7299B4BF8A08BFAC40F`。ESP32-S3ビルドと推定器のオフライン検証、同じ推定値を両版に与えた36,000周期の制御比較は成功しています。15秒間のUSBログでCRCエラーゼロ、待機状態、PWMゼロ、正常なクォータニオンを確認しました。400 Hzタスクは平均約1.613 ms、最大2.552 msで、6,000周期中2回の2.5 ms超過がありました。取りこぼしはゼロですが、全周期の期限内完了は達成していません。[IMU版の設定と検証](../docs/imu_flight_model.md)、[ビルド記録](../docs/imu_flight_build.json)、[USB起動・処理時間](../docs/imu_usb_startup.json)を参照してください。

`pid_experiment/StampFly_PIDBlock_FlightTest400.bin` は、追加ロギング前の専用PID比較版です。SHA256 は `235C4E34099E0A53B848499929E9B61C006B55AEF7F2DF52DC25BD475E15AB98`。2026-10-15 の書き込み記録は `docs/pid_flight_deployment.json` にあります。

`current/StampFly_Official_FlightTest400.bin` は、PID比較前の基準版です。飛行制御の分割・配線整理後に36,000周期・15出力の等価性確認と ESP32-S3 ビルドを通しています。2026-10-15 に COM4 の StampFly へアプリ領域だけを書き込み、970,448 byte全体の digest 照合に成功しました。SHA256 は `276049CBB0723367D9B74944E5B491F468ED289DA0A66C580672CA63510EA49B`。記録は `docs/control_layout_flight_deployment.json` と `docs/reorganized_flight_deployment.json` です。比較基準として保存し、PID実験版で上書きしていません。

`previous_successful/` は、ユーザーが飛行成功を報告したセンサー処理置き換え版のアプリです。SHA256 は `5A3D486B4152BB3328E481755A2E93826A5616160FB5929266D73AB4EAFC7C14`。

`history/before_control_layout_20261015_175607/` には再書き込み直前の配布用ファームウェアと記録を保存しています。機体から読み出したアプリ領域のバックアップは Git 管理外の `backups/` にあります。

通常の再ビルド出力は Git 管理外の `build/` に保存されます。このフォルダーは配布する版を識別するために置いています。基礎版のUSBログでは400周期ごとの診断と3種類の50 Hzログを確認しています。実飛行成功はユーザー報告による確認で、飛行中の数値評価は行っていません。
