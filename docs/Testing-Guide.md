# テスト・診断ガイド

## 概要

Windows Kitting Workflowプロジェクトには、設定ファイル、プロジェクト構造、システム統合を検証するための包括的なテストスイートが含まれています。このドキュメントでは、テストツールの使用方法と結果の解釈について説明します。

## テストスイート構成

### Run-AllTests.ps1 - マスターテストランナー

**目的**: 包括的なレポートによる一元的なテスト実行

**主要機能**:
- マルチスイートテスト実行
- 自動修復機能
- CI/CD統合サポート
- JSONおよびHTMLレポート
- 設定可能な実行フロー

**使用例**:
```powershell
# デフォルト設定ですべてのテストを実行
.\tests\Run-AllTests.ps1

# 自動修復を有効にして実行
.\tests\Run-AllTests.ps1 -Fix

# 特定のテストスイートを実行
.\tests\Run-AllTests.ps1 -TestSuites "JsonConfiguration","ProjectStructure"

# 包括的なレポートを生成
.\tests\Run-AllTests.ps1 -GenerateReport -OutputJson -Verbose

# CI/CDモード（失敗時も継続）
.\tests\Run-AllTests.ps1 -ContinueOnFailure -OutputJson
```

### Test-JsonConfiguration.ps1 - JSON検証

**目的**: JSON設定ファイルの包括的な検証

**検証領域**:
- JSON構文と構造
- スキーマ準拠
- 文字エンコーディング（BOM検出、文字化けチェック）
- ファイル間整合性
- 設定の完全性

**使用例**:
```powershell
# すべてのJSON設定ファイルを検証
.\tests\Test-JsonConfiguration.ps1

# 特定の設定ファイルをテスト
.\tests\Test-JsonConfiguration.ps1 -ConfigPath "config\workflow.json"

# エンコーディングと構文の問題を自動修復
.\tests\Test-JsonConfiguration.ps1 -Fix

# 詳細な検証と詳細出力
.\tests\Test-JsonConfiguration.ps1 -Verbose -OutputJson
```

**スキーマ検証の詳細**:

1. **workflow.json**:
   - 必須: `steps`配列を持つ`workflow`オブジェクト
   - 各ステップには`id`と`script`プロパティが必要
   - 一意のステップID
   - 有効なスクリプト参照

2. **notifications.json**:
   - 通知が有効な場合のWebhook URLとタイプ
   - 有効なイベント設定

3. **applications.json**:
   - 必須の`id`と`installMethod`を持つアプリケーションオブジェクト
   - メソッド固有の検証（wingetには`packageId`、msi/exeには`installerPath`が必要）

4. **workflow.json autologin設定**:
   - autologin-setupステップのパラメータ検証
   - 認証情報フォーマットのチェック

### Test-ProjectStructure.ps1 - プロジェクト構造検証

**目的**: プロジェクト構成とファイル依存関係の検証

**検証カテゴリ**:
- **フォルダ構造**: 必須ディレクトリと自動作成されるオプションフォルダ
- **コアファイル**: 必須スクリプトと設定ファイル
- **スクリプト構文**: PowerShell、JSON、バッチファイルの検証
- **レジストリファイル**: .regファイル形式と内容の検証
- **ドキュメント**: 必須ドキュメント構造（現在は無効化）
- **依存関係**: スクリプト間およびファイル間の参照

**使用例**:
```powershell
# 完全なプロジェクト構造を検証
.\tests\Test-ProjectStructure.ps1

# 詳細な検証と詳細出力
.\tests\Test-ProjectStructure.ps1 -Verbose

# 結果をJSONにエクスポート
.\tests\Test-ProjectStructure.ps1 -OutputJson
```

## テスト実行ワークフロー

### 開発ワークフロー

```powershell
# 1. 開発中のJSON検証
.\tests\Test-JsonConfiguration.ps1 -Fix

# 2. ファイル変更後の構造検証
.\tests\Test-ProjectStructure.ps1 -Verbose

# 3. コミット前の完全テストスイート
.\tests\Run-AllTests.ps1 -GenerateReport
```

