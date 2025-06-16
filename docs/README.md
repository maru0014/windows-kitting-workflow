# Windows Kitting Workflow ドキュメント

このフォルダには、Windows Kitting Workflowプロジェクトの詳細ドキュメントが含まれています。

## ドキュメント一覧

### 📋 [レジストリ設定ガイド](Registry-Configuration.md)
Windowsレジストリ設定の詳細説明
- エクスプローラー設定（ファイル拡張子表示）
- パフォーマンス設定（応答性向上）
- プライバシー設定（情報収集抑制）
- カスタム設定の追加方法
- 安全性とバックアップ機能

### 📦 [アプリケーション管理ガイド](Application-Management.md)
アプリケーションインストールの管理方法
- applications.json設定ファイルの詳細
- winget/MSI/EXE インストール方法
- スクリプト実行オプション
- カスタマイズ例
- トラブルシューティング

### ⚙️ [カスタマイズガイド](Customization-Guide.md)
ワークフローのカスタマイズ方法
- workflow.json設定の詳細
- カスタムスクリプトの追加
- 通知設定（Slack/Teams）
- 環境別設定の管理
- 高度なカスタマイズ技法

### � [Windows Updateガイド](Windows-Update-Guide.md)
Windows Update設定の詳細
- 利用可能なパラメータ（MicrosoftUpdate、KBArticleID等）
- 設定例（セキュリティのみ、機能更新除外等）
- トラブルシューティング
- デバッグモード
- セキュリティ考慮事項

### 🧵 [Slackスレッドガイド](Slack-Thread-Guide.md)
Slackスレッド機能の使用方法
- PCごとのスレッド分割設定
- スレッドTS管理
- テスト・デバッグ方法
- 管理関数の使用方法
- トラブルシューティング

### � [Wi-Fi設定ガイド](Wi-Fi-Configuration-Guide.md)
Wi-Fi自動設定機能の詳細説明
- Wi-Fi設定XMLファイルの作成方法
- プロファイルのエクスポート・インポート
- セキュリティ考慮事項（パスワード暗号化）
- 企業ネットワーク（802.1X）対応
- トラブルシューティングとエラー対処

### �🔧 [トラブルシューティングガイド](Troubleshooting.md)
問題解決方法と診断手順
- よくある問題と解決方法
- PowerShell実行ポリシー
- JSON設定ファイルエラー
- wingetインストール失敗
- ログの活用方法
- 緊急時の対処法

### 🧪 [テスト・診断ガイド](Testing-Guide.md)
テストツールの使用方法
- Run-AllTests.ps1（テストランナー）
- Test-JsonConfiguration.ps1（JSON検証）
- Test-ProjectStructure.ps1（プロジェクト構造検証）
- カスタムテストの作成

### 🔐 [自動ログインREADME](AutoLogin-README.md)
自動ログイン機能の詳細説明
- 設定ファイル（autologin.json）
- 使用方法
- セキュリティ考慮事項
- トラブルシューティング

## 推奨読書順序

### 初回利用者
1. [メインREADME](../README.md) - プロジェクト概要とクイックスタート
2. [アプリケーション管理ガイド](Application-Management.md) - インストールアプリの理解
3. [レジストリ設定ガイド](Registry-Configuration.md) - システム変更内容の理解

### カスタマイズしたい場合
1. [カスタマイズガイド](Customization-Guide.md) - 基本的なカスタマイズ方法
2. [アプリケーション管理ガイド](Application-Management.md) - アプリ設定の変更
3. [Windows Updateガイド](Windows-Update-Guide.md) - Windows Update設定の詳細
4. [レジストリ設定ガイド](Registry-Configuration.md) - レジストリ設定の追加

### 問題が発生した場合
1. [トラブルシューティングガイド](Troubleshooting.md) - 問題解決方法
2. [テスト・診断ガイド](Testing-Guide.md) - 診断ツールの使用
3. [自動ログインREADME](AutoLogin-README.md) - 自動ログイン問題の場合

### 開発・保守担当者
1. [テスト・診断ガイド](Testing-Guide.md) - テストツールの理解
2. [カスタマイズガイド](Customization-Guide.md) - 高度なカスタマイズ
3. [トラブルシューティングガイド](Troubleshooting.md) - サポート対応

## ドキュメント間の関連性

```
README.md (メイン)
├── Registry-Configuration.md
├── Application-Management.md  
├── Customization-Guide.md
│   ├─ 参照 → Registry-Configuration.md
│   ├─ 参照 → Application-Management.md
│   ├─ 参照 → Windows-Update-Guide.md
│   └─ 参照 → Troubleshooting.md
├── Windows-Update-Guide.md
│   ├─ 参照 → Customization-Guide.md
│   ├─ 参照 → Troubleshooting.md
│   └─ 参照 → Testing-Guide.md
├── Troubleshooting.md
│   ├─ 参照 → Testing-Guide.md
│   └─ 参照 → AutoLogin-README.md
├── Testing-Guide.md
│   └─ 参照 → Troubleshooting.md
└── AutoLogin-README.md
```

## ドキュメントの更新

ドキュメントの更新時は以下を考慮してください：

1. **相互参照の確認**: 関連ドキュメント間のリンクが正しいか
2. **情報の一貫性**: 複数のドキュメントで矛盾がないか
3. **例示の最新性**: コード例や設定例が現在のバージョンと一致するか
4. **図表の更新**: ファイル構成図などが現在の構造と一致するか

## フィードバック

ドキュメントに関するフィードバックや改善提案がありましたら、GitHubのIssuesまでお知らせください。
