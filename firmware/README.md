# 書き込み済みファームウェア

`current/StampFly_Official_FlightTest400.bin` は、36,000周期・15出力の等価性確認と ESP32-S3 ビルドを通した新版です。2026-10-15 に COM4 の StampFly へアプリ領域だけを書き込み、全領域の digest 照合に成功しました。SHA256 は `4F8FDE9013CD943AAB884ADE2F9F7E2532B55E086B510BB405D92E823B0190B2`。書き込み記録は `docs/reorganized_flight_deployment.json` です。

`previous_successful/` は、ユーザーが飛行成功を報告したセンサー処理置き換え版のアプリです。SHA256 は `5A3D486B4152BB3328E481755A2E93826A5616160FB5929266D73AB4EAFC7C14`。

通常の再ビルド出力は Git 管理外の `build/` に保存されます。このフォルダーは配布する版を識別するために置いています。新版の物理的な飛行結果・書き込み後の周期実測はまだ取得していません。
