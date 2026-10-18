# ドキュメント案内

最初に機体を飛ばす方は[プロジェクト直下のREADME](../README.md)、アプリ操作は[DataLogger_GUIDE.md](../DataLogger_GUIDE.md)から始めてください。このフォルダには現行の説明を置きます。

| 目的 | 説明 |
|---|---|
| 製品・USB・ビルド | [セットアップ](setup.md)、[依存製品と同梱コード](dependencies.md) |
| モデルを読む | [機体モデル](imu_flight_model.md)、[CPU・処理周期](cpu_tasks.md) |
| 制御を調整する | [制御パラメータ](control_parameters.md)、[水平補助](horizontal_control.md) |
| 記録を解析する | [ログ形式と項目](logging_extensions.md) |
| 開発・試験・配布 | [開発手順](development.md) |
| 過去の結果・整理内容 | [履歴の要約と記録集](history/README.md) |
| ライセンス | [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) |

agentic AIは[AI_CONTEXT.md](../AI_CONTEXT.md)を読んでから作業してください。

過去の検証JSON・画面・試行記録は`history/records.zip`へ集約しました。全件を順に読む必要はありません。`history/README.md`で必要な段階を選び、索引や参照ツールから原文を開けます。これから実行する検証の出力は`build/reports/`へ保存します。
