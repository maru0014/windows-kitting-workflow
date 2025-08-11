# ローカルユーザー削除ガイド

対象スクリプト: `scripts/setup/remove-user.ps1`

## 概要
指定したローカルユーザーが現在ログイン中でないこと、保護対象アカウントでないことを確認し、ローカルユーザーおよび対応するユーザープロファイルを削除します。必要に応じて強制実行（`-Force`）を行います。

## 前提条件
- 管理者権限が必須
- 対象はローカルアカウント（組み込みの保護アカウントは除外）
- ログは共通ログ機構により `logs/remove-user.log` へ出力されます

## 使い方

```powershell
# ユーザー tempuser を削除（推奨: ログオフ済みで実行）
.
\remove-user.ps1 -UserName "tempuser"

# ログオン中でも試行（強制）。必要に応じてサービス停止・サインアウトなどの並行対処が必要になる場合あり
.
\remove-user.ps1 -UserName "tempuser" -Force

# ヘルプ表示
.
\remove-user.ps1 -Help
```

## パラメータ
- `-UserName <string>`: 対象ローカルユーザー名（必須）
- `-Force` (switch): 対象ユーザーがログオン中でも処理を試行
- `-Help` (switch): ヘルプ表示

## 動作詳細
1. 権限確認（管理者でない場合は終了）。
2. 現在ログイン中ユーザーと一致しないかを検証。
3. 保護対象アカウントを拒否（`Administrator`, `Guest`, `DefaultAccount`, `WDAGUtilityAccount`）。
4. `quser` または WMI/CIM によりログオン中判定。`-Force` が無ければログオン中は中断。
5. ユーザー削除:
   - `Get-LocalUser` で存在確認 → `Disable-LocalUser` → `Remove-LocalUser`。
6. プロファイル削除:
   - `Win32_UserProfile` から対象 SID or `C:\Users\<name>` 直下を特定。
   - `Special`/ローミング構成は除外、`Loaded`（使用中）はスキップ。
   - `Invoke-CimMethod Delete`、失敗時は最終手段としてディレクトリ削除を試行。

## 出力・ログ・完了マーカー
- ログに各処理結果を出力。
- 完了マーカー JSON（`remove-user-<name>.completed.json` 相当）が作成され、以下を含みます。
  - `completedAt`, `userName`, `userRemoved`, `profileRemoved`, `forced`

## 終了コード
- 0: ユーザーまたはプロファイルのいずれかを削除できた
- 1: 権限不足・条件未満・削除対象なしなどで処理不成立

## 注意事項 / ベストプラクティス
- データ消失の可能性があるため、必要に応じてバックアップを取得してください。
- ログオン中プロファイルは削除できません。`-Force` は削除試行を継続しますが、使用中ロックにより失敗する場合があります。
- 組織運用では削除前に退職/利用終了フロー・データ保全方針に従ってください。

## トラブルシューティング
- 「権限不足」: 管理者で PowerShell を起動し直してください。
- 「削除できない」: 端末をサインアウト/再起動し、再度実行。該当ユーザーのプロセス・サービスを停止してください。
- 詳細はログ（`remove-user.log`）を参照してください。
