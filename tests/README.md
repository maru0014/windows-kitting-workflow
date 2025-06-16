# Windows Kitting Workflow テストスイート

このフォルダには、Windows Kitting Workflowプロジェクトの包括的なテストスイートが含まれており、設定ファイル、プロジェクト構造、システム統合の検証を行います。

## 簡単実行方法（推奨）

### run-tests.bat - 簡単テスト実行
Windowsユーザー向けの最も簡単な実行方法：
```batch
# エクスプローラーでダブルクリックまたはコマンドプロンプトから実行
run-tests.bat
```

### run-tests-advanced.bat - オプション付き実行
より柔軟なテストオプション：
```batch
# 標準テスト
run-tests-advanced.bat

# 自動修復付きテスト
run-tests-advanced.bat fix

# JSONファイルのみテスト
run-tests-advanced.bat json

# 詳細レポート生成
run-tests-advanced.bat report

# ヘルプ表示
run-tests-advanced.bat help
```

### PowerShell直接実行
より詳細な制御が必要な場合：
```powershell
# すべてのテストを実行
.\Run-AllTests.ps1

# 自動修復を有効にして実行
.\Run-AllTests.ps1 -Fix

# 特定のテストスイートを実行
.\Run-AllTests.ps1 -TestSuites "JsonConfiguration"
```

## テストスクリプト概要

### Run-AllTests.ps1 - マスターテストランナー
- **目的**: 包括的なレポートですべてのテストスイートを実行
- **機能**: 
  - 複数のテストスイートに対応
  - CI/CD統合対応
  - JSONおよびHTMLレポート生成
  - 自動修復機能
  - 設定可能な実行フロー

```powershell
# すべてのテストを実行
.\Run-AllTests.ps1

# 自動修復を有効にして実行
.\Run-AllTests.ps1 -Fix

# 特定のテストスイートを実行
.\Run-AllTests.ps1 -TestSuites "JsonConfiguration","ProjectStructure"

# 詳細レポートを生成
.\Run-AllTests.ps1 -GenerateReport -OutputJson -Verbose

# CI/CDモード（失敗時も継続）
.\Run-AllTests.ps1 -ContinueOnFailure -OutputJson
```

### Test-JsonConfiguration.ps1 - JSON検証
- **目的**: JSON設定ファイルの包括的な検証
- **機能**:
  - 構文検証
  - スキーマ検証
  - 文字エンコーディングチェック（BOM、文字化けチェック）
  - 自動修復機能
  - ファイル間整合性チェック

```powershell
# すべてのJSONファイルを検証
.\Test-JsonConfiguration.ps1

# 特定のファイルをテスト
.\Test-JsonConfiguration.ps1 -ConfigPath "config\workflow.json"

# 問題を自動修復
.\Test-JsonConfiguration.ps1 -Fix

# 詳細出力
.\Test-JsonConfiguration.ps1 -Verbose -OutputJson
```

### Test-ProjectStructure.ps1 - プロジェクト構造検証
- **目的**: プロジェクトフォルダ構造とファイル依存関係の検証
- **機能**:
  - 必須フォルダの検証
  - ファイル存在チェック
  - PowerShell構文検証
  - レジストリファイル検証
  - ドキュメント構造チェック
  - 依存関係の検証

```powershell
# プロジェクト構造を検証
.\Test-ProjectStructure.ps1

# 詳細検証
.\Test-ProjectStructure.ps1 -Verbose

# 結果をエクスポート
.\Test-ProjectStructure.ps1 -OutputJson
```

### Test-NotificationFunctions.ps1 - 通知機能テスト
- **目的**: Slack/Teams通知機能の動作確認
- **機能**:
  - 通知設定の検証
  - Slack通知のテスト
  - Teams通知のテスト
  - スレッド機能のテスト
  - スレッドデータの管理

```powershell
# 全機能テスト
.\Test-NotificationFunctions.ps1 -All

# 設定情報表示
.\Test-NotificationFunctions.ps1 -ShowInfo

# Slack通知テスト
.\Test-NotificationFunctions.ps1 -TestSlack

# スレッドデータクリア
.\Test-NotificationFunctions.ps1 -ClearThreads
```

## テストカテゴリ

### JSON設定テスト
すべてのJSON設定ファイルを検証：
- **workflow.json**: ワークフローステップ検証、依存関係チェック
- **notifications.json**: Webhook設定検証
- **applications.json**: アプリケーション定義検証
- **autologin.json**: 自動ログイン設定検証

**共通チェック項目**:
- UTF-8エンコーディング（BOM付き）
- JSON構文検証
- スキーマ準拠
- 文字化けチェック（文字崩れの検出）
- 相互参照検証

### プロジェクト構造テスト
プロジェクト構成の検証：
- **フォルダ構造**: 必須ディレクトリの存在
- **コアファイル**: 必須スクリプトと設定
- **スクリプト依存関係**: スクリプト間参照
- **ドキュメント**: 必須ドキュメントファイル
- **レジストリファイル**: .regファイル構文検証

### 統合テスト
システム統合の検証：
- **ワークフロー-スクリプトマッピング**: workflow.jsonが既存スクリプトを参照
- **共通関数**: 共有関数のアクセス可能性
- **設定整合性**: ファイル間設定の整合性
- **依存関係解決**: コンポーネント間依存関係

