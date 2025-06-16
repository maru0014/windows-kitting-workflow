# Slack スレッド機能ガイド

## 概要

Windows Kitting WorkflowのSlack通知機能では、PCごとにスレッドを分けて通知を送信することができます。これにより、複数のPCで同時にセットアップを実行しても、各PCの進捗を個別のスレッドで追跡できます。

## 機能の仕組み

1. **初回通知**: PCから最初の通知がSlack chat.postMessage APIで送信され、返されるタイムスタンプ（ts）を保存
2. **2回目以降**: 保存されたtsをthread_tsパラメータとして使用してスレッドに返信
3. **PC識別**: PCシリアル番号（BIOS情報から取得）を使用してPCを識別
4. **API使用**: Webhook APIではなくchat.postMessage APIを使用（Bot Token認証）

## 設定方法

### notifications.json の設定

```json
{
  "notifications": {
    "providers": {
      "slack": {
        "enabled": true,
        "botToken": "xoxb-YOUR-BOT-TOKEN-HERE",
        "channel": "#kitting-workflow",
        "username": "Kitting-Workflow",
        "iconEmoji": ":robot_face:",
        "thread": {
          "enabled": true,
          "perMachine": true,
          "tsStoragePath": "status/slack_thread_ts.json"
        }
      }
    }
  }
}
```

### 設定項目説明

- **botToken**: Slack Bot Token（xoxb-で始まる）
- **channel**: 通知を送信するSlackチャンネル（#付き）
- **username**: 通知時に表示されるBot名
- **iconEmoji**: 通知時に表示されるアイコン
- **thread.enabled**: スレッド機能の有効/無効
- **thread.perMachine**: PCごとのスレッド分け（trueを推奨）
- **thread.tsStoragePath**: スレッドTSファイルの保存パス

### perMachine機能の詳細

`perMachine`が有効（`true`）の場合：

- **ユーザー名の自動変更**: 通知時のユーザー名にPCのシリアル番号が自動的に追加されます
  - 例: `Kitting-Workflow` → `Kitting-Workflow-ABC123`
- **PC識別の向上**: 同じコンピューター名を持つPCでも、シリアル番号により一意に識別可能
- **スレッド管理**: PCのシリアル番号ベースでスレッドが管理されるため、より確実な分離が可能

PCのシリアル番号が取得できない場合は、コンピューター名がフォールバックとして使用されます。

## Bot Tokenの取得方法

1. **Slack Appの作成**
   - https://api.slack.com/apps にアクセス
   - "Create New App" をクリック
   - "From scratch" を選択

2. **権限の設定**
   - "OAuth & Permissions" に移動
   - 以下のスコープを追加：
     - `chat:write` - メッセージ送信権限
     - `chat:write.public` - パブリックチャンネル投稿権限

3. **Appをワークスペースにインストール**
   - "Install App to Workspace" をクリック
   - 認証を完了

4. **Bot Tokenをコピー**
   - "Bot User OAuth Token" をコピー
   - `xoxb-`で始まるトークンを設定ファイルに記載

## スレッドTSファイル

PCごとのスレッドタイムスタンプは以下のJSON形式で保存されます：

```json
{
  "PC01": "1234567890.123456",
  "PC02": "1234567891.234567",
  "PC03": "1234567892.345678"
}
```

- **キー**: コンピューター名
- **値**: Slackから返されたタイムスタンプ

## 使用例

### 通常の使用
スレッド機能が有効な場合、特別な操作は不要です。WorkflowEngine が自動的にスレッド管理を行います。

### テスト・デバッグ
専用のテストスクリプトを使用してスレッド機能をテストできます：

```powershell
# スレッド情報の表示
.\Test-SlackThread.ps1 -ShowInfo

# テスト通知の送信
.\Test-SlackThread.ps1 -TestNotification

# 特定PCのスレッドTSクリア
.\Test-SlackThread.ps1 -ClearSerial "ABC123"

# 全スレッドTSクリア
.\Test-SlackThread.ps1 -ClearAll
```

## 管理関数

MainWorkflow.ps1内で以下の関数を使用できます：

### Get-SlackThreadTs
指定されたPCのスレッドTSを取得

```powershell
$ts = Get-SlackThreadTs -SerialNumber "ABC123"
```

### Clear-SlackThreadTs
スレッドTSをクリア

```powershell
# 特定PCのクリア（シリアル番号で指定）
Clear-SlackThreadTs -SerialNumber "ABC123"

# 全てクリア
Clear-SlackThreadTs -All
```

### Show-SlackThreadInfo
現在のスレッド情報を表示

```powershell
Show-SlackThreadInfo
```

## 利点

1. **整理された通知**: 各PCの進捗が個別のスレッドで追跡可能
2. **チャンネルの整理**: メインチャンネルに多数の通知が混在することを防止
3. **履歴の管理**: PC単位での作業履歴が一目で確認可能
4. **効率的な確認**: 特定のPCの進捗のみを追跡可能

## トラブルシューティング

### スレッドが作成されない

**原因**: 
- Slack Bot Tokenが無効または未設定
- 必要なSlack権限（chat:write）がない
- thread.enabled が false
- JSON設定ファイルの構文エラー
- チャンネルが存在しないか、Botがチャンネルにアクセスできない

**対処法**:
```powershell
# 設定確認
.\Test-SlackThread.ps1 -ShowInfo

# Bot Token確認
# notifications.jsonのbotTokenが xoxb- で始まることを確認

# テスト通知送信
.\Test-SlackThread.ps1 -TestNotification
```

### 古いスレッドTSによる問題

**原因**: 
- 過去のスレッドTSが残っている
- チャンネルやワークスペースが変更された

**対処法**:
```powershell
# スレッドTSクリア
.\Test-SlackThread.ps1 -ClearAll

# 新しい通知でスレッド再作成
.\Test-SlackThread.ps1 -TestNotification
```

### スレッドTSファイルの破損

**症状**: JSON読み込みエラー

**対処法**:
```powershell
# ファイル削除
Remove-Item "status\slack_thread_ts.json" -Force

# 新しいファイルで再開
.\Test-SlackThread.ps1 -TestNotification
```

## セキュリティ考慮事項

1. **Bot Tokenの保護**: 設定ファイルのアクセス権限を適切に設定
2. **タイムスタンプの管理**: スレッドTSファイルへの不正アクセスを防止
3. **ログ情報**: 機密情報が通知に含まれないよう注意
4. **Bot権限**: 必要最小限の権限（chat:write）のみを付与

## 設定無効化

スレッド機能を無効にしたい場合：

```json
{
  "notifications": {
    "providers": {
      "slack": {
        "thread": {
          "enabled": false
        }
      }
    }
  }
}
```

この設定により、従来通りの単発通知に戻ります。
