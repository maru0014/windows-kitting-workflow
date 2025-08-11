# スタートアップアプリ無効化ガイド

対象スクリプト: `scripts/setup/disable-startup-apps.ps1`

## 概要
指定名に一致する「スタートアップ」登録を無効化します。タスク マネージャーの「スタートアップ アプリ」に表示される項目に対応し、必要に応じてレジストリの `StartupApproved` 配下に無効化エントリを作成します。

## 前提条件
- PowerShell 7 以降推奨
- `-AllUsers` を使う場合は管理者権限が必要
- ログは共通ログ機構により `logs/disable-startup-apps.log`（プロジェクトのログ出力先）へ出力されます

## 使い方

```powershell
# 現在ユーザーの OneDrive 自動起動を無効化
.\n+disable-startup-apps.ps1 -Name "OneDrive"

# Teams を全ユーザー領域も含めて無効化（管理者で実行）
.
\disable-startup-apps.ps1 -Name "Teams" -AllUsers

# ヘルプ表示
.
\disable-startup-apps.ps1 -Help
```

## パラメータ
- `-Name <string>`: 無効化対象名（部分一致）
- `-AllUsers` (switch): HKLM も対象に含め、全ユーザー領域の登録も無効化
- `-Help` (switch): ヘルプ表示

## 動作詳細
1. 次のキーで対象名に部分一致する値を探索します。
   - 現在ユーザー: `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run` / `Run32` / `StartupFolder`
   - 全ユーザー（`-AllUsers` 指定時）: `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run` / `Run32`
2. 値データ（Binary）の先頭バイトを `0x03` に設定して無効化します（既に `0x03` の場合はスキップ）。
3. `StartupApproved` に該当が無いが `...\CurrentVersion\Run` に登録のみ存在する場合は、対応する `StartupApproved\Run/Run32` に「無効状態(0x03)」のエントリを新規作成します。

## 出力・ログ・完了マーカー
- 変更一覧はログにも記録されます。
- 完了マーカー: `Get-CompletionMarkerPath` により JSON が作成されます。
  - ファイル名例: `disable-startup-apps-onedrive.json`、`disable-startup-apps-teams-allusers.json`
  - 含まれる項目: `completedAt`, `name`, `allUsers`, `changedCount`, `changes[]`

## 終了コード
- 0: スクリプト処理が正常終了（該当なしでも処理が完了していれば 0）
- 1: エラー（例: `-AllUsers` 指定で非管理者、例外発生 など）

## 注意事項 / ベストプラクティス
- 無効化後、アプリにより再ログオンや再起動が必要な場合があります。
- `-Name` は部分一致です。意図せぬ一致を避けるため、十分に絞り込んだ名称を推奨します。
- 全ユーザー領域（HKLM）を変更する場合は必ず管理者で実行してください。

## トラブルシューティング
- 「見つからない」: 対象名称の表記揺れを確認。`-AllUsers` が必要なケースもあります。
- 「権限不足」: 管理者で PowerShell を起動し直し、`-AllUsers` を再試行。
- 詳細はログ（`disable-startup-apps.log`）を参照してください。
