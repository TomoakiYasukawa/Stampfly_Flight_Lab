# 書き込み済みファームウェア

`current/StampFly_Official_FlightTest400.bin` は、飛行制御の分割・配線整理後に36,000周期・15出力の等価性確認と ESP32-S3 ビルドを通した最新版です。2026-10-15 に COM4 の StampFly へアプリ領域だけを再書き込みし、書き込んだ970,448 byte全体の digest 照合に成功しました。SHA256 は `276049CBB0723367D9B74944E5B491F468ED289DA0A66C580672CA63510EA49B`。書き込み記録は `docs/control_layout_flight_deployment.json` と `docs/reorganized_flight_deployment.json` です。

`previous_successful/` は、ユーザーが飛行成功を報告したセンサー処理置き換え版のアプリです。SHA256 は `5A3D486B4152BB3328E481755A2E93826A5616160FB5929266D73AB4EAFC7C14`。

`history/before_control_layout_20261015_175607/` には再書き込み直前の配布用ファームウェアと記録を保存しています。機体から読み出したアプリ領域のバックアップは Git 管理外の `backups/` にあります。

通常の再ビルド出力は Git 管理外の `build/` に保存されます。このフォルダーは配布する版を識別するために置いています。新版の物理的な飛行結果・書き込み後の周期実測はまだ取得していません。
