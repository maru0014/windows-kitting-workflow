# Teams通知機能の改善実装

## 実装内容

### 1. 日本語エンコード対策

Teams通知送信時に、Slack通知と同様のUTF-8エンコーディング処理を追加しました：

```powershell
# 日本語文字化け対策
$jsonPayload = $payload | ConvertTo-Json -Depth 10
$convertedText = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

# Content-Typeにcharset=utf-8を明示
$response = Invoke-RestMethod -Uri $teamsConfig.webhook.url -Method POST -Body $convertedText -ContentType "application/json; charset=utf-8"
```

### 2. スレッド機能の実装

Teams通知でも同一シリアル番号のPCからの通知を疑似スレッドとして関連付ける機能を追加しました：

#### 設定ファイル（config/notifications.json）の変更
```json
"teams": {
  "enabled": false,
  "webhook": {
    "url": "https://outlook.office.com/webhook/YOUR/TEAMS/WEBHOOK"
  },
  "thread": {
    "enabled": true,
    "perMachine": true,
    "tsStoragePath": "status/teams_thread_ts.json",
    "_comment": "perMachineが有効な場合、同じシリアル番号のPCからの通知は疑似スレッドとして関連付けられます"
  }
}
```

#### 実装されたスレッド機能
- PCのシリアル番号ベースでのスレッドID管理
- 初回投稿時に新しいスレッドIDを生成（GUIDの一部を使用）
- 継続投稿時にはスレッドIDを表示して関連付け

### 3. 追加された管理関数

#### Teams用スレッド管理関数
- `Clear-TeamsThreadTs` : TeamsスレッドTSをクリア
- `Get-TeamsThreadTs` : TeamsスレッドTSを取得
- `Show-TeamsThreadInfo` : Teamsスレッド情報を表示

#### テスト用関数
- `Test-NotificationFunctions` : 通知機能の動作確認

### 4. テストスクリプトの作成

`Test-Notifications.ps1` スクリプトを作成し、以下の機能を提供：

```powershell
# Slack通知テスト
.\Test-Notifications.ps1 -TestSlack

# Teams通知テスト
.\Test-Notifications.ps1 -TestTeams

# スレッド情報表示
.\Test-Notifications.ps1 -ShowInfo

# スレッドデータクリア
.\Test-Notifications.ps1 -ClearThreads

# 全ての機能をテスト
.\Test-Notifications.ps1 -All
```

## 使用方法

### 1. 設定ファイルの更新
`config/notifications.json` でTeams通知を有効化し、Webhook URLを設定してください：

```json
"teams": {
  "enabled": true,
  "webhook": {
    "url": "YOUR_ACTUAL_TEAMS_WEBHOOK_URL"
  },
  "thread": {
    "enabled": true,
    "perMachine": true
  }
}
```

### 2. 動作確認
テストスクリプトを使用して動作確認を行ってください：

```powershell
# 設定情報の確認
.\Test-Notifications.ps1 -ShowInfo

# Teams通知テスト（日本語エンコードとスレッド機能の確認）
.\Test-Notifications.ps1 -TestTeams
```

### 3. スレッド機能の動作

#### perMachine = true の場合
- 同じPCからの通知は同じスレッドIDで関連付けられます
- PCのシリアル番号がキーとして使用されます
- メッセージに `[継続] Thread ID: XXXXXXXX` として表示されます

#### perMachine = false の場合
- 全てのPCからの通知が単一のスレッドIDで関連付けられます

## ファイル構成

```
d:\PowerShell\windows-kitting-workflow\
├── MainWorkflow.ps1              # メインワークフロー（関数追加/修正）
├── Test-Notifications.ps1       # 通知機能テストスクリプト（新規作成）
├── config\
│   └── notifications.json       # 通知設定（Teams設定追加）
└── status\                      # スレッドTS管理ファイル格納先
    ├── slack_thread_ts.json     # Slackスレッド管理
    └── teams_thread_ts.json     # Teamsスレッド管理（新規）
```

## 注意事項

1. **Teams Webhook URL**: 実際のTeams Webhook URLを設定してください
2. **文字エンコーディング**: 日本語が正しく表示されることを確認してください
3. **スレッド管理**: Teamsは真のスレッド機能がないため、疑似スレッドとして実装されています
4. **テスト**: 本番運用前に `Test-Notifications.ps1` でテストを実行してください

## トラブルシューティング

### 問題: 日本語が文字化けする
**解決策**: Content-Typeに `charset=utf-8` が含まれていることを確認

### 問題: スレッド機能が動作しない
**解決策**: 
1. `status/teams_thread_ts.json` ファイルの権限を確認
2. `Show-TeamsThreadInfo` で設定状況を確認
3. `Clear-TeamsThreadTs -All` でスレッドデータをリセット

### 問題: 通知が送信されない
**解決策**: 
1. Webhook URLが正しく設定されていることを確認
2. Teams Webhookが有効であることを確認
3. ネットワーク接続を確認
