# StampFly 公式制御の Simulink 移植

現在、StampFly COM4 には **`StampFly_Official_Bench400` の生成ファームウェア**を書き込んであります。メイン制御400 Hz、LEDC PWM指定150 kHz／8 bit、公式の離陸・高度保持ロジック、コピーした50 Hzデータロガーを含みます。**実モーター出力はゼロに固定されています。** JoyStick COM6 の公式ファームウェアは維持しています。

モデルの開き方・コードの読み順・公式との差・検証結果は [Simulink移植の説明](docs/official_simulink.md)、不足していた関数の修復内容は [ツールキットの復旧記録](docs/toolkit_recovery.md) を参照してください。

```matlab
init_official
open_system('StampFly_Official_Bench400')
app = run_stampfly_imu_app;
```

`verify_official_models` で公式C++との数値比較とSimulink再生、`build_official_bench` でモーター無効化を確認してビルドできます。後者は書き込みを行いません。バッテリーなし・USB給電の検証を実施しており、飛行可能なファームウェアとしては検証していません。

---

## 以前に行った公式 JoyStick 操作環境の構築

以下は2026-10-14の公式バイナリ導入時の記録です。現在の機体ファームウェアは上記Simulink版に置き換わっています。以降の飛行操作説明は公式バイナリへ復元した場合に適用します。

M5Stack 公式配布のファームウェアを使用する環境です。2026-10-14 に両機器へ書き込みました。

| 機器 | USB ポート | MAC | 書き込み版 |
|---|---|---|---|
| StampFly | COM4 | 70:AF:09:DF:A6:C4 | v1.1.0 / 2024-08-12 |
| Atom JoyStick | COM6 | 48:CA:43:B6:5B:30 | Controller v1.2.0 / 2026-06-10 |

Controller v1.2.0 は公式ガイドで AtomS3 と AtomS3R の両世代に対応する版です。PC は書き込みに使用し、操作時は JoyStick と StampFly が ESP-NOW で直接通信します。

## 確認結果

- 両機器の 8MB フラッシュを変更前にバックアップ済みです。`backups/` に保存しました。
- 書き込み時のハッシュ照合に成功しました。
- 再起動後に実行コードを独立照合し、両方で `digest matched` を確認しました。ブートローダーとパーティションテーブルも公式ファイルと一致しました。
- 再起動後の全体比較では NVS の 0x9000 セクターのみ変化しました。これは起動時の設定更新を含むため、以後の照合は実行コード・ブートローダー・パーティションテーブルを対象にします。
- USB 給電のみでの起動後、ユーザーが JoyStick の操作画面に `Press to Fly` が表示されることを確認しました。機体を持ち上げると ALT が約 0.2〜0.3M に変わり、無線の情報返信まで確認できました。
- ユーザーから飛行テスト実施の報告がありました。飛行中のログや詳細な結果は取得していません。

詳しい識別情報、SHA-256、バックアップ名は `setup_record.json`、書き込み・照合の記録は `logs/` に保存しています。公式の配布ファイルとソースは `official_sources/` にあります。

## ペアリング

バッテリー・プロペラを外した StampFly を USB につなぎ、水平に置いて進めます。

1. JoyStick を USB 給電で起動します。既存のペアリングが使える場合は操作画面へ進めます。
2. ペアリングし直す場合は、AtomS3 / AtomS3R の画面中央ボタンを押しながら USB を接続します。
3. ペアリング案内が出たら中央ボタンを離し、もう一度短く押して検索を始めます。
4. StampFly の中央ボタンを短く押して再起動します。起動時にペアリング信号を送ります。
5. JoyStick の成功表示と再起動を待ちます。設定画面の `Press to Next` を中央ボタンで選び、操作画面で `Press to Fly`、高度、機体の電圧を確認します。

初回起動の紫色の表示中はセンサー校正のため機体を動かさないでください。バッテリーを外した USB 給電では低電圧による水色の点滅が出る場合があります。

## 基本操作

最初の飛行は `Stabilize` と `Auto Altitude` を選びます。公式の起動時設定はこの組み合わせです。

| 操作 | 動作 |
|---|---|
| AtomS3 / AtomS3R 画面中央ボタン | 自動高度モードで離陸 / 着陸 |
| 左スティック上下 | 目標高度の上げ下げ |
| 左スティック左右 | 機体の向きを変える |
| 右スティック上下 | 前後の移動 |
| 右スティック左右 | 左右の移動 |
| 左前ボタン | Stabilize / Sport 切り替え |
| 右前ボタン | Auto Altitude / Manual Altitude 切り替え |
| 右スティック押し込み | 宙返り |

