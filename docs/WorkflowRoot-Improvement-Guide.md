# WorkflowRoot取得処理の改善ガイド

## 概要

`$workflowRoot`パス取得処理が各スクリプトで重複していた問題を解決するため、共通ヘルパー関数を導入しました。これにより、コードの保守性向上、処理のキャッシュ化、エラー処理の標準化が実現されました。

## 新しいヘルパー関数

### 1. Get-WorkflowRoot
ワークフローのルートディレクトリを動的に検出し、キャッシュします。

```powershell
$workflowRoot = Get-WorkflowRoot
```

### 2. Get-WorkflowPath
よく使用されるパスを簡単に取得できます。

```powershell
# 設定フォルダのパス
$configPath = Get-WorkflowPath -PathType "Config"

# 特定の設定ファイルのパス
$workflowConfigPath = Get-WorkflowPath -PathType "Config" -SubPath "workflow.json"

# ログフォルダのパス
$logPath = Get-WorkflowPath -PathType "Logs" -SubPath "scripts\install.log"

# ステータスフォルダのパス
$statusPath = Get-WorkflowPath -PathType "Status" -SubPath "system-info.json"
```

### 3. Get-WorkflowConfig
設定ファイルを簡単に読み込みます。

```powershell
# workflow.json を読み込み
$config = Get-WorkflowConfig -ConfigType "workflow"

# notifications.json を読み込み
$notificationConfig = Get-WorkflowConfig -ConfigType "notifications"
```

### 4. Get-CompletionMarkerPath
完了マーカーファイルのパスを取得します。

```powershell
$completionMarker = Get-CompletionMarkerPath -TaskName "init"
# 結果: {WorkflowRoot}\status\init.completed
```

## 利用方法

### スクリプトでの使用

```powershell
# ヘルパー関数のインポート
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

# 従来の方法
$workflowRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
while ($workflowRoot -and -not (Test-Path (Join-Path $workflowRoot "MainWorkflow.ps1"))) {
    $parent = Split-Path $workflowRoot -Parent
    if ($parent -eq $workflowRoot) {
        $workflowRoot = $PSScriptRoot
        break
    }
    $workflowRoot = $parent
}
$configPath = Join-Path $workflowRoot "config\workflow.json"

# 新しい方法
$workflowRoot = Get-WorkflowRoot
$configPath = Get-WorkflowPath -PathType "Config" -SubPath "workflow.json"
```

## 移行ツール

### 個別ファイルの移行

```powershell
# DryRunで変更内容を確認
.\scripts\Migrate-WorkflowRoot.ps1 -FilePath "scripts\setup\initialize.ps1" -DryRun

# 実際に更新
.\scripts\Migrate-WorkflowRoot.ps1 -FilePath "scripts\setup\initialize.ps1"
```

### 一括移行

```powershell
# すべてのファイルをDryRunで確認
.\scripts\Migrate-All-WorkflowRoot.ps1 -DryRun

# すべてのファイルを一括更新
.\scripts\Migrate-All-WorkflowRoot.ps1 -Force
```

## 対応済みファイル

以下のファイルはすでに新しいヘルパー関数を使用するように更新されています：

- `scripts/Common-LogFunctions.ps1`
- `scripts/setup/initialize.ps1`

## 移行が必要なファイル

以下のファイルには従来の`$workflowRoot`取得処理が含まれており、移行が推奨されます：

### scripts/setup/
- `install-winget.ps1`
- `import-registry.ps1`
- `windows-update.ps1`
- `rename-computer.ps1`
- `install-basic-apps.ps1`
- `deploy-desktop-files.ps1`

### tests/
- `Test-JsonConfiguration.ps1`
- `Test-NotificationFunctions.ps1`

## メリット

### 1. コードの重複削減
- 50行以上の重複コードが数行に短縮

### 2. 保守性の向上
- パス取得ロジックの変更は1箇所で対応可能
- エラー処理の統一

### 3. パフォーマンス向上
- キャッシュ機能による重複処理の削減

### 4. 開発効率向上
- よく使用されるパスパターンの簡単な取得
- 設定ファイル読み込みの簡略化

## 注意事項

1. **インポートの追加**: 新しいスクリプトでは`Common-WorkflowHelpers.ps1`のインポートが必要です。

2. **キャッシュのクリア**: テスト時など、キャッシュをクリアしたい場合は `Clear-WorkflowRootCache` を使用してください。

3. **後方互換性**: 既存のスクリプトは移行せずとも動作しますが、保守性向上のため移行を推奨します。

## トラブルシューティング

### エラー: "Get-WorkflowRoot が認識されません"
- `Common-WorkflowHelpers.ps1` がインポートされていることを確認してください
- パスが正しいことを確認してください

### エラー: "MainWorkflow.ps1が見つかりません"
- 実行しているスクリプトの位置を確認してください
- ワークフローのディレクトリ構造が正しいことを確認してください

### パフォーマンスが改善されない
- キャッシュが正常に動作していることを確認してください
- 必要に応じて `Clear-WorkflowRootCache` でキャッシュをリセットしてください