### デプロイ前テスト

```powershell
# 包括的な検証
.\tests\Run-AllTests.ps1 -Verbose -OutputJson -GenerateReport

# 生成されたレポートを確認
# - test-report.html（視覚的概要）
# - test-results-all.json（詳細データ）
```

### トラブルシューティングワークフロー

```powershell
# 1. 包括的診断を実行
.\tests\Run-AllTests.ps1 -Verbose

# 2. 特定の問題に焦点を当てる
.\tests\Test-JsonConfiguration.ps1 -ConfigPath "problematic-file.json" -Verbose

# 3. 自動修復を試行
.\tests\Test-JsonConfiguration.ps1 -Fix

# 4. 修復を検証
.\tests\Run-AllTests.ps1
```

## テスト出力とレポート

### コンソール出力形式

テストでは、状況をすばやく識別するためのカラーコード化された出力を使用します：
- 🟢 **緑**: テストが正常に通過
- 🔴 **赤**: テストが失敗、要注意
- 🟡 **黄**: 警告または追加情報

**出力例**:
```
[PASS] JSON構文 - workflow.json
[FAIL] 文字エンコーディング - notifications.json
  15行目、23位置で文字化けを検出: '�'
[PASS] スキーマ検証 - applications.json
```

### JSONレポート構造

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
      "Message": "JSON構文は有効です",
      "FixAction": ""
    }
  ]
}
```

### HTMLレポート機能

生成されるHTMLレポートには以下が含まれます：
- 成功メトリクスを含むエグゼクティブサマリー
- カテゴリ別のテストスイート内訳
- タイムスタンプ付きの詳細テスト結果
- エラーの詳細と推奨事項
- 視覚的ステータスインジケータ

## 自動修復機能

### サポートされている自動修復

1. **文字エンコーディング問題**:
   - UTF-8 BOMの追加
   - 一貫した改行コードの正規化

2. **JSON形式**:
   - 基本的な構文エラーの修正
   - 文字エンコーディングの標準化

3. **ファイルエンコーディング**:
   - UTF-8（BOM付き）の適用
   - ファイル間での一貫したエンコーディング

### 自動修復の安全機能

- **自動バックアップ**: 変更前に元ファイルをバックアップ
- **修復後検証**: 変更を受け入れる前に修復を検証
- **失敗時のロールバック**: 修復が検証に失敗した場合の自動復元

### 手動介入が必要な場合

- 複雑なJSON構文エラー
- ファイル依存関係の不足
- スキーマ構造違反
- レジストリファイルの内容エラー

## 統合テスト

### コンポーネント間検証

テストスイートには以下を検証する統合テストが含まれます：

1. **ワークフロー-スクリプトマッピング**: workflow.jsonが既存スクリプトを参照することを確認
2. **共通関数の可用性**: 共有関数が読み込み可能であることを検証
3. **設定の整合性**: ファイル間設定の整合性をチェック
4. **依存関係解決**: コンポーネント間依存関係を検証

### 統合テストの例

```powershell
# 統合テストのみを実行
.\tests\Run-AllTests.ps1 -TestSuites "Integration"

# 統合テストは完全実行に自動的に含まれます
.\tests\Run-AllTests.ps1
```

## CI/CD統合

### GitHub Actions例

```yaml
name: Windows Kitting Workflow Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: PowerShell実行ポリシーを設定
      shell: powershell
      run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    
    - name: テストスイートを実行
      shell: powershell
      run: |
        .\tests\Run-AllTests.ps1 -ContinueOnFailure -OutputJson -Verbose
        if ($LASTEXITCODE -ne 0) { 
          Write-Host "テストが失敗しましたが、成果物収集のため継続します"
        }
    
    - name: テスト結果をアップロード
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: |
          test-results-*.json
          test-report.html
```

### Azure DevOpsパイプライン

```yaml
trigger:
- main
- develop

pool:
  vmImage: 'windows-latest'

