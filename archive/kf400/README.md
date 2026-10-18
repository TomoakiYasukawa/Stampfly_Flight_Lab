# 標準Kalman Filterの比較用アーカイブ

通常利用・教材として採用するモデルは、プロジェクト直下の **Stampfly_Tx.slx** です。高度推定の予測・補正・状態保持を1つのMATLAB Functionで読める構成を優先しました。

このフォルダーの **StampFly_KF400.slx** は、標準Kalman Filterに置き換えた比較版です。2026-10-17にユーザーから **「実飛行テスト、問題なしです」** と報告を受けました。追加の配線修正は行わず、書き込み・飛行した保存モデルとBINをそのまま残しています。飛行ログによる数値評価は未実施です。

- `StampFly_KF400.slx`：標準Kalman Filter版。高度推定以外は作成時の整理済みIMU版と比較済み。
- `baseline/StampFly_IMU400.slx`：比較に使った、ToF常時取得と追加整理を行う前のIMUモデル。
- `firmware/`：Revision 1801、BuildID 1401、CH 3の書き込み済みBIN、ブートローダー、パーティション。
- `config/startup.m`と`baseline/config/startup.m`：保存モデルを移動せず開くためのプロジェクト初期化への入口。

MATLABで **StampFly_Lab.prj** を開き、ここにあるSLXをダブルクリックします。標準ブロックは **AttitudeAltitudeEstimation400 → AltitudeKalman → FilterStep → KalmanFilter** にあります。基準モデルには整理前の名前が残っているため、同時に開く際にはどちらのファイルを開いているか確認します。このアーカイブのフォルダー全体を通常のMATLABパスへ追加する必要はありません。

[GUI設定・更新順序・検証結果](../../docs/history/README.md)、[書き込み・飛行報告](../../docs/history/README.md)を参照してください。標準ブロックを従来の特殊な待機・リセット動作へ合わせるために周辺処理と階層が増えており、基礎教材では比較用として扱います。

保存モデルのSHA256：`7b4bfddfafad0d0a53b8b4ec998ce1f5f3be061954af273ab40c8e1d08045a0a`。書き込み済みアプリのSHA256：`3a44dc01f9b3f4ed0ec832977fa473a202781f625103a5fb22dec6911e89de61`。USB待機時計測は平均1.770 ms、最大2.699 ms、6,000周期中4回の2.5 ms超過、取りこぼしゼロでした。
