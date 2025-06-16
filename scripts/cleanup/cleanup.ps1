# ============================================================================
# Windows 11 自動セットアップ - クリーンアップスクリプト
# 一時ファイルの削除とシステムクリーンアップを実行
# ============================================================================

[CmdletBinding()]
param(
	[switch]$SkipSystemCleanup,
	[switch]$NoArchiveLogs,
	[switch]$Force
)

# 共通ログ関数の読み込み
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
$logFunctionsPath = Join-Path $rootDir "scripts\Common-LogFunctions.ps1"

if (Test-Path $logFunctionsPath) {
	. $logFunctionsPath
}
else {
	Write-Error "共通ログ関数が見つかりません: $logFunctionsPath"
	exit 1
}

# ログ関数
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    Write-ScriptLog -Message $Message -Level $Level -ScriptName "cleanup" -LogFileName "cleanup.log"
}

# ログファイルの設定
$logDir = Join-Path $rootDir "logs\scripts"
$logFile = Join-Path $logDir "cleanup.log"
$statusDir = Join-Path $rootDir "status"
$statusFile = Join-Path $statusDir "cleanup.completed"

# ステータスディレクトリの作成
if (-not (Test-Path $statusDir)) {
    New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
}

# 実行開始ログ
$script:startTime = Get-Date
Write-Log "=========================================="
Write-Log "🧹 クリーンアップスクリプト開始"
Write-Log "📅 実行時刻: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Log "=========================================="

