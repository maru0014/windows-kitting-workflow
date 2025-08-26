# トラブルシューティングガイド

## 概要

Windows Kitting Workflowの実行中に発生する可能性のある問題と、その解決方法について説明します。

## よくある問題と解決方法

### 1. PowerShell実行ポリシーエラー

**症状**:
```
このシステムではスクリプトの実行が無効になっているため、ファイル XXX.ps1 を読み込むことができません。
```

**解決方法**:
```powershell
# 現在のユーザーでの実行ポリシーを変更
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 管理者権限での実行ポリシー変更（推奨）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

**確認方法**:
```powershell
# 現在の実行ポリシーを確認
Get-ExecutionPolicy -List
```

### 2. タスクスケジューラ登録失敗

**症状**:
```
タスクスケジューラへの登録に失敗しました
```

**原因と解決方法**:
1. **管理者権限の不足**
   - PowerShellまたはコマンドプロンプトを「管理者として実行」で起動

2. **スクリプトパスの問題**
   ```powershell
   # フルパスを確認
   $scriptPath = (Get-Location).Path + "\MainWorkflow.ps1"
   Write-Host "スクリプトパス: $scriptPath"
   ```

3. **Windows Defenderによるブロック**
   - Windows Defenderの設定でスクリプトの実行を許可
   - フォルダを除外リストに追加

**手動でのタスク確認**:
```powershell
# タスクスケジューラの確認
Get-ScheduledTask -TaskName "WindowsKittingWorkflow*"

# タスクの手動削除（必要に応じて）
Unregister-ScheduledTask -TaskName "WindowsKittingWorkflow-AutoContinue" -Confirm:$false
```

### 3. JSON設定ファイルエラー

**症状**:
```
設定ファイルの読み込みに失敗しました： '：' または '}' ではなく無効なオブジェクトが渡されました。
```

**原因**:
- 全角文字（：，｛｝など）の混入
- BOM（Byte Order Mark）の問題
- JSON構文エラー

**診断と修正**:
```powershell
# 診断ツールで確認
.\tests\Test-JsonConfiguration.ps1 -Verbose

# 自動修正を試行
.\tests\Test-JsonConfiguration.ps1 -Fix

# 特定ファイルのテスト
.\tests\Test-JsonConfiguration.ps1 -ConfigPath "config\workflow.json"
```

**手動修正方法**:
1. **全角文字の確認と修正**
   - `：` → `:`
   - `，` → `,`
   - `｛｝` → `{}`

2. **BOMの削除**
   ```powershell
   # UTF-8 without BOMで保存
   $content = Get-Content "config\workflow.json" -Raw
   [System.IO.File]::WriteAllText("config\workflow.json", $content, [System.Text.UTF8Encoding]::new($false))
   ```

### 4. wingetインストール失敗

**症状**:
```
winget: コマンドが見つかりません
```

**解決方法**:
1. **前提条件の確認**
   - Windows 10 1809以降またはWindows 11が必要
   - Microsoft Storeの利用可能性を確認

2. **App Installerの手動インストール**
   ```powershell
   # Microsoft Storeを開いてApp Installerを検索・インストール
   start ms-windows-store://search/?query=app%20installer
   ```

3. **winget手動インストール**
   ```powershell
   # GitHubからの直接ダウンロード（管理者権限必要）
   Invoke-RestMethod -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "winget.msixbundle"
   Add-AppxPackage -Path "winget.msixbundle"
   ```

**wingetの動作確認**:
```powershell
# wingetのバージョン確認
winget --version

# ソースの更新
winget source update