飛行時は機体のバッテリーを充電し、プロペラを元の正しい位置・向きへ戻し、USB を外して水平な床へ置きます。校正後に `Press to Fly` を押して離陸します。着陸は `Press to Land` です。このボタンは自動高度モードでは管理着陸で、即時のモーター停止とは異なります。

## Fly を押したときの飛行制御

以下は公式 M5StampFly 公開コードの `src/flight_control.cpp` と `src/sensor.cpp` に基づきます。起動時の Stabilize + Auto Altitude では、初期目標高度 0.5m へ向けて推力を徐々に上げ、姿勢と高度を機体上の 400Hz ループで制御します。

- 姿勢: BMI270 のジャイロ・加速度を Madgwick フィルターで処理し、ロール・ピッチを推定します。右スティックから作る目標角度に対し、姿勢 PID → 角速度 PID → 4モーターの PWM 配分、の順に制御します。目標角度は ±30度に制限されます。
- 高度: 下向き ToF 距離と鉛直加速度を Kalman フィルターで統合し、高度・上下速度を推定します。高度 PID → 目標上下速度 → 上下速度 PID → 共通推力、の順に制御します。左スティック上下は目標高度を変更します。目標高度のコード上の範囲は 0.05〜1.8m です。
- 旋回: 左スティック左右はヨー角速度の指令です。中立では旋回を抑えますが、絶対方位を固定する制御ではありません。
- 水平移動: 右スティックは傾きの指令です。この配布版には光学フローを使用した水平位置・水平速度の制御がありません。中立に戻すと水平姿勢へ戻りますが、その場所を保持したり流れを積極的に打ち消したりする制御はありません。
- 着陸: Press to Land で自動着陸へ移り、上下速度の目標を -0.15m/s にします。推定高度が 0.1m 未満になると待機へ戻してモーターを止めます。

Sport はロール・ピッチの姿勢角度ループを外して角速度を指令する方式です。Manual Altitude は高度保持を外してスロットルを指令する方式です。姿勢モードと高度モードは別々に切り替えられます。

## 公式版の再書き込み

このフォルダーで PowerShell から実行できます。Python と pyserial はこの PC の既存環境を使用し、esptool は `tools/esptool.exe` に保存済みです。機器は MAC で識別するため、COM 番号が変わっても検出します。

```powershell
# 機体のバッテリー・プロペラを外して USB 給電だけにした後に実行
.\flash_official.ps1 -Device StampFly -UsbOnly
.\flash_official.ps1 -Device JoyStick -UsbOnly
```

スクリプトは公式ファイルの SHA-256 を確認し、8MB バックアップを保存してから書き込みます。バックアップが失敗した場合は書き込みません。

ダウンロードモードへ手動で入れる場合は、StampFly は中央ボタンを押しながら USB を接続します。JoyStick は USB 接続後に側面リセットボタンを長押しし、緑の表示が出たら離します。

## 元のファームウェアへの復元

バッテリー・プロペラを外して、対応する機器とポートを確認してから実行します。8MB 全体を復元するため、現在の公式版と設定を置き換えます。

```powershell
.\tools\esptool.exe --chip esp32s3 --port COM4 --baud 460800 write_flash 0x0 .\backups\StampFly_COM4_before_official_20261014.bin
.\tools\esptool.exe --chip esp32s3 --port COM6 --baud 460800 write_flash 0x0 .\backups\JoyStick_COM6_before_official_20261014.bin
```

## 参照元

- [公式ファームウェア・ペアリング・操作ガイド](https://docs.m5stack.com/en/guide/stampfly/firmware)
- [M5StampFly 公式ソース・ファームウェア](https://github.com/m5stack/M5StampFly)
- [Atom JoyStick / StampFlyController 公式ソース・ファームウェア](https://github.com/m5stack/Atom-JoyStick/tree/main/examples/StampFlyController)

保存した公式ソースのコミット: M5StampFly `fa7b6a59c7f297d398d381840184451dce137c48`、Atom-JoyStick `e9f53fbd8a2edd25aedf987aac2ae40a52e6bea0`。各ソースの MIT LICENSE も保存しています。
