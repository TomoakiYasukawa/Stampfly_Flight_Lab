# ログ互換性の比較基準

`LegacyBasicLogger.m`は400 Hzへの負荷分散前の50 Hzロガーです。`verify_distributed_telemetry`がこのフォルダーを一時的に検索パスへ追加し、生成byte列・保存時刻・Sequenceを比較します。通常のモデル・アプリからは参照しません。
