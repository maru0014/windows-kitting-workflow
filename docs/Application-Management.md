# アプリケーション管理ガイド

## 概要

Windows Kitting Workflowでは、JSONベースの設定ファイルを使用してアプリケーションのインストールを管理します。
このドキュメントでは、アプリケーション設定の詳細と、カスタマイズ方法について説明します。

## 基本的なアプリケーション一覧

### 開発ツール
- **PowerShell 7**: 最新のPowerShell環境
- **Windows Terminal**: 高機能ターミナルアプリ
- **Git**: バージョン管理システム
- **Visual Studio Code**: コードエディタ

### ユーティリティ
- **7-Zip**: ファイル圧縮・展開ツール
- **Notepad++**: 高機能テキストエディタ
- **PowerToys**: Microsoft製ユーティリティ集

### ブラウザ
- **Google Chrome**: Webブラウザ
- **Mozilla Firefox**: オープンソースWebブラウザ

### メディア
- **VLC Media Player**: マルチメディアプレイヤー

### 生産性
- **Microsoft Teams**: チームコラボレーション
- **Adobe Acrobat Reader**: PDF閲覧・編集

## 設定ファイル: applications.json

### 基本構造

```json
{
  "applications": [
    {
      "id": "unique-app-id",
      "name": "アプリケーション名",
      "description": "アプリの説明",
      "category": "Development|Productivity|Utilities|Browsers|Media|Communication|Custom",
      "priority": 1,
      "enabled": true,
      "installMethod": "winget|msi|exe",
      "packageId": "Microsoft.PowerShell",
      "installerPath": "downloads\\CustomApp.msi",
      "args": ["--silent", "/norestart"]
    }
  ]
}
```

### パラメータ詳細

#### 必須パラメータ
- **id**: アプリケーションの一意識別子
- **name**: 表示名
- **category**: アプリケーションカテゴリ
- **installMethod**: インストール方法（winget/msi/exe）

#### オプションパラメータ
- **description**: アプリケーションの説明
- **priority**: インストール優先度（1=必須, 2=推奨, 3=オプション）
- **enabled**: インストールの有効/無効（true/false）
- **packageId**: wingetパッケージID（winget使用時）
- **installerPath**: インストーラーファイルパス（msi/exe使用時）
- **args**: インストール時の追加引数

## インストール方法

### 1. winget（推奨）
Windows Package Manager経由でのインストール

```json
{
  "id": "powershell7",
  "name": "PowerShell 7",
  "installMethod": "winget",
  "packageId": "Microsoft.PowerShell",
  "args": ["--silent"]
}
```

### 2. MSI
MSIファイルを使用したインストール

```json
{
  "id": "custom-app",
  "name": "カスタムアプリ",
  "installMethod": "msi",
  "installerPath": "downloads\\CustomApp.msi",
  "args": ["/quiet", "/norestart"]
}
```

### 3. EXE
EXEファイルを使用したインストール

```json
{
  "id": "legacy-app",
  "name": "レガシーアプリ",
  "installMethod": "exe",
  "installerPath": "downloads\\LegacyApp.exe",
  "args": ["/S", "/v/qn"]
}
```

## スクリプトの実行オプション

### 基本実行

```powershell
# 全てのアプリをインストール
.\scripts\setup\install-basic-apps.ps1

# ヘルプを表示
.\scripts\setup\install-basic-apps.ps1 -Help
```

### 詳細なオプション

```powershell
# ドライラン - 何がインストールされるかを確認（推奨）
.\scripts\setup\install-basic-apps.ps1 -DryRun

# 優先度1（必須）のアプリのみインストール
.\scripts\setup\install-basic-apps.ps1 -MaxPriority 1

# 特定のカテゴリのみインストール
.\scripts\setup\install-basic-apps.ps1 -Categories "Development","Utilities"

# 特定アプリのみインストール
.\scripts\setup\install-basic-apps.ps1 -IncludeApps "git","vscode"

# 特定アプリを除外してインストール
.\scripts\setup\install-basic-apps.ps1 -ExcludeApps "teams","chrome"

# 強制再インストール
.\scripts\setup\install-basic-apps.ps1 -Force -IncludeApps "git"
```

### パラメータ説明

- **-Help**: 詳細なヘルプを表示
- **-ConfigPath**: アプリケーション設定ファイルのパス
- **-IncludeApps**: インストールするアプリのIDを指定
- **-ExcludeApps**: 除外するアプリのIDを指定  
- **-Categories**: 対象カテゴリを指定
- **-MaxPriority**: インストールする最大優先度（1=必須, 2=推奨, 3=オプション）
- **-Force**: 既にインストール済みでも強制再インストール
- **-DryRun**: 実際のインストールは行わず、実行予定を表示

## カスタマイズ例

### 新しいアプリケーションの追加

```json
{
  "id": "slack",
  "name": "Slack",
  "description": "チームコミュニケーションツール",
  "category": "Communication",
  "priority": 2,
  "enabled": true,
  "installMethod": "winget",
  "packageId": "SlackTechnologies.Slack"
}
```

### 開発環境に特化した設定

```json
{
  "applications": [
    {
      "id": "nodejs",
      "name": "Node.js",
      "category": "Development",
      "priority": 1,
      "installMethod": "winget",
      "packageId": "OpenJS.NodeJS"
    },
    {
      "id": "docker-desktop",
      "name": "Docker Desktop",
      "category": "Development",
      "priority": 2,
      "installMethod": "winget",
      "packageId": "Docker.DockerDesktop"
    },
    {
      "id": "postman",
      "name": "Postman",
      "category": "Development",
      "priority": 2,
      "installMethod": "winget",
      "packageId": "Postman.Postman"
    }
  ]
}
```

## トラブルシューティング

### よくある問題

1. **wingetパッケージが見つからない**
   ```powershell
   # パッケージの検索
   winget search "アプリ名"
   
   # ソースの更新
   winget source update
   ```

2. **インストール権限エラー**
   - 管理者権限での実行を確認
   - UACの設定を確認

3. **ネットワークエラー**
   - インターネット接続を確認
   - プロキシ設定がある場合は適切に設定

4. **依存関係エラー**
   - 前提条件のアプリケーションが不足している場合
   - priority設定で順序を調整

### ログの確認

```powershell
# インストールログの確認
Get-Content logs\scripts\basic-apps.log -Tail 50

# 特定アプリのエラー確認
Select-String "エラー" logs\scripts\basic-apps.log
```

## 関連ドキュメント
- [メインREADME](../README.md)
- [トラブルシューティングガイド](Troubleshooting.md)
- [カスタマイズガイド](Customization-Guide.md)
