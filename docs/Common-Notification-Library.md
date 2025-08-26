# 共通通知ライブラリの実装

## 概要

通知機能を共通化し、コードの重複を排除するため、`Common-NotificationFunctions.ps1`ライブラリを実装しました。

## 実装内容

### 📂 ファイル構成

```
scripts/
├── Common-NotificationFunctions.ps1  # 共通通知ライブラリ（新規）
├── setup/
│   └── setup-bitlocker.ps1          # 更新済み（共通ライブラリ使用）
└── MainWorkflow.ps1                  # 更新済み（共通ライブラリ使用）
```

### 🔄 変更点

1. **MainWorkflow.ps1の通知関数を抽出**
   - Slack/Teams通知関数を共通ライブラリに移動
   - 重複コードを排除し、メンテナンス性を向上

2. **共通ライブラリの作成**
   - `Common-NotificationFunctions.ps1`を新規作成
   - 統一されたインターフェースで通知機能を提供

3. **BitLockerスクリプトの改善**
   - 独自の通知実装を削除
   - 共通ライブラリを使用するように更新

## 🔧 使用方法

### 1. ライブラリの読み込み

```powershell
# 共通通知ライブラリの読み込み
. (Join-Path $PSScriptRoot "scripts\Common-NotificationFunctions.ps1")
```

### 2. 通知設定の初期化

```powershell
# 通知設定ファイルの読み込み
$configPath = "config\notifications.json"
Import-NotificationConfig -ConfigPath $configPath
```

### 3. 通知の送信（統合インターフェース）

```powershell
# イベント種別を指定して送信（notifications.json のテンプレートを使用）
Send-Notification -EventType "onWorkflowComplete" -Variables @{
    totalDuration   = "00:12:34"
    sessionDuration = "00:12:34"
}

# 任意のカスタムメッセージを送る（テンプレートを使わない）
Send-Notification -EventType "onWorkflowStart" -CustomMessage "🚀 セットアップを開始しました"
```

## 📋 提供される関数

### Core Functions

| 関数名 | 説明 |
|--------|------|
| `Import-NotificationConfig` | 通知設定ファイルを読み込み |
| `Send-Notification` | 統合通知送信（Slack/Teams/TTS対応） |
| `Get-PCSerialNumber` | PCシリアル番号取得 |
| `Get-PreferredMachineName` | CSVの `machine_list.csv` からPC名を解決（無ければ `$env:COMPUTERNAME`） |
| `Get-OrCreate-MachineId` | Teams用のマシンIDを生成/取得 |

### Slack Functions

| 関数名 | 説明 |
|--------|------|
| `Send-SlackNotification` | Slack専用通知送信 |

### Teams Functions

| 関数名 | 説明 |
|--------|------|
| `Send-TeamsNotification` | Teams専用通知送信（Power Automate経由・新スレッド化方式） |

### TTS Functions

| 関数名 | 説明 |
|--------|------|
| `Send-TTSNotification` | ローカル音声合成で読み上げ（System.Speech または SAPI COM） |

### Utility Functions

| 関数名 | 説明 |
|--------|------|
| `Clear-MachineIds` | マシンIDをクリア（テスト用） |

## 🔧 設定ファイル

通知設定は従来通り`config/notifications.json`を使用します：

```json
{
  "notifications": {
    "enabled": true,
    "providers": {
      "slack": {
        "enabled": true,
        "webhook": {
          "url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
        },
        "thread": {
          "enabled": true,
          "perMachine": true,
          "tsStoragePath": "status/slack_thread_ts.json"
        }
      },
      "teams": {
        "enabled": true,
        "flowUrl": "https://your-teams-flow-url-here",
        "teamId": "your-team-id",
        "channelId": "your-channel-id",
        "idStoragePath": "status/teams_machine_ids.json"
      },
      "tts": {
        "enabled": true,
        "preferJapanese": true,
        "voiceName": "",
        "rate": 0,
        "volume": 100,
        "speakEvents": [
          "onWorkflowStart",
          "onWorkflowComplete",
          "onWorkflowError",
          "onWorkflowSuccess",
          "onWorkflowFailure",
          "onWorkflowCriticalError"
        ]
      }
    }
  }
}
```

### 変数の解決と `machineName` の扱い

- `Send-Notification` 実行時、`Variables.machineName` を明示しない場合でも、内部で自動的に設定されます。
  - 優先順: `config/machine_list.csv` のシリアル一致行の `Machine Name` → なければ `$env:COMPUTERNAME`。
  - この解決は `Get-PreferredMachineName` により行われます。`Serial Number` は空白・記号を除去して突合します。
- `Variables.timestamp` は `yyyy-MM-dd HH:mm:ss` で自動付与されます。

補足:
- `preferJapanese`: true の場合、`ja-*` の音声があれば優先します。
- `voiceName`: 特定の音声名を優先選択します（指定時はこちらが優先）。
- `rate`: -10..10、`volume`: 0..100。
- `speakEvents`: 読み上げ対象イベントを限定可能（空にすると全イベント対象）。

## 🚀 利点

### 1. コードの統一性
- 全スクリプトで統一された通知インターフェース
- 設定の一元管理

### 2. メンテナンス性向上
- 通知機能の修正は1箇所のみ
- バグ修正の影響範囲を限定

### 3. 機能の一貫性
- 全スクリプトで同じ通知機能を利用
- スレッド機能、エンコーディング対応などを統一

## 🔄 移行されたスクリプト

### MainWorkflow.ps1
- 古い通知関数群を削除
- 共通ライブラリの読み込みを追加
- 初回通知（`onWorkflowStart`）の送信は `initialize.ps1` に移行

### setup-bitlocker.ps1
- `Send-BitLockerNotification`関数を削除
- 共通ライブラリの`Send-Notification`を使用
- より簡潔で統一されたコードに改善

## 📝 今後の計画

1. **他のスクリプトへの適用**
   - 他のsetupスクリプトも共通ライブラリを使用するように更新
   - 通知機能の統一を完了

2. **機能拡張**
   - 新しい通知プロバイダー（Discord、Email等）の追加
   - 通知テンプレートシステムの実装

3. **テスト強化**
   - 共通ライブラリの単体テスト追加
   - 統合テストの拡充

## 🐛 トラブルシューティング

### 共通ライブラリが読み込めない場合

```powershell
# パスを確認
$libPath = Join-Path $PSScriptRoot "scripts\Common-NotificationFunctions.ps1"
Write-Host "ライブラリパス: $libPath"
Test-Path $libPath
```

### 通知が送信されない場合

```powershell
# 設定確認
if ($Global:NotificationConfig) {
    Write-Host "通知設定: 読み込み済み"
} else {
    Write-Host "通知設定: 未読み込み"
    Import-NotificationConfig
}

# TTS を個別に確認
Send-TTSNotification -Message "テスト読み上げです" -ErrorAction SilentlyContinue
```

## 📚 関連ドキュメント

- [Teams通知新スレッド化方式ガイド](Teams-Notification-V2-Guide.md)
- [Slackスレッドガイド](Slack-Thread-Guide.md)
- [テストガイド](Testing-Guide.md)

## 仕様補足: 初回通知のタイミングとステータスファイル

- 初回通知（`onWorkflowStart`）は `scripts/setup/initialize.ps1` 実行時に送信されます。
  - ユーザーがダイアログでPC名を修正した場合、CSVへ反映後の最新PC名で通知されます。
  - 作成されるステータス:
    - `status/workflow-started.completed`
    - `status/workflow-initial-start.json`（未存在時のみ作成）
