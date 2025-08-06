# Windows Kitting Workflow ドキュメント

このフォルダには、Windows Kitting Workflowプロジェクトの詳細ドキュメントが含まれています。

## 📖 クイックナビゲーション

### 🎯 [目次・ガイド一覧](TABLE_OF_CONTENTS.md)
目的別・レベル別の詳細なドキュメントガイド

### 🚀 はじめて使う方
[メインREADME](../README.md) → [アプリケーション管理ガイド](Application-Management.md) → [トラブルシューティングガイド](Troubleshooting.md)

### ⚙️ カスタマイズしたい方
[カスタマイズガイド](Customization-Guide.md) → [レジストリ設定ガイド](Registry-Configuration.md)

## ドキュメント一覧

### � 基本ガイド（ユーザー向け）

### �📋 [レジストリ設定ガイド](Registry-Configuration.md)
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

### 🔐 [BitLocker設定ガイド](BitLocker-Configuration-Guide.md)
BitLocker暗号化の自動設定
- TPMベースの暗号化設定
- PIN認証オプション
- 回復キーの自動管理
- セキュリティ考慮事項
- トラブルシューティング

### ⚙️ [WorkflowEditorガイド](WorkflowEditor-Guide.md)
GUIワークフロー設定エディター
- 視覚的なワークフロー設定編集
- ステップの順序変更機能
- 基本設定とステップ詳細設定
- 保存機能とファイル管理
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
- workflow.jsonでの設定方法
- 使用方法
- セキュリティ考慮事項
- トラブルシューティング

### � 技術実装詳細（開発者向け）

### �📢 [Teams通知機能強化](Teams-Notifications-Enhancement.md)
Teams通知機能の改善実装詳細
- 日本語エンコード対策
- スレッド機能の実装
- 設定ファイルの変更方法
- 実装例とトラブルシューティング

### 🎨 [Teams通知新スレッド化方式ガイド](Teams-Notification-V2-Guide.md)
Teams通知の新スレッド化方式実装
- 改良版PowerAutomateフローとの連携
- マシンIDベースの真のスレッド化
- 複数台同時実行時のメッセージ分離
- 設定方法とトラブルシューティング

### ⚡ [WorkflowRoot改善ガイド](WorkflowRoot-Improvement-Guide.md)
WorkflowRoot取得処理の改善実装
- 共通ヘルパー関数の導入
- パス取得処理のキャッシュ化
- エラー処理の標準化
- 使用方法と実装例

## 推奨読書順序

### 🚀 初回利用者
1. [メインREADME](../README.md) - プロジェクト概要とクイックスタート
2. [アプリケーション管理ガイド](Application-Management.md) - インストールアプリの理解
3. [レジストリ設定ガイド](Registry-Configuration.md) - システム変更内容の理解
4. [トラブルシューティングガイド](Troubleshooting.md) - 問題発生時の対処法

### ⚙️ カスタマイズしたい場合
1. [カスタマイズガイド](Customization-Guide.md) - 基本的なカスタマイズ方法
2. [アプリケーション管理ガイド](Application-Management.md) - アプリ設定の変更
3. [Windows Updateガイド](Windows-Update-Guide.md) - Windows Update設定の詳細
4. [レジストリ設定ガイド](Registry-Configuration.md) - レジストリ設定の追加
5. [Wi-Fi設定ガイド](Wi-Fi-Configuration-Guide.md) - Wi-Fi自動設定の詳細
6. [共通通知ライブラリ](Common-Notification-Library.md) - 通知機能のカスタマイズ
7. [Slackスレッドガイド](Slack-Thread-Guide.md) - Slack通知の設定

### 🔧 問題が発生した場合
1. [トラブルシューティングガイド](Troubleshooting.md) - 問題解決方法
2. [テスト・診断ガイド](Testing-Guide.md) - 診断ツールの使用
3. [自動ログインREADME](AutoLogin-README.md) - 自動ログイン問題の場合

### 👨‍💻 開発・保守担当者
1. [共通通知ライブラリ](Common-Notification-Library.md) - 通知機能の共通化アーキテクチャ
2. [テスト・診断ガイド](Testing-Guide.md) - テストツールの理解
3. [WorkflowRoot改善ガイド](WorkflowRoot-Improvement-Guide.md) - 共通処理の理解
4. [Teams通知機能強化](Teams-Notifications-Enhancement.md) - Teams通知の実装
5. [Teamsアダプティブカード実装](Teams-Adaptive-Cards-Implementation.md) - アダプティブカード詳細
6. [カスタマイズガイド](Customization-Guide.md) - 高度なカスタマイズ
7. [トラブルシューティングガイド](Troubleshooting.md) - サポート対応

## ドキュメント間の関連性

```
README.md (メイン)
├── 基本ガイド
│   ├── Registry-Configuration.md
│   ├── Application-Management.md  
│   ├── Customization-Guide.md
│   │   ├─ 参照 → Registry-Configuration.md
│   │   ├─ 参照 → Application-Management.md
│   │   ├─ 参照 → Windows-Update-Guide.md
│   │   └─ 参照 → Troubleshooting.md
│   ├── Windows-Update-Guide.md
│   │   ├─ 参照 → Customization-Guide.md
│   │   ├─ 参照 → Troubleshooting.md
│   │   └─ 参照 → Testing-Guide.md
│   ├── Wi-Fi-Configuration-Guide.md
│   ├── Slack-Thread-Guide.md
│   ├── Troubleshooting.md
│   │   ├─ 参照 → Testing-Guide.md
│   │   └─ 参照 → AutoLogin-README.md
│   ├── Testing-Guide.md
│   │   └─ 参照 → Troubleshooting.md
│   └── AutoLogin-README.md
└── 技術実装詳細
    ├── Teams-Notifications-Enhancement.md
    ├── Teams-Adaptive-Cards-Implementation.md
    └── WorkflowRoot-Improvement-Guide.md
```

## ドキュメントの更新

ドキュメントの更新時は以下を考慮してください：

1. **相互参照の確認**: 関連ドキュメント間のリンクが正しいか
2. **情報の一貫性**: 複数のドキュメントで矛盾がないか
3. **例示の最新性**: コード例や設定例が現在のバージョンと一致するか
4. **図表の更新**: ファイル構成図などが現在の構造と一致するか

詳細な検証項目については[検証ノート](VALIDATION_NOTES.md)を参照してください。

## フィードバック

ドキュメントに関するフィードバックや改善提案がありましたら、GitHubのIssuesまでお知らせください。
