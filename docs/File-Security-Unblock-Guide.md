# ファイルセキュリティブロック解除ガイド

## 概要
インターネットからダウンロードしたファイルには、Windowsによってセキュリティブロック（Zone.Identifier）が設定されます。このブロックにより、PowerShellスクリプトや実行ファイルが実行できなくなります。

## 問題の症状
- PowerShellスクリプトを実行しようとすると「実行ポリシーによりブロックされています」エラーが発生
- ファイルのプロパティに「このファイルは他のコンピューターから取得したものです」チェックボックスが表示される

## 解決方法

### 方法1: 自動一括解除（推奨）

#### バッチファイルを使用（最も簡単）
```batch
# プロジェクトのルートディレクトリで実行
.\unblock-files.bat
```

#### PowerShellスクリプトを直接使用
```powershell
# 現在のディレクトリとサブディレクトリのすべてのファイルを処理
.\scripts\Unblock-AllFiles.ps1 -Recurse

# 事前確認（実際には処理しない）
.\scripts\Unblock-AllFiles.ps1 -Recurse -WhatIf

# 特定のディレクトリのみ処理
.\scripts\Unblock-AllFiles.ps1 -Path "C:\MyFolder" -Recurse
```

### 方法2: PowerShellワンライナー

```powershell
# すべてのファイルを一括解除
Get-ChildItem -Recurse | Unblock-File

# 特定の拡張子のみ
Get-ChildItem -Recurse -Include "*.ps1", "*.bat", "*.exe" | Unblock-File

# PowerShellスクリプトのみ
Get-ChildItem -Recurse -Filter "*.ps1" | Unblock-File
```

### 方法3: 実行ポリシーの変更

```powershell
# 現在のユーザーのみに適用（推奨）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# システム全体に適用（管理者権限が必要）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

## 対象ファイル拡張子

自動解除スクリプトは以下の拡張子のファイルを対象とします：
- `.ps1` - PowerShellスクリプト
- `.bat` - バッチファイル
- `.cmd` - コマンドファイル
- `.exe` - 実行ファイル
- `.msi` - Windowsインストーラー
- `.zip` - 圧縮ファイル
- `.reg` - レジストリファイル

## 安全性について

- `Unblock-File`コマンドは、Zone.Identifierストリームを削除するだけです
- ファイル自体は変更されません
- `-WhatIf`パラメータを使用して事前確認できます
- 信頼できるソースからダウンロードしたファイルのみに使用してください

## トラブルシューティング

### 実行ポリシーエラーが発生する場合
```powershell
# 一時的にポリシーをバイパス
powershell -ExecutionPolicy Bypass -File ".\scripts\Unblock-AllFiles.ps1"
```

### 管理者権限が必要な場合
```powershell
# PowerShellを管理者として実行してから実行
Start-Process powershell -Verb RunAs
```

### 特定のファイルが解除できない場合
- ファイルが使用中でないか確認
- 管理者権限でPowerShellを実行
- ウイルス対策ソフトが干渉していないか確認

## 参考情報

- [about_Execution_Policies](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [Unblock-File](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file)
