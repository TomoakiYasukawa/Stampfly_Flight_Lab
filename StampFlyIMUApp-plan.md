# StampFlyIMUApp の改善方針

既存の App Designer テキスト形式（`.m` + `.xml`）とタブ構成を維持します。現在のアプリは `backups/app_review_20261017/` に保全済みです。

1. 履歴の保存先フォルダーを選択・表示し、自動記録と一覧で同じフォルダーを使用します。記録中の変更は次の記録から適用します。
2. 固定PID版の未記録P/I列と量子化でゼロに見える補正列に代えて、同時刻のSFIX補足から平滑化・制限後の共通推力差とモーター配分を表示します。欠測はNaNを維持します。
3. 診断フラグは項目ごとの帯と「下=OFF／上=ON」で示し、未記録とOFFを区別します。状態は初期化→校正→待機→飛行制御→着陸の表示順へ写像します。
4. 相対XYに開始・終了マーカーを置き、各グラフ上に表示中のファイル名／ライブデータ名を表示します。
5. 使用されていない飛行操作・旧高度調整欄を、実モデルの7 PID（IdealのP/I/D/N）と水平位置P・速度PI・制限値の設定へ置き換えます。モデルから読み出し、編集値をモデルへ反映、保存・再ビルド・書き込みの区別を表示します。
6. アプリとMAT記録を機器に接続せず検証し、READMEと履歴を更新します。

参照: `matlab-build-app/references/editing-guide.md`、`app-designer/agent-guide-shared.md`、`app-designer/agent-guide-plaintext.md`、`uifigure/grid-layout.md`、`uifigure/callbacks.md`。`.xml`は直接編集し、`.m`の変更は既存内容を読み取ってAppDesignerAgentInterfaceのコードAPIで保存します。モデルの係数設定は`reorg.edit`を使用します。