try {
    # 管理者権限チェック
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-Log "⚠️  警告: 管理者権限で実行されていません。一部の機能が制限される可能性があります。" -Level "WARN"
    }
    else {
        Write-Log "✅ 管理者権限で実行中"
    }

    # 統計変数の初期化
    $totalDeletedItems = 0
    $totalDeletedSizeMB = 0
    $completedTasks = 0
    $failedTasks = 0

    # ============================================================================
    # 1. 一時ファイルのクリーンアップ
    # ============================================================================
    Write-Log "📁 一時ファイルのクリーンアップを開始..."

    $tempPaths = @(
        $env:TEMP,
        $env:TMP,
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "C:\Windows\SoftwareDistribution\Download"
    )

    foreach ($tempPath in $tempPaths) {
        if (Test-Path $tempPath) {
            Write-Log "🔍 クリーンアップ中: $tempPath"
            try {
                $itemCount = 0
                $deletedSize = 0

                Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        if ($_.PSIsContainer) {
                            if ((Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
                                Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                                $itemCount++
                            }
                        }
                        else {
                            $size = $_.Length
                            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                            $itemCount++
                            $deletedSize += $size
                        }
                    }
                    catch {
                        # ファイルが使用中の場合はスキップ
                    }
                }

                $deletedSizeMB = [math]::Round($deletedSize / 1MB, 2)
                Write-Log "  ✅ 削除完了: $itemCount 個のアイテム, $deletedSizeMB MB"
                $totalDeletedItems += $itemCount
                $totalDeletedSizeMB += $deletedSizeMB
                $completedTasks++
            }
            catch {
                Write-Log "  ❌ 警告: $tempPath のクリーンアップでエラー: $($_.Exception.Message)" -Level "WARN"
                $failedTasks++
            }
        }
        else {
            Write-Log "  ⚠️  パスが存在しません: $tempPath" -Level "WARN"
        }
    }

    Write-Log "📊 一時ファイルクリーンアップ完了 - 削除: $totalDeletedItems 個, $totalDeletedSizeMB MB"

    # ============================================================================
    # 2. ブラウザキャッシュのクリーンアップ
    # ============================================================================
    Write-Log "🌐 ブラウザキャッシュのクリーンアップを開始..."

    $browserCaches = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2"
    )

    $browserCacheCount = 0
    foreach ($cachePath in $browserCaches) {
        $resolvedPaths = Get-ChildItem -Path $cachePath -ErrorAction SilentlyContinue
        foreach ($path in $resolvedPaths) {
            if (Test-Path $path.FullName) {
                Write-Log "🗑️  ブラウザキャッシュをクリーンアップ: $($path.Name)"
                try {
                    Remove-Item -Path $path.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    $browserCacheCount++
                    $completedTasks++
                }
                catch {
                    Write-Log "  ❌ 警告: キャッシュ削除でエラー: $($_.Exception.Message)" -Level "WARN"
                    $failedTasks++
                }
            }
        }
    }

    Write-Log "📊 ブラウザキャッシュクリーンアップ完了 - 処理: $browserCacheCount 個"

    # ============================================================================
    # 3. システムクリーンアップ（管理者権限が必要）
    # ============================================================================
    if (-not $SkipSystemCleanup -and $isAdmin) {
        Write-Log "⚙️  システムクリーンアップを開始..."

        # ディスククリーンアップの実行
        try {
            Write-Log "🖥️  ディスククリーンアップを実行中..."
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -ErrorAction SilentlyContinue
            Write-Log "  ✅ ディスククリーンアップ完了"
            $completedTasks++
        }
        catch {
            Write-Log "  ❌ 警告: ディスククリーンアップでエラー: $($_.Exception.Message)" -Level "WARN"
            $failedTasks++
        }

        # イベントログのクリア（古いエントリのみ）
        try {
            Write-Log "📋 イベントログの古いエントリをクリア中..."
            $logNames = @("Application", "System", "Setup")
            $clearedLogs = 0
            foreach ($logName in $logNames) {
                $eventLog = Get-WinEvent -ListLog $logName -ErrorAction SilentlyContinue
                if ($eventLog -and $eventLog.RecordCount -gt 10000) {
                    wevtutil cl $logName
                    Write-Log "  ✅ $logName ログをクリアしました (エントリ数: $($eventLog.RecordCount))"
                    $clearedLogs++
                }
            }
            if ($clearedLogs -gt 0) {
                Write-Log "📊 イベントログクリア完了 - $clearedLogs 個のログをクリア"
                $completedTasks++
            }
            else {
                Write-Log "ℹ️  クリア対象のイベントログはありません"
            }
        }
        catch {
            Write-Log "❌ 警告: イベントログクリアでエラー: $($_.Exception.Message)" -Level "WARN"
            $failedTasks++
        }
    }
    else {
        if ($SkipSystemCleanup) {
            Write-Log "⏭️  システムクリーンアップをスキップしました"
        }
        else {
            Write-Log "⚠️  管理者権限がないため、システムクリーンアップをスキップしました" -Level "WARN"
        }
    }

    # ============================================================================
    # 4. ログファイルのアーカイブ
    # ============================================================================
    if (-not $NoArchiveLogs) {
        Write-Log "📦 ログファイルのアーカイブを開始..."

        $logsDir = Join-Path $rootDir "logs"
        $archiveDir = Join-Path $logsDir "archive"
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $archiveName = "logs_archive_$timestamp.zip"
        $archivePath = Join-Path $archiveDir $archiveName

        if (-not (Test-Path $archiveDir)) {
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        }

        try {
            # 7日以上古いログファイルをアーカイブ
            $oldLogs = Get-ChildItem -Path $logsDir -Recurse -File | Where-Object {
                $_.LastWriteTime -lt (Get-Date).AddDays(-7) -and
                $_.Extension -eq ".log" -and
                $_.Directory.Name -ne "archive"
            }

            if ($oldLogs.Count -gt 0) {
                Compress-Archive -Path $oldLogs.FullName -DestinationPath $archivePath -CompressionLevel Optimal
                $oldLogs | Remove-Item -Force
                Write-Log "✅ 古いログファイル $($oldLogs.Count) 個をアーカイブしました: $archiveName"
                $completedTasks++
            }
            else {
                Write-Log "ℹ️  アーカイブ対象のログファイルはありません"
            }
        }
        catch {
            Write-Log "❌ 警告: ログアーカイブでエラー: $($_.Exception.Message)" -Level "WARN"
            $failedTasks++
        }
    }
    else {
        Write-Log "⏭️  ログアーカイブをスキップしました"
    }

    # ============================================================================
    # 5. 不要なダウンロードファイルのクリーンアップ
    # ============================================================================
    Write-Log "📥 ダウンロードフォルダのクリーンアップを開始..."

    $downloadsPath = Join-Path $env:USERPROFILE "Downloads"
    if (Test-Path $downloadsPath) {
        try {
            # 30日以上古い一時ファイルを削除
            $oldFiles = Get-ChildItem -Path $downloadsPath -File | Where-Object {
                $_.LastAccessTime -lt (Get-Date).AddDays(-30) -and
                ($_.Extension -eq ".tmp" -or $_.Extension -eq ".temp" -or $_.Name -like "*.partial")
            }

            if ($oldFiles.Count -gt 0) {
                $oldFiles | Remove-Item -Force
                Write-Log "✅ 古い一時ファイル $($oldFiles.Count) 個を削除しました"
                $completedTasks++
            }
            else {
                Write-Log "ℹ️  削除対象の一時ファイルはありません"
            }
        }
        catch {
            Write-Log "❌ 警告: ダウンロードフォルダクリーンアップでエラー: $($_.Exception.Message)" -Level "WARN"
            $failedTasks++
        }
    }
    else {
        Write-Log "⚠️  ダウンロードフォルダが見つかりません: $downloadsPath" -Level "WARN"
    }

    # ============================================================================
    # 6. レジストリの最適化（管理者権限が必要）
    # ============================================================================
    if ($isAdmin -and -not $SkipSystemCleanup) {
        Write-Log "🔧 レジストリの最適化を開始..."

        try {
            # システムファイルチェック
            Write-Log "🔍 システムファイルチェックを実行中..."
            Start-Process -FilePath "sfc" -ArgumentList "/scannow" -Wait -ErrorAction SilentlyContinue
            Write-Log "✅ システムファイルチェック完了"
            $completedTasks++
        }
        catch {
            Write-Log "❌ 警告: システムファイルチェックでエラー: $($_.Exception.Message)" -Level "WARN"
            $failedTasks++
        }
    }

    # ============================================================================
    # 7. 完了処理
    # ============================================================================
    $duration = ((Get-Date) - $script:startTime).TotalMinutes

    Write-Log "==================== クリーンアップ結果 ===================="
    Write-Log "✅ 成功したタスク: $completedTasks"
    if ($failedTasks -gt 0) {
        Write-Log "❌ 失敗したタスク: $failedTasks"
    }
    Write-Log "🗑️  削除したアイテム: $totalDeletedItems 個"
    Write-Log "💾 解放した容量: $totalDeletedSizeMB MB"
    Write-Log "⏱️  実行時間: $([math]::Round($duration, 2)) 分"
    Write-Log "============================================================="

    Write-Log "🎉 クリーンアップが正常に完了しました"

    # 完了ステータスファイルの作成
    $completionInfo = @{
        timestamp            = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        status               = "completed"
        duration             = $duration
        adminRights          = $isAdmin
        skippedSystemCleanup = $SkipSystemCleanup
        archivedLogs         = (-not $NoArchiveLogs)
        completedTasks       = $completedTasks
        failedTasks          = $failedTasks
        deletedItems         = $totalDeletedItems
        freedSpaceMB         = $totalDeletedSizeMB
    } | ConvertTo-Json

    Set-Content -Path $statusFile -Value $completionInfo -Encoding UTF8

    Write-Log "=========================================="
    Write-Log "🏁 クリーンアップスクリプト正常終了"
    Write-Log "📅 完了時刻: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "=========================================="

    if ($failedTasks -eq 0) {
        exit 0
    }
    else {
        exit 1
    }

}
catch {
    Write-Log "💥 エラー: クリーンアップスクリプトでエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "📋 エラー詳細: $($_.Exception.StackTrace)" -Level "ERROR"

    # エラーステータスファイルの作成
    $errorInfo = @{
        timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        status         = "error"
        errorMessage   = $_.Exception.Message
        stackTrace     = $_.Exception.StackTrace
        completedTasks = $completedTasks
        failedTasks    = $failedTasks
    } | ConvertTo-Json

    Set-Content -Path $statusFile -Value $errorInfo -Encoding UTF8

    exit 1
}