steps:
- task: PowerShell@2
  displayName: 'Windows Kitting Workflowテストを実行'
  inputs:
    targetType: 'inline'
    script: |
      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
      .\tests\Run-AllTests.ps1 -ContinueOnFailure -OutputJson -GenerateReport -Verbose
  continueOnError: true

- task: PublishTestResults@2
  displayName: 'テスト結果を公開'
  condition: always()
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'test-results-*.json'
    testRunTitle: 'Windows Kitting Workflow Tests'

- task: PublishHtmlReport@1
  displayName: 'HTMLレポートを公開'
  condition: always()
  inputs:
    reportDir: 'test-report.html'
    tabName: 'Test Report'
```

## パフォーマンス考慮事項

### テスト実行時間

- **JSON設定テスト**: 約5-10秒
- **プロジェクト構造テスト**: 約10-15秒  
- **統合テスト**: 約5-10秒
- **完全テストスイート**: 約20-35秒

### 最適化のヒント

1. **対象テスト**: 開発中は特定のテストスイートを使用
2. **並列実行**: CI/CDシステムでテストスイートを並列実行可能
3. **増分テスト**: 変更されたコンポーネントに焦点を当てる
4. **結果キャッシュ**: 未変更テストの再実行を回避

## テスト問題のトラブルシューティング

### 一般的なテスト失敗

1. **PowerShell実行ポリシー**:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **ファイルアクセス権限**:
   - テストスクリプトがすべてのプロジェクトファイルに読み取りアクセスできることを確認
   - ファイル変更時（-Fix使用時）は適切な権限で実行

3. **依存関係の不足**:
   - 必要なファイルがすべて存在することを確認
   - プロジェクト構造の完全性をチェック

4. **文字エンコーディング問題**:
   - 自動修復機能を使用: `-Fix`パラメータ
   - 自動修復が失敗した場合は手動でファイルエンコーディングを確認

### テストスクリプトのデバッグ

詳細な診断のために詳細出力を有効にします：
```powershell
# 最大詳細レベル
.\tests\Run-AllTests.ps1 -Verbose -OutputJson

# 特定のテストのデバッグ
.\tests\Test-JsonConfiguration.ps1 -Verbose -ConfigPath "specific-file.json"
```

### テストスクリプトの検証

テストスクリプト自体も検証できます：
```powershell
# PowerShell構文チェック
Get-ChildItem tests\*.ps1 | ForEach-Object {
    $errors = @()
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $_.FullName -Raw), [ref]$errors)
    if ($errors.Count -eq 0) {
        Write-Host "✓ $($_.Name)" -ForegroundColor Green
    } else {
        Write-Host "✗ $($_.Name): $($errors.Count) errors" -ForegroundColor Red
    }
}
```

## ベストプラクティス

### テスト開発

1. **包括的カバレッジ**: 各テストは関連する複数の側面を検証すべき
2. **明確なエラーメッセージ**: 具体的な推奨事項を含む実行可能なフィードバックを提供
3. **安全な自動修復**: 修復を試行する前に常にバックアップ
4. **パフォーマンス最適化**: 高速実行のためのテスト設計

### テスト実行

1. **定期的テスト**: 開発中に頻繁にテストを実行
2. **コミット前検証**: コードコミット前に必ず完全テストスイートを実行
3. **環境テスト**: クリーンで分離された環境で検証
4. **結果分析**: 洞察やトレンドのために詳細レポートを確認

### メンテナンス

1. **テストの最新性**: プロジェクトの進化に合わせてテストを更新
2. **新機能カバレッジ**: 新機能にテストを追加
3. **パフォーマンス監視**: テスト実行時間の追跡と最適化
4. **ドキュメント更新**: 現在のテストドキュメントを維持

## 関連ドキュメント

- [メインREADME](../README.md)
- [トラブルシューティングガイド](Troubleshooting.md)
- [カスタマイズガイド](Customization-Guide.md)
- [テストスイートREADME](../tests/README.md)