# 利用可能なソースの確認
winget source list
```

### 5. ネットワーク接続エラー

**症状**:
- アプリケーションのダウンロードに失敗
- Windows Update実行時のエラー

**解決方法**:
1. **基本的な接続確認**
   ```powershell
   # インターネット接続テスト
   Test-NetConnection -ComputerName "8.8.8.8" -Port 53
   
   # DNSの確認
   Resolve-DnsName "microsoft.com"
   ```

2. **プロキシ設定の確認**
   ```powershell
   # プロキシ設定の確認
   Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" | Select-Object ProxyServer, ProxyEnable
   
   # wingetプロキシ設定
   winget settings
   ```

3. **ファイアウォール設定**
   - Windows Defenderファイアウォールの設定確認
   - 企業環境の場合、IT部門への相談

### 6. アプリケーションインストール失敗

**症状**:
特定のアプリケーションのインストールが失敗する

**診断方法**:
```powershell
# インストールログの確認
Get-Content logs\scripts\basic-apps.log -Tail 50

# 特定アプリのエラー検索
Select-String "エラー|error|failed" logs\scripts\basic-apps.log

# wingetでの手動確認
winget search "アプリ名"
winget install "パッケージID"
```

**解決方法**:
1. **パッケージIDの確認**
   ```powershell
   # 正確なパッケージIDを検索
   winget search --exact "アプリ名"
   ```

2. **管理者権限での実行**
   - 一部のアプリケーションは管理者権限が必要

3. **依存関係の確認**
   - 前提条件となるアプリケーションがインストールされているか

### 7. レジストリ設定が適用されない

**症状**:
レジストリファイルを実行しても設定が反映されない

**解決方法**:
1. **ログオフ・ログオンの実行**
   - 一部の設定は再ログインが必要

2. **レジストリの手動確認**
   ```powershell
   # 設定値の確認
   Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt"
   ```

3. **バックアップからの復元**
   ```powershell
   # バックアップファイルの一覧
   Get-ChildItem backup\registry\

   # 特定のバックアップを復元（ダブルクリックまたは）
   regedit /s "backup\registry\backup_20231201_142030.reg"
   ```

### 8. 自動ログイン設定の問題

**症状**:
自動ログインが機能しない

**解決方法**:
1. **設定の確認**
   ```powershell
   # 自動ログイン設定の確認
   Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon
   ```

2. **パスワードポリシーの確認**
   - 複雑なパスワード要件がある場合
   - アカウントロックアウトポリシーの確認

3. **手動での設定削除**
   ```powershell
   # 自動ログイン設定を手動で削除
   .\AutoLogin.ps1 -Action Remove
   ```

詳細は[自動ログインREADME](AutoLogin-README.md)を参照してください。

### 9. Windows Update実行失敗

**症状**:
- PSWindowsUpdateモジュールのインストール失敗
- Windows Updateサービスの開始失敗
- アップデートのダウンロード/インストール失敗

**診断方法**:
```powershell
# Windows Updateログの確認
Get-Content logs\windows-update.log -Tail 50

# Windows Updateサービスの状態確認
Get-Service -Name wuauserv, bits, cryptsvc, msiserver

# PSWindowsUpdateモジュールの確認
Get-Module -Name PSWindowsUpdate -ListAvailable
```

**解決方法**:

#### 1. PSWindowsUpdateモジュールの問題
```powershell
# 手動インストール
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser

# モジュールのインポート確認
Import-Module PSWindowsUpdate -Force
Get-Command -Module PSWindowsUpdate
```

#### 2. Windows Updateサービスの問題
```powershell
# サービスの手動開始
Start-Service -Name wuauserv
Start-Service -Name bits
Start-Service -Name cryptsvc

# サービスの自動開始設定
Set-Service -Name wuauserv -StartupType Automatic
```

#### 3. Windows Updateキャッシュの問題
```powershell
# Windows Updateキャッシュのクリア（管理者権限で実行）
Stop-Service -Name wuauserv, bits -Force
Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force
Start-Service -Name wuauserv, bits
```

#### 4. 特定のKBアップデートの問題
```powershell
# 問題のあるKBを除外して実行
.\scripts\setup\windows-update.ps1 -NotKBArticleID @("KB5034763")

