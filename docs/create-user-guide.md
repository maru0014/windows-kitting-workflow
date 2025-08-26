# ローカルユーザー作成ガイド（create-user.ps1）

このガイドでは、`scripts/setup/create-user.ps1` を用いて、引数で直接指定するか、`config/local_user.json` からユーザー情報を読み取ってローカルユーザーを作成/更新する方法を説明します。グループは引数または JSON で指定してください（どちらも無い場合はエラー）。

## 前提条件
- 管理者権限で実行すること
- `scripts/Common-LogFunctions.ps1`, `scripts/Common-WorkflowHelpers.ps1` が存在すること
 - `config/local_user.json` が存在する場合は次の形式:
   ```json
   {
     "UserName": "User001",
     "Password": "User1234",
     "Groups": ["Administrators"]
   }
   ```

## 使い方

### 1) JSON 参照で自動作成（推奨）
`config/local_user.json` から `UserName`/`Password`/`Groups` を読み取り、ユーザーを作成/更新します（引数未指定項目のみ補完）。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1
```

### 2) 引数で直接指定（引数が最優先）
`-UserName` と `-Password`、必要に応じて `-Groups` を渡した場合、JSON よりも引数の値が最優先されます。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1 -UserName "user001" -Password "User1234"
```

### 3) グループ指定
グループは必須です。`-Groups`（引数）または `local_user.json` の `Groups` で指定してください。`Administrator` 単数指定は自動で `Administrators` に正規化されます。どちらにも無い場合はエラー終了します。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1 -UserName "user001" -Password "User1234" -Groups "Administrators","Users"
```

### 4) JSON パスの変更
別の JSON を使う場合は `-ConfigPath` を指定してください（相対パスはワークフローのルート起点で解決）。

```bash
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup\create-user.ps1 -ConfigPath "config\\local_user.json"
```

## 動作仕様
- 引数 `UserName`/`Password`/`Groups` が指定された項目は最優先で使用
- 未指定の項目は `local_user.json` から補完
- 引数・JSON のいずれにも必要項目が無い場合はエラー終了
- 既存ユーザーが存在する場合は有効化し、パスワードを更新
- 指定グループに既に所属している場合はスキップ
- 完了判定は MainWorkflow が `status/{id}.completed`（既定: `status/create-user.completed`）を作成します
  - 互換: `completionCheck.path` が設定されている場合、そのパスの存在でも完了とみなされます
  - スクリプト内部での完了マーカー作成は廃止（詳細はログを参照）

## エラーハンドリング
- 管理者権限でない場合はエラー終了
- JSON 未読込、ユーザー/パスワード/グループ未指定時はエラー終了
- グループが存在しない場合は該当グループのみ警告し、他を継続

## ワークフロー統合
`config/workflow.json` に以下のサンプルステップを追加済みです。`rename-computer` 完了後に実行されます。

```json
{
  "id": "create-user",
  "name": "ローカルユーザー作成",
  "description": "引数またはlocal_user.jsonに基づきローカルユーザーを作成し、グループに追加（引数が最優先、次点でJSON。いずれも無ければエラー）",
  "script": "scripts/setup/create-user.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "ConfigPath": "config/local_user.json",
    "UserName": "",
    "Password": "",
    "Groups": ["Administrators"]
  },
  "completionCheck": {
    "type": "file"
  },
  "timeout": 180,
  "retryCount": 1,
  "rebootRequired": false,
  "dependsOn": ["rename-computer"],
  "onError": "continue"
}
```

## セキュリティ注意
- コマンドライン引数にパスワードを渡す場合は履歴やログに残る可能性があります。可能であれば JSON 運用または別の安全な資格情報管理方法をご検討ください。
- スクリプト内部ではパスワードを `SecureString` に変換してから `New-LocalUser`/`Set-LocalUser` に渡しています。

---
最終更新: 2025-08-26（JSON優先ロジックに変更、グループ指定必須化）
