# Windows Kitting Workflow

## 概要

Windows Kitting Workflowは、Windows 11 PCを完全自動でセットアップするためのワークフローシステムです。PowerShellとJSON設定ファイルを使用して、アプリケーションのインストール、レジストリ設定、システム最適化を自動実行します。

### 主な特徴

- **完全自動化**: ユーザー介入なしでPCセットアップを実行
- **JSON設定**: 実行順序と設定をJSONファイルで簡単管理
- **winget統合**: Microsoft公式パッケージマネージャーによる安全なアプリ管理
- **レジストリ最適化**: セキュリティ・パフォーマンス向上のための設定自動適用
- **エラー通知**: Slack/Teams連携によるリアルタイム通知
- **自動継続**: 再起動後も自動的にセットアップを継続
- **安全なバックアップ**: レジストリ変更前の自動バックアップ

## ファイル構成

```
windows-kitting-workflow/
├── README.md                     # このファイル
├── main.bat                     # メインエントリーポイント
├── unblock-files.bat            # セキュリティブロック一括解除
├── MainWorkflow.ps1             # メインワークフローエンジン
├── AutoLogin.ps1                # 自動ログイン設定管理
├── TaskScheduler.ps1            # タスクスケジューラ管理
├── config/                      # 設定ファイル
│   ├── workflow.json            # ワークフロー設定
│   ├── applications.json        # アプリケーション設定
│   ├── notifications.json       # 通知設定
│   ├── autologin.json          # 自動ログイン設定
│   ├── machine_list.csv         # マシンリスト（オプション）
│   ├── desktop/                # デスクトップファイル
│   │   ├── public/             # パブリック用
│   │   └── user/               # ユーザー用
│   └── registry/               # レジストリ設定ファイル
├── scripts/                     # スクリプトファイル
│   ├── Common-LogFunctions.ps1  # 共通ログ関数
│   ├── Unblock-AllFiles.ps1    # セキュリティブロック一括解除
│   ├── setup/                  # セットアップスクリプト
│   └── cleanup/                # クリーンアップスクリプト
├── docs/                       # ドキュメント
│   ├── README.md                    # ドキュメント一覧とナビゲーション
│   ├── Registry-Configuration.md    # レジストリ設定詳細
│   ├── Application-Management.md    # アプリケーション管理
│   ├── Customization-Guide.md      # カスタマイズガイド
│   ├── Windows-Update-Guide.md     # Windows Update詳細
│   ├── Wi-Fi-Configuration-Guide.md # Wi-Fi設定ガイド
│   ├── Slack-Thread-Guide.md       # Slackスレッド詳細
│   ├── Troubleshooting.md          # トラブルシューティング
│   ├── Testing-Guide.md            # テスト・診断ガイド
│   ├── AutoLogin-README.md         # 自動ログイン詳細
│   ├── Teams-Notifications-Enhancement.md  # Teams通知改善詳細
│   ├── Teams-Adaptive-Cards-Implementation.md  # Teams実装詳細
│   └── WorkflowRoot-Improvement-Guide.md  # WorkflowRoot改善詳細
├── tests/                      # テスト・診断ツール
│   ├── README.md               # テストガイド
│   ├── Run-AllTests.ps1        # テストランナー
│   ├── Test-JsonConfiguration.ps1  # JSON検証
│   ├── Test-ProjectStructure.ps1   # プロジェクト構造検証
│   ├── run-tests.bat          # 簡単テスト実行
│   └── run-tests-advanced.bat # 高度テスト実行
└── 自動生成フォルダ（実行時作成）
    ├── backup/                 # バックアップファイル
    ├── status/                 # ステータス管理
    └── logs/                   # ログファイル
```

## クイックスタート

### 前提条件

- Windows 11 または Windows 10 1809以降
- PowerShell 5.1以上
- インターネット接続

### ⚠️ 重要: セキュリティブロック解除

インターネットからダウンロードしたファイルには、Windowsによってセキュリティブロックが設定されます。このワークフローを実行する前に、以下のコマンドでセキュリティブロックを解除してください：

```batch
# 最も簡単な方法（バッチファイル実行）
.\unblock-files.bat

# または PowerShell で直接実行
.\scripts\Unblock-AllFiles.ps1 -Recurse
```

詳細な手順は[ファイルセキュリティブロック解除ガイド](docs/File-Security-Unblock-Guide.md)を参照してください。

### 基本的な使用方法

1. **フォルダをCドライブに配置**
   ```
   C:\windows-kitting-workflow\
   ```

2. **main.batを右クリックして「管理者として実行」を選択**

以上。

セットアップが開始されると、自動ログインとタスクスケジューラが設定され、PC再起動後も自動的に処理が継続されます。

## インストールされる内容

