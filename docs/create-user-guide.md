# ローカルユーザー作成ガイド（create-user.ps1）

このガイドでは、`scripts/setup/create-user.ps1` を用いて、PC のシリアル番号に紐づく `config/machine_list.csv` からユーザーを自動作成する方法、または引数で直接ユーザー名・パスワードを指定して作成する方法を説明します。ユーザーは指定グループに追加され、デフォルトでは `Administrators` に追加されます。

## 前提条件
- 管理者権限で実行すること
- `config/machine_list.csv` に以下の列があること:
  - `Serial Number`, `Machine Name`, `User Name`, `User Password`, `Office License Type`, `Office Product Key`
- `scripts/Common-LogFunctions.ps1`, `scripts/Common-WorkflowHelpers.ps1` が存在すること

## 使い方

### 1) CSV 参照で自動作成（推奨）
PC のシリアル番号に一致する行から `User Name` と `User Password` を読み取り、ユーザーを作成/更新します。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1
```

### 2) 引数で直接指定（引数が優先）
`-UserName` と `-Password` を渡した場合、CSV ではなく引数の値で作成/更新します。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1 -UserName "user001" -Password "User1234"
```

### 3) グループ追加
`-Groups` でローカルグループを配列で指定できます。デフォルトは `Administrators`。`Administrator` 単数指定は自動で `Administrators` に正規化されます。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1 -UserName "user001" -Password "User1234" -Groups "Administrators","Users"
```

### 4) CSV パスの変更
別の CSV を使う場合は `-ConfigPath` を指定してください（相対パスはワークフローのルート起点で解決）。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1 -ConfigPath "config\\machine_list.csv"
```

## 動作仕様
- 引数 `UserName`/`Password` が両方渡された場合に限り、引数を優先
- 引数未指定時は `machine_list.csv` からシリアル番号一致行を検索して利用
- 既存ユーザーが存在する場合は有効化し、パスワードを更新
- 指定グループに既に所属している場合はスキップ
- 完了時に `status/create-user.completed` を作成（JSON、作成時刻・ユーザー名・グループ・ソースを記録）

## エラーハンドリング
- 管理者権限でない場合はエラー終了
- シリアル番号取得不可、CSV 未読込、対象行なし、ユーザー/パスワード空欄などはエラー終了
- グループが存在しない場合は該当グループのみ警告し、他を継続

## ワークフロー統合
`config/workflow.json` に以下のサンプルステップを追加済みです。`rename-computer` 完了後に実行されます。

```json
{
  "id": "create-user",
  "name": "ローカルユーザー作成",
  "description": "machine_list.csvまたは引数に基づきローカルユーザーを作成し、グループに追加",
  "script": "scripts/setup/create-user.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "ConfigPath": "config/machine_list.csv",
    "UserName": "",
    "Password": "",
    "Groups": ["Administrators"]
  },
  "completionCheck": {
    "type": "file",
    "path": "status/create-user.completed"
  },
  "timeout": 180,
  "retryCount": 1,
  "rebootRequired": false,
  "dependsOn": ["rename-computer"],
  "onError": "continue"
}
```

## セキュリティ注意
- コマンドライン引数にパスワードを渡す場合は履歴やログに残る可能性があります。可能であれば CSV 運用または別の安全な資格情報管理方法をご検討ください。
- スクリプト内部ではパスワードを `SecureString` に変換してから `New-LocalUser`/`Set-LocalUser` に渡しています。

---
最終更新: 2025-08-24
