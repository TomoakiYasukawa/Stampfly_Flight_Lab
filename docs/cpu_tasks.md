# CPUと処理周期の割り当て

機体はESP32-S3の2つのCPUを使います。現行モデルはsingle-taskingで、Simulinkから生成された周期実行タスク **BaserateをCPU1に固定**しています。ブロックの周期を50 Hzにしても、それだけでCPU0へ分かれるわけではありません。

| CPU | 処理 |
|---|---|
| CPU1 | モデルのstep全体。400 Hzの姿勢・高度・水平推定、PID、飛行状態管理、BMI270と光学フロー取得、50 Hzログ作成・距離換算、40 HzのJoyStick返信準備 |
| CPU0 | 別タスクのToF・磁気・電池読み出し、無線・USB送信、LED・ブザー出力 |

## 設定する場所

モデルの **TickStart → CycleClock** は [`official.TickStart400`](../code/+official/TickStart400.m) です。このクラスの`updateBuildInfo`が [`src/official_scheduler.cpp`](../src/official_scheduler.cpp) と `-Wl,--wrap=mw_osThreadCreate` をビルドへ追加します。

`official_scheduler.cpp`の`__wrap_mw_osThreadCreate`では、名前がBaserateのタスクに限って次の呼び出しを使います。

```cpp
xTaskCreatePinnedToCore(task, def->name, def->stackdepth,
                       argument, def->priority, &def->taskhandle, 1);
```

最後の`1`がCPU1です。CPU0の非同期タスクは、各ファイルの`xTaskCreatePinnedToCore(..., 0)`で指定しています。

| タスク | ソース |
|---|---|
| ToF | [`vl53l3cx_bottom_official128_wrapper.cpp`](../src/vl53l3cx/vl53l3cx_bottom_official128_wrapper.cpp) |
| 磁気 | [`bmm150_logger.cpp`](../src/bmm150/bmm150_logger.cpp) |
| 電池 | [`official_battery.cpp`](../src/official_battery.cpp) |
| 無線 | [`imu_tx.cpp`](../src/imu_tx.cpp) |
| USB | [`official_usb.cpp`](../src/official_usb.cpp) |
| LED・ブザー | [`official_status.cpp`](../src/official_status.cpp) |

MathWorksのインストール先は変更していません。元の`mw_osThreadCreate`はCPU未固定の`xTaskCreate`を使っていたため、`ARDUINO_RUNNING_CORE=1`だけではBaserateの固定になりませんでした。

## 実測で確認すること

USB診断の`SFRUNTIME core=1`がBaserateの実行CPU、`SFTASK`がstep全体の処理時間です。`SFTIMING`はモデル内の計測点までで、その後の処理を含まないため、周期余裕の判定には全タスクの値も使います。

Revision 1803ではCPU1固定後の90秒待機と約18秒のプロペラなしMode 2試験で再起動はありませんでした。ただし2.5 msを超える処理とタイマー取りこぼしが残っています。既存SDKはCPU0のidle watchdogのみを監視しているため、CPU1へ移して再起動しないことだけで周期問題の解決とは判断しません。[調査と確認範囲](history/README.md)

CPU固定を維持した区間計測版1804では、ユーザーから「問題は解消され、安定して飛びました」と実飛行結果の報告を得ました。[実飛行の記録](history/README.md)。USB机上計測での周期超過は、飛行結果とは別に記録しています。