## テスト実行パターン

### 開発ワークフロー
```powershell
# 1. 開発中のクイック検証
.\Test-JsonConfiguration.ps1 -Fix

# 2. 変更後の構造検証
.\Test-ProjectStructure.ps1 -Verbose

# 3. コミット前の完全テストスイート
.\Run-AllTests.ps1 -GenerateReport
```

### CI/CD統合
```powershell
# 自動テストパイプライン
.\Run-AllTests.ps1 -ContinueOnFailure -OutputJson -Verbose

# 結果はtest-results-all.jsonで利用可能
```

### トラブルシューティングワークフロー
```powershell
# 1. 包括的診断
.\Run-AllTests.ps1 -Verbose

# 2. 特定エリアの集中チェック
.\Test-JsonConfiguration.ps1 -ConfigPath "problematic-file.json" -Verbose

# 3. 自動修復の試行
.\Test-JsonConfiguration.ps1 -Fix
```

## テスト出力とレポート

### コンソール出力
- カラーコード化された結果（緑=成功、赤=失敗、黄=警告）
- 構造化されたテストカテゴリ化
- 進行状況インジケータ
- 推奨事項付きの詳細エラーメッセージ

### JSONレポート
```json
{
  "TestSuite": "JsonConfiguration",
  "Success": true,
  "ExitCode": 0,
  "Timestamp": "2025-06-15 10:30:00",
  "Details": [
    {
      "TestName": "JSON Syntax",
      "FilePath": "config\\workflow.json",
      "Success": true,
      "Message": "JSON syntax is valid"
    }
  ]
}
```

### HTMLレポート
以下を含む包括的なHTMLレポート：
- エグゼクティブサマリー
- テストスイート内訳
- 詳細結果
- タイムスタンプ追跡
- 成功/失敗メトリクス

## エラー処理と自動修復

### 一般的な問題と自動修復

1. **全角文字**
   - 検出: 除外（全角文字は許可）
   - 注意: 文字化けのみチェック対象

2. **UTF-8 BOM**
   - 検出: バイトオーダーマークの不在
   - 自動修復: BOM付きUTF-8で保存

3. **JSON構文エラー**
   - 検出: 位置付きパースエラー
   - 自動修復: 文字エンコーディング修正を試行

4. **ファイル不足**
   - 検出: 必須ファイルの不在
   - 推奨: ファイル作成ガイダンス

### 手動介入が必要な場合

- 複雑なJSON構文エラー
- スクリプト依存関係の不足
- 不正なスキーマ構造
- レジストリファイルの内容問題

## ベストプラクティス

### テスト開発
1. **包括的カバレッジ**: 各テストは複数の側面を検証すべき
2. **明確なメッセージ**: 実行可能なエラーメッセージを提供
3. **自動修復の安全性**: 自動修復前に常にバックアップ
4. **パフォーマンス**: 高速実行のために最適化

### テスト実行
1. **定期的テスト**: 開発中に頻繁にテストを実行
2. **コミット前**: コミット前に必ず完全テストスイートを実行
3. **環境検証**: クリーンな環境でテスト
4. **結果分析**: 詳細レポートを確認して洞察を得る

### メンテナンス
1. **テスト更新**: プロジェクト変更に合わせてテストを最新に保つ
2. **新規検証**: 新機能に対するテストを追加
3. **パフォーマンス監視**: テスト実行時間を追跡
4. **ドキュメント**: 変更に合わせてテストドキュメントを更新

## CI/CD統合例

### GitHub Actions
```yaml
- name: Run Tests
  shell: powershell
  run: |
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    .\tests\Run-AllTests.ps1 -ContinueOnFailure -OutputJson -Verbose
    if ($LASTEXITCODE -ne 0) { exit 1 }

- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: test-results-all.json
```

### Azure DevOps
```yaml
- task: PowerShell@2
  displayName: 'Run Windows Kitting Workflow Tests'
  inputs:
    targetType: 'inline'
    script: |
      .\tests\Run-AllTests.ps1 -ContinueOnFailure -OutputJson -GenerateReport
  continueOnError: true

- task: PublishTestResults@2
  inputs:
    testResultsFormat: 'NUnit'
    testResultsFiles: 'test-results-all.json'
```

## 関連ドキュメント
- [メインREADME](../README.md)
- [トラブルシューティングガイド](../docs/Troubleshooting.md)
- [カスタマイズガイド](../docs/Customization-Guide.md)

## トラブルシューティング

### ログファイルの文字化けが発生する場合
1. エンコーディングを確認
2. 共通ログ関数（`scripts\Common-LogFunctions.ps1`）の動作確認

### フォルダ・ファイル不足エラーの場合
1. `Test-ProjectStructure.ps1 -Verbose` で詳細を確認
2. 不足しているファイル・フォルダを作成

## 注意事項

- テストスクリプトは開発・検証用です
- 本番環境での実行前に必ずテストしてください
- テストファイルは `.gitignore` に含まれていません（バージョン管理対象）
- テスト結果のログファイルは自動的に生成され、`.gitignore` に含まれます