# セキュリティアップデートのみ実行
.\scripts\setup\windows-update.ps1 -KBArticleID @("KB5034441", "KB5034123")
```

#### 5. Microsoft Updateの問題
```powershell
# Windows Updateのみ実行（Microsoft Update除外）
.\scripts\setup\windows-update.ps1 -MicrosoftUpdate $false
```

**Windows Updateトラブルシューティングツール**:
```powershell
# Windows Update トラブルシューティングツールの実行
msdt.exe /id WindowsUpdateDiagnostic
```

**高度なトラブルシューティング**:
```powershell
# Windows Update コンポーネントのリセット
# 以下のコマンドを管理者権限で実行

net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
ren C:\Windows\System32\catroot2 catroot2.old

net start wuauserv
net start cryptSvc
net start bits
net start msiserver
```

## ログの活用方法

### メインログの確認

```powershell
# 最新のログエントリを確認
Get-Content logs\workflow.log -Tail 20

# エラーのみを抽出
Select-String "ERROR|エラー" logs\workflow.log

# 特定の日時のログを確認
Get-Content logs\workflow.log | Where-Object { $_ -match "2023-12-01" }
```

### スクリプト別ログの確認

```powershell
# 各スクリプトのログファイル
Get-ChildItem logs\scripts\

# 特定スクリプトのログ
Get-Content logs\scripts\initialize.log
Get-Content logs\scripts\winget.log
Get-Content logs\scripts\basic-apps.log
```

### ログエンコーディングの確認

```powershell
# UTF-8 with BOMの確認
$bytes = [System.IO.File]::ReadAllBytes("logs\workflow.log")
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "UTF-8 with BOMで出力されています" -ForegroundColor Green
} else {
    Write-Host "UTF-8 with BOMではありません" -ForegroundColor Yellow
}
```

## 診断ツールの活用

### 包括テストの実行

```powershell
# 全体的な健全性チェック
.\tests\Test-Complete.ps1 -Verbose

# 問題の自動修正を試行
.\tests\Test-Complete.ps1 -FixIssues
```

### 段階的な診断

```powershell
# 1. JSON設定ファイルの検証
.\tests\Test-JsonConfiguration.ps1

# 2. プロジェクト構造の検証
.\tests\Test-ProjectStructure.ps1

# 3. 包括的テスト実行
.\tests\Run-AllTests.ps1 -Verbose
```

## 緊急時の対処

### ワークフローの強制停止

```powershell
# タスクスケジューラから削除
Get-ScheduledTask -TaskName "WindowsKittingWorkflow*" | Unregister-ScheduledTask -Confirm:$false

# 自動ログインの無効化
.\AutoLogin.ps1 -Action Remove -Force
```

### システムの復元

1. **レジストリの復元**
   ```powershell
   # バックアップから復元
   Get-ChildItem backup\registry\ | Sort-Object Name -Descending | Select-Object -First 1 | ForEach-Object { regedit /s $_.FullName }
   ```

2. **手動でのクリーンアップ**
   ```powershell
   # 一時ファイルの削除
   Remove-Item status\*.completed -Force  # 既定のステップIDベース完了マーカー
   Remove-Item logs\*.log -Force
   ```

## サポートが必要な場合

### 情報収集

以下の情報を収集してサポートに連絡してください：

```powershell
# システム情報
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, WindowsBuildLabEx

# PowerShellバージョン
$PSVersionTable

# 実行ポリシー
Get-ExecutionPolicy -List

# エラーログ
Get-Content logs\workflow.log -Tail 50
```

### ログの出力

```powershell
# 診断情報を一括出力
.\tests\Test-Complete.ps1 -Verbose > diagnostic-output.txt 2>&1
```

## 関連ドキュメント
- [メインREADME](../README.md)
- [テスト・診断ガイド](Testing-Guide.md)
- [カスタマイズガイド](Customization-Guide.md)
- [自動ログインREADME](AutoLogin-README.md)
