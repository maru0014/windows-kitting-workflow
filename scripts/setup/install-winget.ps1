# ============================================================================
# wingetインストール・設定スクリプト
# Windows Package Manager (winget) のインストールと設定
# ============================================================================

param(
    [switch]$Force,
    [switch]$UpdateSources
)

# UpdateSourcesのデフォルト動作を設定（明示的に-UpdateSources:$falseが指定されない限りtrue）
if (-not $PSBoundParameters.ContainsKey('UpdateSources')) {
    $UpdateSources = $true
}

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

# ログ関数
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    Write-ScriptLog -Message $Message -Level $Level -ScriptName "Winget" -LogFileName "winget.log"
}

# wingetの可用性確認
function Test-WingetInstalled {
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            $versionOutput = & winget --version 2>$null
            $version = $versionOutput -replace 'v', ''
            Write-Log "wingetは既にインストールされています: v$version"
            Write-Log "インストールパス: $($wingetPath.Source)"
            return $true
        }
        else {
            Write-Log "wingetはインストールされていません"
            return $false
        }
    }
    catch {
        Write-Log "wingetの確認でエラー: $($_.Exception.Message)" -Level "WARN"
        return $false
    }
}

# App Installerの確認とインストール
function Install-AppInstaller {
    try {
        Write-Log "App Installerの確認とインストールを開始します"

        # App Installerパッケージの確認
        $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue

        if ($appInstaller) {
            Write-Log "App Installerは既にインストールされています: v$($appInstaller.Version)"
            return $true
        }

        Write-Log "App Installerがインストールされていません。インストールを試行します"

        # Microsoft Storeからのインストールを試行
        try {
            Write-Log "Microsoft Store経由でApp Installerをインストール中..."

            # App Installer の直接ダウンロードURL
            $appInstallerUrl = "https://aka.ms/getwinget"
            $tempPath = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"

            Write-Log "App Installerをダウンロード中: $appInstallerUrl"
            Invoke-WebRequest -Uri $appInstallerUrl -OutFile $tempPath -UseBasicParsing

            Write-Log "App Installerをインストール中..."
            Add-AppxPackage -Path $tempPath -ForceApplicationShutdown

            # 一時ファイルの削除
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue

            # インストールの確認
            Start-Sleep -Seconds 10
            $appInstaller = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue

            if ($appInstaller) {
                Write-Log "App Installerのインストールが完了しました: v$($appInstaller.Version)"
                return $true
            }
            else {
                Write-Log "App Installerのインストールに失敗しました" -Level "ERROR"
                return $false
            }

        }
        catch {
            Write-Log "App Installerのインストールでエラー: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }

    }
    catch {
        Write-Log "App Installerの処理でエラー: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# wingetの基本設定
function Set-WingetConfiguration {
    try {
        Write-Log "wingetの基本設定を行います"

        # wingetソースの更新
        if ($UpdateSources) {
            Write-Log "wingetソースを更新中..."
            & winget source update | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Log "wingetソースの更新が完了しました"
            }
            else {
                Write-Log "wingetソースの更新で問題が発生しました" -Level "WARN"
            }
        }

        # ソース契約の同意
        Write-Log "ソース契約に同意します"
        & winget list --accept-source-agreements | Out-Null

        # インストール契約の事前同意設定
        try {
            Write-Log "インストール時の契約に事前同意するよう設定します"
            & winget settings --set installBehavior.preferences.scope machine 2>$null
            & winget settings --set installBehavior.preferences.locale en-US 2>$null
        }
        catch {
            Write-Log "winget設定の一部で問題が発生しましたが、続行します" -Level "WARN"
        }

        return $true

    }
    catch {
        Write-Log "winget設定でエラー: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# 利用可能なソースの確認
function Test-WingetSources {
    try {
        Write-Log "利用可能なwingetソースを確認します"

        $sources = & winget source list
        Write-Log "利用可能なソース:"
        $sources | ForEach-Object { Write-Log "  $_" }

        # Microsoftストアソースの確認
        $msStoreSource = $sources | Where-Object { $_ -match "msstore" }
        if ($msStoreSource) {
            Write-Log "Microsoft Storeソースが利用可能です"
        }
        else {
            Write-Log "Microsoft Storeソースが利用できません" -Level "WARN"
        }

        # wingetリポジトリの確認
        $wingetSource = $sources | Where-Object { $_ -match "winget" }
        if ($wingetSource) {
            Write-Log "wingetリポジトリが利用可能です"
        }
        else {
            Write-Log "wingetリポジトリが利用できません" -Level "WARN"
        }

        return $true

    }
    catch {
        Write-Log "wingetソース確認でエラー: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# wingetインストール後の確認
function Test-WingetInstallation {
    try {
        Write-Log "wingetインストールの確認を行います"

        # バージョン確認
        $versionOutput = & winget --version 2>$null
        $version = $versionOutput -replace 'v', ''
        Write-Log "wingetバージョン: $version"

        # 機能の確認
        Write-Log "wingetの基本機能を確認中..."

        # ヘルプコマンドの実行
        try {
            & winget --help | Out-Null
            Write-Log "ヘルプコマンドが正常に動作します"
        }
        catch {
            Write-Log "ヘルプコマンドでエラー: $($_.Exception.Message)" -Level "WARN"
        }

        # インストール済みパッケージ数の確認
        try {
            $packages = & winget list 2>$null
            $packageCount = ($packages | Measure-Object).Count
            Write-Log "インストール済みパッケージ数: $packageCount"
        }
        catch {
            Write-Log "パッケージリストの取得でエラー: $($_.Exception.Message)" -Level "WARN"
        }

        return $true

    }
    catch {
        Write-Log "wingetインストール確認でエラー: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# 前提条件の確認
function Test-Prerequisites {
    try {
        Write-Log "前提条件を確認中..."

        # Windowsバージョンの確認
        $osVersion = [System.Environment]::OSVersion.Version
        Write-Log "Windowsバージョン: $osVersion"

        # Windows 10 1809 (Build 17763) 以上が必要
        if ($osVersion.Build -lt 17763) {
            Write-Log "wingetにはWindows 10 1809 (Build 17763) 以上が必要です" -Level "ERROR"
            return $false
        }

        # PowerShellバージョンの確認
        $psVersion = $PSVersionTable.PSVersion
        Write-Log "PowerShellバージョン: $psVersion"

        # 管理者権限の確認
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin) {
            Write-Log "管理者権限で実行することを推奨します" -Level "WARN"
        }
        else {
            Write-Log "管理者権限で実行されています"
        }

        # プログレスバーを無効化
        $originalProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # インターネット接続の確認
        try {
            $testConnection = Test-NetConnection -ComputerName "www.microsoft.com" -Port 443 -InformationLevel Quiet
            if ($testConnection) {
                Write-Log "インターネット接続を確認しました"
            }
            else {
                Write-Log "インターネット接続が利用できません" -Level "WARN"
                return $false
            }
        }
        catch {
            Write-Log "インターネット接続の確認でエラー: $($_.Exception.Message)" -Level "WARN"
        }
        # プログレスバー設定を元に戻す
        $ProgressPreference = $originalProgressPreference

        return $true

    }
    catch {
        Write-Log "前提条件の確認でエラー: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

try {
    Write-Log "wingetインストール・設定処理を開始します"

    # 既にインストールされているかチェック
    if (Test-WingetInstalled -and -not $Force) {
        Write-Log "wingetは既に利用可能です。設定のみ実行します"

        # 設定の実行
        Set-WingetConfiguration
        Test-WingetSources

        # 完了マーカーの作成
        $completionMarker = Get-CompletionMarkerPath -TaskName "winget"
        @{
            completedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            action      = "already_available"
            version     = (& winget --version 2>$null)
        } | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

        exit 0
    }

    # 前提条件の確認
    if (-not (Test-Prerequisites)) {
        throw "前提条件を満たしていません"
    }

    # App Installerのインストール（wingetが含まれる）
    if (-not (Install-AppInstaller)) {
        throw "App Installerのインストールに失敗しました"
    }

    # wingetの利用可能性を再確認
    if (-not (Test-WingetInstalled)) {
        throw "wingetが利用できません"
    }

    # 基本設定
    if (-not (Set-WingetConfiguration)) {
        throw "wingetの設定に失敗しました"
    }

    # ソースの確認
    if (-not (Test-WingetSources)) {
        Write-Log "wingetソースの確認で問題が発生しましたが、続行します" -Level "WARN"
    }

    # インストール後の確認
    Test-WingetInstallation

    Write-Log "wingetのインストールと設定が正常に完了しました"

    # 完了マーカーの作成
    $completionMarker = Get-CompletionMarkerPath -TaskName "winget"
    @{
        completedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        action      = "installed"
        version     = (& winget --version 2>$null)
    } | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

    exit 0

}
catch {
    Write-Log "wingetインストール・設定処理でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
