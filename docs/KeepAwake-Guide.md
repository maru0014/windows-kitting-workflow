# KeepAwake ガイド（実行中のロック/スリープ抑止）

Windows Kitting Workflow では、長時間の処理中にロックやスリープ、画面オフが発生しないよう、Windows 公式 API `SetThreadExecutionState` を用いた抑止機構を提供します。

## 実装概要

- 追加ファイル: `scripts/Common-KeepAwake.ps1`
- 提供関数:
  - `Start-KeepAwake [-DisplayRequired]`: 抑止を開始（`-DisplayRequired` で画面オフ抑止も有効）
  - `Stop-KeepAwake`: 抑止を解除
- 組み込み: `MainWorkflow.ps1` でワークフロー実行を `try/finally` で囲み、開始時に `Start-KeepAwake -DisplayRequired`、終了時に `Stop-KeepAwake` を必ず呼ぶ実装

## 使い方（任意スクリプトでの利用例）

```powershell
. (Join-Path $PSScriptRoot "scripts\Common-KeepAwake.ps1")
Start-KeepAwake -DisplayRequired
try {
	# 長時間の処理
}
finally {
	Stop-KeepAwake
}
```

## 技術詳細

- API: `kernel32!SetThreadExecutionState`
- 有効化フラグ: `ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED`
- 解除: `ES_CONTINUOUS` のみを渡してフラグをクリア

## 注意事項（制限）

- 明示ロック（Win+L）、RDP 切断、厳格な GPO（機械の非アクティブ制限）は抑止できません。
- 画面オフは許容でスリープのみ防ぎたい場合、`-DisplayRequired` を外してください。
- PowerShell ホストがクラッシュした場合、状態が残ることがあります。再実行やサインアウト/再起動で解消します。

## トラブルシューティング

- 効かない場合はドメイン GPO を確認。`presentationsettings /start` でも効果がなければポリシーの可能性が高いです。
- ログ: `logs\workflow.log` にワークフローの開始/終了ログが記録されます。

---
最終更新: 2025-09-18
