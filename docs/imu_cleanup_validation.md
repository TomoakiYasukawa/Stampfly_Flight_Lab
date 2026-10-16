# 現行IMU版の整理と確認結果

現行の機体実装は **`StampFly_IMU400.slx`**、ログ受信機は **`M5Stamp_IMU_Rx.slx`** です。過去の実装・比較モデルは`archive/`へ移しています。標準高度Kalman版は追加修正せず保存し、現行版ではMATLAB FunctionのAltitudeKalmanを使います。

## 変更と確認

| 対象 | 内容・結果 | 記録 |
|---|---|---|
| 制御・推定・ログ | 3種類の入力、合計36,000時刻・36出力を整理前と比較。型・サイズ・値は一致し、誤差ゼロ。状態遷移・優先順位・ログCRCも確認 | [比較](imu_cleanup_verification.json) |
| 配線・階層・説明 | XYZのベクトル化、余分なラッパー削除、日本語コメント、端子名表示。現行モデル内に未接続の数値信号端子・途中で切れた線なし | [モデル監査](imu_cleanup_model_audit.json)、[構造](imu_cleanup_structure.json) |
| 配置 | 主要17画面を整理して確認。配置・マスク表示の変更前後で処理パラメーターと接続を維持 | [配置](imu_cleanup_layout.json)、[モデル解説](imu_flight_model.md) |
| ESP32-S3ビルド | 機体・受信機とも成功。独自ソースのプロジェクト外参照と未解決ソースはゼロ。配布BINと保存モデルのSHA-256を記録 | [ビルド](imu_cleanup_build.json)、[BIN一覧](../firmware/current/manifest.json) |
| 配布先の起動 | 別フォルダーへコピーし、`restoredefaultpath`後にプロジェクトを開く。両モデルの更新、アプリ起動・終了、同梱クラスの解決を確認 | [配布確認](imu_distribution_verification.json) |
| MATLABプロジェクト | 現行モデル・アプリ・READMEのショートカット、配布ファイル登録、生成物の保存先、依存関係とプロジェクトチェックを確認 | [プロジェクト確認](imu_project_verification.json) |
| アーカイブ | 移動後の開き方と、保存した全モデルのバイト一致を確認 | [アーカイブ確認](imu_archive_verification.json)、[移動一覧](imu_distribution_moves.json) |
| 実機書き込み・机上確認 | COM4の機体へ書き込み、内容の照合と15秒のUSB観測を実施。CRCエラー・待機PWMはゼロ、ToF・姿勢・高度の更新を確認 | [書き込み](imu_cleanup_aircraft_deployment.json)、[USB確認](imu_cleanup_usb_startup.json) |

配布用コピーは`.git`を含めず確認したため、「全プロジェクトファイルがソース管理対象」のチェックは未追跡と表示されます。モデル・アプリ・パスなどの実行に関するチェックは成功し、Git管理のチェックは元のチェックアウトで別途実施しています。

## 実機確認の範囲

**今回の整理版は実機へ書き込み・照合済み、実飛行は未実施です。** CH 3、Revision 1701の検証済みBINを使用し、書き込み前のKF版アプリ領域をバックアップしました。USBで待機中のMode 3を観測し、ToFの有効サンプル増加と読み出しエラーゼロを確認しています。

周期処理時間は6,000周期で平均 **1.616 ms**、最大 **2.561 ms**、2.5 ms超過3回、取りこぼしゼロでした。全周期が2.5 ms以内という結果ではありません。校正中のMode 0・1、ToF到着時刻の詳細と飛行中の動作は未確認です。整理前後の比較は同じセンサー入力を与えた場合の一致を確認しています。過去の飛行成功は[履歴](history/README.md)に記録し、今回の机上確認と区別しています。
