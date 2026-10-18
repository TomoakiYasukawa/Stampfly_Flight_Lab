# 開発と検証

まず`StampFly_Lab.prj`を開きます。現行の入口は`Stampfly_Tx`、`M5Stamp_Rx`、`DataLogger`です。通常の設定・飛行は[README](../README.md)、実装の注意点は[AI_CONTEXT.md](../AI_CONTEXT.md)を参照してください。

## 生成物とMEX

`build/`は生成コード、Simulinkキャッシュ、MEX、試験結果、履歴の展開キャッシュです。再生成できる内容をソースフォルダへ出さないでください。記録や実機復元用バックアップはそれぞれ`recordings/`、`logs/`、`backups/`です。

通常の機体ビルド・DataLogger利用に、配布されたMEXバイナリは不要です。公式C++との比較試験では`tests/reference/`のソースから **`build/tests/mex/`**へ作ります。WindowsのMEXを他OS・他MATLAB版へそのまま配布する必要はありません。生成MEX比較にはMATLAB Coderと対応C／C++コンパイラーが必要です。

`resources/project/`はMATLABプロジェクトの登録・パス・ショートカットです。ファイル数が多くてもアプリの生成物ではないため、手作業で削除しません。MATLABの`removeFile`／`addFile`はGit接続中に変更を自動ステージする場合があります。`register_stampfly_project()`は事故を防ぐためGit接続中の実行を拒否します。

構成を変えたときは`python tools/create_distribution_check.py`でGitを含まない一時コピーを作り、別のMATLABセッションでコピーのプロジェクトを開いて`register_stampfly_project()`を実行します。プロジェクトチェックと依存関係の結果を確認してコピーを閉じてから、`resources/project/`の更新内容を元のプロジェクトへ戻します。元のプロジェクトも閉じた状態でメタデータを入れ替え、再度開いて確認します。登録更新だけを目的にGitへステージ・コミットする必要はありません。

## 変更後の確認

モデルは`Ctrl+D`で更新します。制御・ドライバーを変更した場合はビルドも行い、実機書き込み・USB確認・飛行結果を別々に記録します。

```matlab
open_system('Stampfly_Tx.slx');
set_param('Stampfly_Tx','SimulationCommand','update');
open_system('M5Stamp_Rx.slx');
set_param('M5Stamp_Rx','SimulationCommand','update');
buildReport = build_stampfly_lab(); % Build only; hardware is not contacted
```

新しいBINは`firmware/current/`、生成コードは`build/firmware/`に保存します。manifestにはモデル・BINのSHA-256と`Flashed=false`を記録します。保存した独自ソースは`ProjectSources`、再生成できるコードは`GeneratedSources`へ分け、参照パスをプロジェクト相対にしています。ビルド成功を実機書き込み成功として扱わないでください。GUIのビルド・展開操作は[セットアップ](setup.md)を参照します。

機器をつながず、アプリの受信・保存・履歴・表示・終了を確認できます。

```matlab
results = runtests({ ...
    'tests/DataLoggerDisplayTest.m', ...
    'tests/DataLoggerResponsivenessTest.m', ...
    'tests/FlightRecorderTest.m', ...
    'tests/RecordingHistoryTest.m', ...
    'tests/FlowDisplayFrameTest.m', ...
    'tests/LiveTimeAxesTest.m', ...
    'tests/StampFlyPoseProjectionTest.m', ...
    'tests/ControlSettingsTest.m'});
assert(all([results.Passed]));
```

アプリ試験はプロセス型プールを起動することがあります。`ControlSettingsTest`はPCの開いたモデルへ一時的に係数を変え、保存せずに戻します。未保存のユーザー作業を含むMATLABセッションと分けて実行してください。

`verify_horizontal_algorithms`、`verify_distributed_telemetry`、`verify_horizontal_codegen`などは水平推定・ログの比較に使えます。閉ループ・Gherkinの実ブロック試験は`tests/models/`のハーネスを使い、Simulink TestとSimulink Agentic Toolkitが必要です。通常利用にはToolkitは不要です。

## 過去の資料

検証JSON・旧説明の原文は`docs/history/records.zip`、索引は`docs/history/index.json`です。元の名前を指定すると必要時にキャッシュへ展開します。

```matlab
file = stampfly_record_file('docs/incident1804_flight_verification.json');
record = jsondecode(fileread(file));
```

Pythonでも原文を一覧・検索・読出しできます。

```powershell
python tools/history_records.py list --contains watchdog
python tools/history_records.py show docs/latest_aircraft_deployment.json
```

過去の一度だけ使う移植・編集・展開スクリプト、モデル内MATLAB Functionの書き出しは`archive/development_history.zip`です。作成当時のIDや構造を前提にしており、そのまま現行モデルへ再実行するための入口ではありません。読む必要があるときはZIPを開くか`configure_stampfly_archive()`で`build/history/development/`へ展開します。

JoyStickの公式ソース一式は`official_sources/controller_source.zip`にまとめ、元のコミット番号とライセンスを保持しています。通常はM5Stack公式配布ファームウェアを利用します。機体の公式比較ソースは`official_sources/M5StampFly/`に直接残しています。

公式版・PID版などの旧モデルは`archive/model_history.zip`、過去の比較ハーネスは`tests/reference/model_regressions.zip`へ集約しました。`stampfly_model_file('旧モデル名')`でキャッシュへ展開して明示的に開けます。現行の水平制御・推定・閉ループハーネスは`tests/models/`、水平補助の基準・失敗1801・成功1804と標準Kalman比較版は`archive/`に直接残しています。古いファイルは通常検索パスへ一括追加しません。

過去のUSB・書き込み・watchdog記録はローカルの`logs/hardware_history.zip`と索引へまとめました。実機読出しBINとユーザーMATは保全しています。`backups/runtime*/debug_symbols.zip`は不具合調査でアドレスを元のELFへ照合するためのものです。展開ファイルは不要になれば削除できますが、固有の実機バックアップと記録は削除対象にしません。

## 性能の変更を評価する

UIを占有するコールバック時間と、保存・解析の全体完了時間を別に測定します。既存メッシュは9,740三角形・4,778頂点で維持し、表示の間引きや補助面の追加は描画完了までの時間を比較してください。過去の応答改善の計測値・USB結果は[履歴](history/README.md)から参照できます。

`benchmark_app_responsiveness('名前',true)`で機器を使わない合成受信・保存・履歴測定ができます。保存用の`matfile`処理にはプロセス型プールを使います。プールの起動・再起動・失敗時フォールバックと、操作ウィンドウの終了条件も試験します。

## 配布

ソース配布ではプロジェクト全体と第三者ライセンスを含め、`build/`、`logs/`、`recordings/`、`backups/`を除きます。`tools/create_distribution_check.py`は独立フォルダへソースをコピーして照合するための補助です。

Compilerで対応機能をコンパイルしたDataLoggerはMATLAB Runtimeで使え、利用者のToolboxライセンスは不要です。作成側にはMATLAB Compilerと使用製品が必要です。並列プロセスのプロファイル・補助ファイル、XML、メッシュを含めてRuntime上で確認します。Simulinkモデル編集はRuntimeでは無効です。この整理では配布EXEの作成・Runtime検証は行っていません。
