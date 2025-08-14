## copy_path_with_network ガイド（共有コピーと資格情報・{pcname}/{today}/{now} 対応）

このドキュメントでは、Windows Kitting Workflow に追加された以下の機能について説明します。

- プレーンテキストの資格情報（JSON 経由）を実行時に PSCredential へ変換して使用
- コピー先・コピー元パスで `{pcname}` プレースホルダを実PC名に展開
- パスで `{today}`/`{now}` プレースホルダを実行日/時刻に展開（`{today}`: YYYY-MM-DD, `{now}`: YYYY-MM-DD_HH-mm-ss、ゼロ埋め・大/小文字不問）
- 相対パスをワークフロー ルート基準で解決
- ワークフロー終盤で `logs` と `backup` を共有フォルダへアップロードする最終ステップ

### 対象スクリプト

- `scripts/setup/copy-path-with-network.ps1`

### 追加パラメータ（テキスト資格情報）

- 宛先用: `-DestinationUsername`, `-DestinationPassword`
- 送信元用: `-SourceUsername`, `-SourcePassword`
- 共通用: `-Username`, `-Password`

優先順位（高 → 低）

1. 宛先/送信元の個別 `PSCredential`（`-DestinationCredential` / `-SourceCredential`）
2. 宛先/送信元の個別テキスト資格情報（`-DestinationUsername/Password` / `-SourceUsername/Password`）
3. 共通 `PSCredential`（`-Credential`）
4. 共通テキスト資格情報（`-Username/Password`）

注意: セキュリティ上、プレーンテキストのパスワードは推奨されません。代替案は「セキュリティ上の注意」を参照してください。

### プレースホルダ

- `{pcname}`: 実行端末の `COMPUTERNAME` に展開（例: `DESKTOP-1234`）
- `{today}`: 実行日の `YYYY-MM-DD` に展開（例: `2025-08-14`）
- `{now}`: 実行日時の `YYYY-MM-DD_HH-mm-ss` に展開（例: `2025-08-14_13-05-09`）

補足: いずれも大/小文字は不問（例: `{PCNAME}`, `{Today}`, `{NOW}` も可）。

### 相対パスの解決

`SourcePath` / `DestinationPath` が UNC でも絶対パスでもない場合、ワークフローのルート（`MainWorkflow.ps1` のあるディレクトリ）を基準に解決します。

### スクリプトの使い方（単体実行例）

```powershell
# 宛先が UNC、テキスト資格情報を使用
./scripts/setup/copy-path-with-network.ps1 `
  -SourcePath logs `
  -DestinationPath "\\192.168.0.1\share\logs-{pcname}\{today}" `
  -DestinationUsername "domain\user" `
  -DestinationPassword "P@ssw0rd!" `
  -Recurse -Force

# 送信元が UNC、共通テキスト資格情報を使用
./scripts/setup/copy-path-with-network.ps1 `
  -SourcePath "\\filesrv\in\report.txt" `
  -DestinationPath backup\report.txt `
  -Username "domain\user" `
  -Password "P@ssw0rd!"
```

```powershell
# {now} を使ってファイル名に日時を付与
./scripts/setup/copy-path-with-network.ps1 `
  -SourcePath logs\latest.txt `
  -DestinationPath "\\192.168.0.1\share\logs-{pcname}\log-{now}.txt" `
  -Username "domain\user" `
  -Password "P@ssw0rd!"
```

### ワークフローへの組み込み（最終ステップ）

`config/workflow.json` の末尾に以下 2 ステップが追加されています。IP/資格情報は環境に合わせて編集してください。

```json
{
  "id": "copy-logs-to-share",
  "name": "ログファイル共有コピー",
  "script": "scripts/setup/copy-path-with-network.ps1",
  "type": "powershell",
  "runAsAdmin": false,
  "parameters": {
    "SourcePath": "logs",
    "DestinationPath": "\\\\192.168.x.xxx\\share\\logs-{pcname}",
    "Username": "xxx",
    "Password": "xxxxxxxx",
    "Recurse": true,
    "Force": true
  },
  "completionCheck": { "type": "file", "path": "status/copy-logs-to-share.completed" },
  "timeout": 300,
  "retryCount": 1,
  "rebootRequired": false,
  "dependsOn": ["disable-autologin"],
  "onError": "continue"
},
{
  "id": "copy-backup-to-share",
  "name": "バックアップ共有コピー",
  "script": "scripts/setup/copy-path-with-network.ps1",
  "type": "powershell",
  "runAsAdmin": false,
  "parameters": {
    "SourcePath": "backup",
    "DestinationPath": "\\\\192.168.x.xxx\\share\\backup-{pcname}",
    "Username": "xxx",
    "Password": "xxxxxxxx",
    "Recurse": true,
    "Force": true
  },
  "completionCheck": { "type": "file", "path": "status/copy-backup-to-share.completed" },
  "timeout": 300,
  "retryCount": 1,
  "rebootRequired": false,
  "dependsOn": ["copy-logs-to-share"],
  "onError": "continue"
}
```

### セキュリティ上の注意

- JSON でのプレーンテキスト `Password` は漏えいリスクがあります。可能なら以下を検討してください。
  - 共有先にあらかじめコンピューター/アカウントのアクセス許可を付与し、資格情報不要でアクセス
  - 実行時に `Get-Credential` を用い `-DestinationCredential`/`-SourceCredential` として渡す
  - Windows 資格情報マネージャーや DPAPI で暗号化した秘密の読み出し（カスタム実装）
- リンターはテキスト `Password` パラメータに警告を出します（仕様上許容しつつ注意喚起）。

### トラブルシューティング

- アクセス拒否: 資格情報が適切か、共有の NTFS/共有権限が揃っているか確認
- パスが見つからない: 相対パスはワークフロールート基準です。UNC/絶対に修正して再試行
- マッピング失敗: UNC を PSDrive に一時マウントしています。既存ドライブレター競合時は開放後に再試行
- 大量ファイル: `-Recurse` の有無、必要に応じて再実行（冪等）