### 基本アプリケーション
- **開発ツール**: PowerShell 7, Git, Visual Studio Code
- **ユーティリティ**: 7-Zip, PowerToys  
- **生産性**: Google 日本語入力, Adobe Acrobat Reader
- **ブラウザ**: Google Chrome, Mozilla Firefox
- **メディア**: VLC Media Player
- **コミュニケーション**: Microsoft Teams, Zoom

### システム最適化
- **エクスプローラー設定**: ファイル拡張子表示でセキュリティ向上
- **パフォーマンス設定**: 応答性向上、視覚効果最適化
- **プライバシー設定**: 不要な情報収集・広告配信の抑制
- **BitLocker暗号化**: TPMベースのシステムドライブ暗号化
- **タスクバー調整**: 不要なボタンの非表示

詳細は[レジストリ設定ガイド](docs/Registry-Configuration.md)を参照してください。

## カスタマイズ

### アプリケーションの追加・変更
`config/applications.json`を編集してインストールアプリをカスタマイズできます。
詳細は[アプリケーション管理ガイド](docs/Application-Management.md)を参照してください。

### ワークフローの変更
`config/workflow.json`を編集して実行順序や処理内容をカスタマイズできます。

#### Windows Updateの設定
Windows Updateステップでは以下のカスタマイズが可能です：
- 特定のKB番号のアップデートのみインストール
- 特定のアップデートを除外してインストール
- Microsoft Updateサービスの含有/除外
- 自動再起動の有効/無効

詳細は[カスタマイズガイド](docs/Customization-Guide.md)を参照してください。

### 通知設定
Slack/Teams Webhookを設定することで、進捗状況をリアルタイムで確認できます。
`config/notifications.json`で設定してください。

#### Slackスレッド機能
PCごとにSlackスレッドを分けて通知することが可能です。複数PCの同時セットアップでも各PCの進捗を個別に追跡できます。
詳細は[Slackスレッドガイド](docs/Slack-Thread-Guide.md)を参照してください。

## トラブルシューティング

### セキュリティエラーが発生する場合

PowerShell実行ポリシーエラーや「ファイルがブロックされています」エラーが発生した場合：

```batch
# セキュリティブロック解除
.\unblock-files.bat

# または実行ポリシーを一時的に変更
powershell -ExecutionPolicy Bypass -File "main.bat"
```

### その他の問題

問題が発生した場合は以下の診断ツールを使用してください：

```powershell
# 包括的な健全性チェック
.\tests\Run-AllTests.ps1 -Verbose

# JSON設定ファイルの検証・修正
.\tests\Test-JsonConfiguration.ps1 -Fix

# プロジェクト構造の詳細診断
.\tests\Test-ProjectStructure.ps1 -Verbose
```

よくある問題と解決方法は[トラブルシューティングガイド](docs/Troubleshooting.md)を参照してください。

## ドキュメント

### 📚 基本ガイド（ユーザー向け）
- **[ドキュメントREADME](docs/README.md)**: 全ドキュメントの概要とナビゲーション
- **[ファイルセキュリティブロック解除ガイド](docs/File-Security-Unblock-Guide.md)**: ダウンロードファイルのブロック解除方法
- **[レジストリ設定ガイド](docs/Registry-Configuration.md)**: システム最適化設定の詳細
- **[アプリケーション管理ガイド](docs/Application-Management.md)**: アプリインストールの管理方法
- **[BitLocker設定ガイド](docs/BitLocker-Configuration-Guide.md)**: BitLocker暗号化の自動設定
- **[カスタマイズガイド](docs/Customization-Guide.md)**: ワークフローのカスタマイズ方法
- **[Windows Updateガイド](docs/Windows-Update-Guide.md)**: Windows Update設定の詳細
- **[Wi-Fi設定ガイド](docs/Wi-Fi-Configuration-Guide.md)**: Wi-Fi自動設定機能の詳細
- **[Slackスレッドガイド](docs/Slack-Thread-Guide.md)**: Slackスレッド機能の使用方法
- **[トラブルシューティングガイド](docs/Troubleshooting.md)**: 問題解決方法
- **[テスト・診断ガイド](docs/Testing-Guide.md)**: テストツールの使用方法
- **[自動ログインREADME](docs/AutoLogin-README.md)**: 自動ログイン機能の詳細

### 🔧 技術実装詳細（開発者向け）
- **[共通通知ライブラリ](docs/Common-Notification-Library.md)**: 通知機能の共通化とアーキテクチャ
- **[Teams通知機能強化](docs/Teams-Notifications-Enhancement.md)**: Teams通知機能の改善実装詳細
- **[Teamsアダプティブカード実装](docs/Teams-Adaptive-Cards-Implementation.md)**: アダプティブカード対応実装
- **[WorkflowRoot改善ガイド](docs/WorkflowRoot-Improvement-Guide.md)**: 共通処理改善の実装詳細

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 注意事項

このツールは管理者権限で実行され、システムに重要な変更を加える可能性があります。本番環境で使用する前に、テスト環境で十分に検証してください。
