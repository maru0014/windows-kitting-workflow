# カスタマイズガイド

## 概要

Windows Kitting Workflowは高度にカスタマイズ可能なシステムです。
このドキュメントでは、ワークフローの設定、カスタムスクリプトの追加、設定ファイルの編集方法について説明します。

## 目次

1. [ワークフロー設定のカスタマイズ](#ワークフロー設定のカスタマイズ)
2. [Windows Updateステップの設定](#windows-updateステップの設定)
3. [カスタムスクリプトの追加](#カスタムスクリプトの追加)
4. [通知設定](#通知設定)
5. [環境別設定](#環境別設定)

詳細なWindows Update設定については[Windows Updateガイド](Windows-Update-Guide.md)を参照してください。

## ワークフロー設定のカスタマイズ

### workflow.json の構造

```json
{
  "workflow": {
    "name": "Windows11AutoSetup",
    "version": "1.0",
    "description": "Windows 11の完全自動セットアップワークフロー",
    "steps": [
      {
        "id": "init",
        "name": "初期化処理",
        "script": "scripts/setup/initialize.ps1",
        "type": "powershell",
        "runAsAdmin": true,
        "completionCheck": {
          "type": "file"
        }
      },
      {
        "id": "install-winget",
        "name": "wingetセットアップ",
        "script": "scripts/setup/install-winget.ps1",
        "type": "powershell",
        "dependsOn": ["windows-update"]
      }
    ]
  }
}
```

### ステップ設定の詳細

#### 必須フィールド
- **id**: ステップの一意識別子
- **name**: ステップの表示名
- **script**: 実行するスクリプトファイルのパス
- **type**: スクリプトの種類（powershell, batch）

#### オプションフィールド
- **runAsAdmin**: 管理者権限で実行するかどうか（true/false）
- **dependsOn**: 依存するステップのID（配列）
- **timeout**: タイムアウト時間（秒）
- **completionCheck**: 完了判定の設定

### 完了判定の設定

#### ファイル存在チェック
```json
"completionCheck": {
  "type": "file"
}
```

#### レジストリ値チェック
```json
"completionCheck": {
  "type": "registry",
  "path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion",
  "name": "ProgramFilesDir",
  "expectedValue": "C:\\Program Files"
}
```

#### プロセス存在チェック
```json
"completionCheck": {
  "type": "process",
  "processName": "winget"
}
```

## カスタムスクリプトの追加

### 1. スクリプトファイルの配置

```
scripts/
├── setup/
│   ├── your-custom-script.ps1
│   └── another-setup-task.bat
└── cleanup/
    └── your-cleanup-script.ps1
```

### 2. PowerShellスクリプトの基本テンプレート

```powershell
# your-custom-script.ps1

param(
    [string]$ConfigPath = "config\custom-config.json",
    [switch]$DryRun,
    [switch]$Force
)

# ログ関数の読み込み
. "$PSScriptRoot\..\Common-LogFunctions.ps1"

try {
    Write-Log "カスタムスクリプト開始" -Level "INFO"
    
    # メイン処理
    if ($DryRun) {
        Write-Log "ドライランモード：実際の処理は実行されません" -Level "INFO"
        return
    }
    
    # 実際の処理をここに記述
    Write-Log "カスタム処理を実行中..." -Level "INFO"
    
    # 完了判定は MainWorkflow 側が行います（スクリプト内のマーカー作成は不要）
    
    Write-Log "カスタムスクリプト完了" -Level "INFO"
}
catch {
    Write-Log "エラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
```

### 3. workflow.jsonへの追加

```json
{
  "id": "custom-step",
  "name": "カスタムタスク",
  "script": "scripts/setup/your-custom-script.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "completionCheck": {
    "type": "file"
  },
  "dependsOn": ["install-winget"],
  "timeout": 600
}
```

## 通知設定のカスタマイズ

### notifications.json の設定

```json
{
  "notifications": {
    "enabled": true,
    "webhook": {
      "url": "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
      "type": "slack"
    },
    "events": {
      "onStart": true,
      "onStepComplete": true,
      "onError": true,
      "onComplete": true
    },
    "messageFormat": {
      "success": "✅ {stepName} が完了しました",
      "error": "❌ {stepName} でエラーが発生しました: {errorMessage}",
      "start": "🚀 ワークフロー '{workflowName}' を開始しました"
    }
  }
}
```

### Slack Webhook設定

1. **Slack Appの作成**
   - Slack API (https://api.slack.com/apps) にアクセス
   - 「Create New App」をクリック
   - 「From scratch」を選択

2. **Incoming Webhookの有効化**
   - 「Incoming Webhooks」を選択
   - 「Activate Incoming Webhooks」をONに設定
   - 「Add New Webhook to Workspace」をクリック

3. **Webhook URLの取得**
   - 投稿先チャンネルを選択
   - 生成されたWebhook URLをコピー
   - `notifications.json`の`url`に設定

### Microsoft Teams設定

```json
{
  "notifications": {
    "enabled": true,
    "providers": {
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

## Slack通知のスレッド機能

Slack通知では、PCごとにスレッドを分けて通知を送信できます。

### 基本設定
```json
{
  "notifications": {
    "providers": {
      "slack": {
        "enabled": true,
        "botToken": "xoxb-YOUR-BOT-TOKEN-HERE",
        "channel": "#kitting-workflow",
        "thread": {
          "enabled": true,
          "perMachine": true
        }
      }
    }
  }
}
```

### 利点
- 複数PCの同時セットアップ時の通知整理
- PC単位での進捗追跡
- チャンネルの可読性向上

**詳細設定とトラブルシューティングについては [Slackスレッドガイド](Slack-Thread-Guide.md) を参照してください。**

## 環境別設定の管理

### 開発環境用設定

```json
{
  "workflow": {
    "name": "Development Setup",
    "steps": [
      {
        "id": "dev-tools",
        "name": "開発ツールインストール",
        "script": "scripts/setup/install-dev-tools.ps1"
      }
    ]
  }
}
```

### 本番環境用設定

```json
{
  "workflow": {
    "name": "Production Setup",
    "steps": [
      {
        "id": "security-hardening",
        "name": "セキュリティ強化",
        "script": "scripts/setup/security-hardening.ps1"
      }
    ]
  }
}
```

### 設定ファイルの切り替え

```powershell
# 開発環境での実行
.\MainWorkflow.ps1 -ConfigPath "config\workflow-dev.json"

# 本番環境での実行
.\MainWorkflow.ps1 -ConfigPath "config\workflow-prod.json"
```

## 高度なカスタマイズ

### 条件付き実行

```json
{
  "id": "conditional-step",
  "name": "条件付きステップ",
  "script": "scripts/setup/conditional-task.ps1",
  "conditions": [
    {
      "type": "os-version",
      "value": "Windows 11"
    },
    {
      "type": "registry",
      "path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion",
      "name": "ProductName",
      "operator": "contains",
      "value": "Pro"
    }
  ]
}
```

### 並列実行の設定

```json
{
  "id": "parallel-group",
  "name": "並列実行グループ",
  "type": "group",
  "parallel": true,
  "steps": [
    {
      "id": "task1",
      "script": "scripts/setup/task1.ps1"
    },
    {
      "id": "task2", 
      "script": "scripts/setup/task2.ps1"
    }
  ]
}
```

### 再試行設定

```json
{
  "id": "retry-step",
  "name": "再試行可能ステップ",
  "script": "scripts/setup/network-dependent-task.ps1",
  "retry": {
    "maxAttempts": 3,
    "delaySeconds": 30,
    "onFailure": "continue"
  }
}
```

## Windows Updateステップの設定

Windows Updateステップでは、アップデートの範囲やインストール方法をカスタマイズできます。

### 基本パラメータ
- **MicrosoftUpdate**: Microsoft Updateサービスを含めるかどうか
- **Force**: 強制実行フラグ（デフォルト: true）
- **RebootIfRequired**: 必要時の自動再起動（デフォルト: true）
- **KBArticleID**: 特定のKB番号のみをインストール
- **NotKBArticleID**: 除外するKB番号の指定

### 設定例（抜粋）

```json
{
  "id": "windows-update",
  "parameters": {
    "MicrosoftUpdate": true,
    "Force": true,
    "RebootIfRequired": true,
    "NotKBArticleID": ["KB5034763"]
  }
}
```

**詳細な設定方法、トラブルシューティング、セキュリティ考慮事項については [Windows Updateガイド](Windows-Update-Guide.md) を参照してください。**

## カスタムログ関数の作成

### 独自ログ関数の追加

```powershell
# scripts/Custom-LogFunctions.ps1

function Write-CustomLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Category = "CUSTOM"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] [$Category] $Message"
    
    # コンソール出力
    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO"  { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
    
    # ファイル出力
    $logPath = "logs\custom.log"
    Add-Content -Path $logPath -Value $logMessage -Encoding UTF8
}
```

## 関連ドキュメント
- [メインREADME](../README.md)
- [レジストリ設定ガイド](Registry-Configuration.md)
- [アプリケーション管理ガイド](Application-Management.md)
- [トラブルシューティングガイド](Troubleshooting.md)
