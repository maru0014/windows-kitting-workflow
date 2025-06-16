# Windows Update設定ガイド

## 概要

Windows Kitting WorkflowのWindows Updateステップは、PSWindowsUpdateモジュールを使用してWindows Updateを自動実行します。このドキュメントでは、Windows Updateステップで利用可能な設定オプションと使用方法について説明します。

## 利用可能なパラメータ

### MicrosoftUpdate (boolean)
- **説明**: Microsoft Updateサービスを含めてアップデートを検索・インストールするかどうか
- **デフォルト値**: true
- **用途**: Officeなどのマイクロソフト製品のアップデートも含める場合はtrue

```json
"parameters": {
  "MicrosoftUpdate": true
}
```

### Force (boolean)
- **説明**: 強制実行フラグ
- **デフォルト値**: true
- **用途**: 既にインストール済みのアップデートを再インストールする場合などに使用

```json
"parameters": {
  "Force": true
}
```

### RebootIfRequired (boolean)
- **説明**: アップデート完了後に再起動が必要な場合、自動的に再起動するかどうか
- **デフォルト値**: true
- **用途**: 無人インストール環境で自動再起動を有効にする場合

```json
"parameters": {
  "RebootIfRequired": true
}
```

### KBArticleID (配列)
- **説明**: 特定のKB番号のアップデートのみをインストール
- **デフォルト値**: [] (空配列 - すべてのアップデートが対象)
- **用途**: セキュリティアップデートのみインストールしたい場合

```json
"parameters": {
  "KBArticleID": ["KB5034441", "KB5034123"]
}
```

### NotKBArticleID (配列)
- **説明**: 除外するKB番号の指定
- **デフォルト値**: [] (空配列 - 除外なし)
- **用途**: 問題のあるアップデートを除外したい場合

```json
"parameters": {
  "NotKBArticleID": ["KB5034763"]
}
```

## 設定例

### 1. 標準設定（推奨）
すべてのアップデートをインストールし、自動再起動を有効にする設定です。

```json
{
  "id": "windows-update",
  "name": "Windows Update",
  "description": "Windows Updateの実行",
  "script": "scripts/setup/windows-update.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "MicrosoftUpdate": true,
    "Force": true,
    "RebootIfRequired": true,
    "KBArticleID": [],
    "NotKBArticleID": []
  },
  "timeout": 3600,
  "retryCount": 3,
  "rebootRequired": true
}
```

### 2. 手動再起動設定
アップデート完了後の再起動を手動で行う設定です。

```json
{
  "id": "windows-update",
  "name": "Windows Update (手動再起動)",
  "parameters": {
    "MicrosoftUpdate": true,
    "Force": true,
    "RebootIfRequired": false,
    "KBArticleID": [],
    "NotKBArticleID": []
  }
}
```

### 3. セキュリティアップデートのみ
特定のKB番号のセキュリティアップデートのみをインストールする設定です。

```json
{
  "id": "windows-update-security",
  "name": "Windows Update (セキュリティのみ)",
  "parameters": {
    "MicrosoftUpdate": true,
    "Force": true,
    "KBArticleID": [
      "KB5034441",  // 2024年1月セキュリティ更新
      "KB5034123",  // 2024年1月累積更新
      "KB5033375"   // 2023年12月セキュリティ更新
    ],
    "RebootIfRequired": true
  }
}
```

### 4. 機能更新プログラムの除外
機能更新プログラム（大型アップデート）を除外する設定です。

```json
{
  "id": "windows-update-no-feature",
  "name": "Windows Update (機能更新除外)",
  "parameters": {
    "MicrosoftUpdate": true,
    "Force": true,
    "NotKBArticleID": [
      "KB5034763",  // Windows 11 23H2機能更新
      "KB5034848"   // Windows 11 24H1機能更新
    ],
    "RebootIfRequired": true
  }
}
```

### 5. Microsoft Office除外設定
WindowsアップデートのみでOfficeアップデートを除外する設定です。

```json
{
  "id": "windows-update-os-only",
  "name": "Windows Update (OS のみ)",
  "parameters": {
    "MicrosoftUpdate": false,
    "Force": true,
    "RebootIfRequired": true,
    "KBArticleID": [],
    "NotKBArticleID": []
  }
}
```

## スクリプトの動作

### 実行フロー
1. **サービス確認**: Windows Update関連サービスの開始確認
2. **モジュール確認**: PSWindowsUpdateモジュールのインストール/インポート
3. **履歴確認**: 最近30日間のアップデート履歴表示
4. **アップデート検索**: 指定されたパラメータに基づくアップデート検索
5. **インストール実行**: 検出されたアップデートのダウンロード・インストール
6. **再起動判定**: 再起動が必要かどうかの確認
7. **完了記録**: 処理結果の記録とマーカーファイル作成

### ログ出力
- **ファイル**: `logs/windows-update.log`
- **内容**: 
  - 実行開始/終了時刻
  - 検出されたアップデート一覧
  - インストール結果
  - エラー情報

### 完了マーカー
処理完了時に `status/windows-update.completed` ファイルが作成されます。

```json
{
  "completedAt": "2024-01-15 14:30:00",
  "updatesInstalled": 5,
  "rebootRequired": true,
  "installedUpdates": [
    {
      "Title": "2024-01 x64 ベース システム用 Windows 11 累積更新プログラム",
      "Result": "Installed"
    }
  ]
}
```

## トラブルシューティング

### よくある問題

#### 1. PSWindowsUpdateモジュールのインストールエラー
```
エラー: PSWindowsUpdateモジュールのインストールに失敗しました
```
**対処法**: 
- PowerShell実行ポリシーを確認
- NuGetプロバイダーの手動インストール

#### 2. Windows Updateサービスが開始しない
```
エラー: Windows Updateサービスの開始に失敗しました
```
**対処法**:
- サービス管理コンソールでサービス状態を確認
- 手動でサービスを開始

#### 3. アップデートのダウンロードが失敗
```
エラー: アップデートインストールでエラー
```
**対処法**:
- インターネット接続を確認
- Windows Updateトラブルシューティングツールを実行

### デバッグモード
詳細なログ出力を得るには、スクリプトを直接実行してください：

```powershell
# 通常実行
.\scripts\setup\windows-update.ps1 -MicrosoftUpdate $true

# 自動再起動有効
.\scripts\setup\windows-update.ps1 -MicrosoftUpdate $true -RebootIfRequired

# 特定KBのみ
.\scripts\setup\windows-update.ps1 -KBArticleID @("KB5034441", "KB5034123")
```

## セキュリティに関する注意事項

1. **管理者権限**: このスクリプトは管理者権限で実行する必要があります
2. **ネットワーク通信**: Microsoft Updateサーバーとの通信が発生します
3. **システム変更**: 重要なシステムファイルが更新される可能性があります
4. **再起動**: 自動再起動を有効にした場合、未保存のデータが失われる可能性があります

## 関連ドキュメント

- [カスタマイズガイド](Customization-Guide.md): ワークフロー全体のカスタマイズ方法
- [トラブルシューティングガイド](Troubleshooting.md): 問題解決方法
- [テスト・診断ガイド](Testing-Guide.md): テストツールの使用方法
