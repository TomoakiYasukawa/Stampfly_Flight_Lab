# 開発・比較用アーカイブ

通常の入口はプロジェクト直下の`Stampfly_Tx.slx`、`M5Stamp_Rx.slx`、`DataLogger`です。このフォルダは比較基準と判断根拠を残すためのものです。

| 場所 | 内容 |
|---|---|
| `snapshots/HorizontalBaseline.slx` | 水平補助追加前のOFF回帰基準 |
| `snapshots/Horizontal1801.slx` | 実飛行で落下報告のあった版。高度・待機修正の比較基準 |
| `snapshots/Horizontal1804.slx` | CPU1固定・区間計測を維持した安定飛行の報告版 |
| [kf400](kf400/README.md) | 標準高度Kalman比較。飛行したモデル・BINと比較基準 |
| `model_history.zip`、`model_history.index.json` | 公式・PID・再生モデルと過去の段階モデル。元のバイト・SHA-256を保全 |
| `development_history.zip` | 一度だけ使った移植・配置・編集・展開スクリプトとモデル内Functionの書き出し |

過去モデルは`stampfly_model_file('モデル名')`からキャッシュへ展開し、明示的に開けます。過去の開発スクリプトはZIPを直接読むか`configure_stampfly_archive()`で展開します。展開先は`build/history/`です。

同名のモデルがあるため、フォルダ全体を通常検索パスへ追加しないでください。モデルごとにモーター出力・初期化・飛行確認の条件が異なります。古い編集・展開スクリプトを現行モデルへそのまま再実行しません。

判断の経緯と原文検証記録は[履歴](../docs/history/README.md)、BINの場所は[firmware/README.md](../firmware/README.md)を参照してください。
