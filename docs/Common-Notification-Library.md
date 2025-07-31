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

### 3. 通知の送信

```powershell
# 基本的な通知送信
Send-Notification -Message "設定が完了しました" -Title "BitLocker設定"

# 詳細オプション付き通知
Send-Notification -Message $detailMessage -Title "🔐 BitLocker設定完了" -Level "INFO" -RequiresUserAction $false
```

## 📋 提供される関数

### Core Functions

| 関数名 | 説明 |
|--------|------|
| `Import-NotificationConfig` | 通知設定ファイルを読み込み |
| `Send-Notification` | 統合通知送信（Slack/Teams両対応） |
| `Get-PCSerialNumber` | PCシリアル番号取得 |

### Slack Functions

| 関数名 | 説明 |
|--------|------|
| `Send-SlackNotification` | Slack専用通知送信 |

### Teams Functions

| 関数名 | 説明 |
|--------|------|
| `Send-TeamsNotification` | Teams専用通知送信（アダプティブカード対応） |

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
      }
    }
  }
}
```

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
- シンプルなラッパー関数で互換性を維持

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
```

## 📚 関連ドキュメント

- [Teams通知機能の改善実装](Teams-Notifications-Enhancement.md)
- [Teamsアダプティブカード対応](Teams-Adaptive-Cards-Implementation.md)
- [Slackスレッドガイド](Slack-Thread-Guide.md)
- [テストガイド](Testing-Guide.md)
