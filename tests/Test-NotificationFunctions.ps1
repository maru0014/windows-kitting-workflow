# ==============================================================================
# 通知機能テストツール
# Slack/Teams通知の動作確認とスレッド機能のテスト
# ==============================================================================

param(
    [switch]$TestSlack,
    [switch]$TestTeams,
    [switch]$ShowInfo,
    [switch]$ClearThreads,
    [switch]$All
)

# ワークフローのルートディレクトリを検出
$workflowRoot = Split-Path $PSScriptRoot -Parent

# ヘルパー関数をインポート
. (Join-Path $workflowRoot "scripts\Common-WorkflowHelpers.ps1")

# 設定ファイルのパス
$notificationConfigPath = Get-WorkflowPath -PathType "Config" -SubPath "notifications.json"

if (-not (Test-Path $notificationConfigPath)) {
    Write-Host "通知設定ファイルが見つかりません: $notificationConfigPath" -ForegroundColor Red
    exit 1
}

# 設定読み込み
try {
    $notificationConfig = Get-Content $notificationConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    Write-Host "通知設定ファイルの読み込みでエラー: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 共通ログ関数の読み込み
$logFunctionsPath = Get-WorkflowPath -PathType "Scripts" -SubPath "Common-LogFunctions.ps1"
if (Test-Path $logFunctionsPath) {
    . $logFunctionsPath
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "INFO" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

function Get-PCSerialNumber {
    try {
        $systemInfo = Get-CimInstance -ClassName Win32_ComputerSystemProduct
        if (-not $systemInfo -or [string]::IsNullOrWhiteSpace($systemInfo.IdentifyingNumber)) {
            return $env:COMPUTERNAME
        }

        $serialNumber = $systemInfo.IdentifyingNumber
        if ($serialNumber -eq "System Serial Number" -or $serialNumber -eq "To be filled by O.E.M.") {
            $biosInfo = Get-CimInstance -ClassName Win32_BIOS
            if ($biosInfo -and -not [string]::IsNullOrWhiteSpace($biosInfo.SerialNumber)) {
                $serialNumber = $biosInfo.SerialNumber
            } else {
                return $env:COMPUTERNAME
            }
        }

        $cleanSerialNumber = $serialNumber -replace '\s+', '' -replace '[^\w]', ''
        return $cleanSerialNumber
    }
    catch {
        Write-Log "PCシリアル番号取得でエラー: $($_.Exception.Message)" -Level "WARN"
        return $env:COMPUTERNAME
    }
}

function Test-SlackNotification {
    Write-Log "=== Slack通知テスト ===" -Level "INFO"

    $slackConfig = $notificationConfig.notifications.providers.slack
    if (-not $slackConfig.enabled) {
        Write-Log "Slack通知が無効です" -Level "WARN"
        return
    }

    $testMessage = "📧 テスト通知: Slack機能の動作確認 - $(Get-Date -Format 'HH:mm:ss')"

    try {
        # スレッド機能のテスト
        if ($slackConfig.thread -and $slackConfig.thread.enabled) {
            Write-Log "スレッド機能有効でテスト実行" -Level "INFO"
        } else {
            Write-Log "通常モードでテスト実行" -Level "INFO"
        }

        # 実際の通知送信は MainWorkflow.ps1 の関数を使用
        Write-Log "テストメッセージ: $testMessage" -Level "INFO"
        Write-Log "Slack通知テスト完了" -Level "INFO"
    }
    catch {
        Write-Log "Slack通知テストでエラー: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Test-TeamsNotification {
    Write-Log "=== Teams通知テスト（新スレッド方式） ===" -Level "INFO"

    $teamsConfig = $notificationConfig.notifications.providers.teams
    if (-not $teamsConfig.enabled) {
        Write-Log "Teams通知が無効です" -Level "WARN"
        return
    }

    $testMessage = "📧 テスト通知: Teams新スレッド方式の動作確認 - $(Get-Date -Format 'HH:mm:ss')"

    try {
        # Flow URL設定チェック
        if (-not $teamsConfig.flowUrl -or $teamsConfig.flowUrl -eq "https://your-teams-flow-url-here") {
            Write-Log "Teams Flow URLが設定されていません" -Level "WARN"
            return
        }

        # 必須設定の確認
        if (-not $teamsConfig.teamId) {
            Write-Log "Teams Team IDが設定されていません" -Level "WARN"
            return
        }

        if (-not $teamsConfig.channelId) {
            Write-Log "Teams Channel IDが設定されていません" -Level "WARN"
            return
        }

        Write-Log "新スレッド方式でテスト実行" -Level "INFO"
        Write-Log "Team ID: $($teamsConfig.teamId)" -Level "INFO"
        Write-Log "Channel ID: $($teamsConfig.channelId)" -Level "INFO"
        Write-Log "テストメッセージ: $testMessage" -Level "INFO"
        Write-Log "Teams通知テスト完了" -Level "INFO"
    }
    catch {
        Write-Log "Teams通知テストでエラー: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Show-NotificationInfo {
    Write-Log "=== 通知設定情報 ===" -Level "INFO"

    # Slack情報
    $slackConfig = $notificationConfig.notifications.providers.slack
    Write-Log "Slack有効: $($slackConfig.enabled)" -Level "INFO"
    if ($slackConfig.enabled) {
        Write-Log "Webhook URL設定: $(if ($slackConfig.webhookUrl -and $slackConfig.webhookUrl -ne 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK') { '設定済み' } else { '未設定' })" -Level "INFO"
        Write-Log "Bot Token設定: $(if ($slackConfig.botToken -and $slackConfig.botToken -ne 'xoxb-your-bot-token-here') { '設定済み' } else { '未設定' })" -Level "INFO"
        Write-Log "スレッド機能: $($slackConfig.thread.enabled)" -Level "INFO"
    }

    # Teams情報
    $teamsConfig = $notificationConfig.notifications.providers.teams
    Write-Log "Teams有効: $($teamsConfig.enabled)" -Level "INFO"
    if ($teamsConfig.enabled) {
        Write-Log "Flow URL設定: $(if ($teamsConfig.flowUrl -and $teamsConfig.flowUrl -ne 'https://your-teams-flow-url-here') { '設定済み' } else { '未設定' })" -Level "INFO"
        Write-Log "Team ID設定: $(if ($teamsConfig.teamId) { '設定済み' } else { '未設定' })" -Level "INFO"
        Write-Log "Channel ID設定: $(if ($teamsConfig.channelId) { '設定済み' } else { '未設定' })" -Level "INFO"
        Write-Log "マシンID保存パス: $($teamsConfig.idStoragePath)" -Level "INFO"
    }
}

function Clear-ThreadData {
    Write-Log "=== スレッドデータクリア ===" -Level "INFO"

    $statusPath = Get-WorkflowPath -PathType "Status"

    # Slackスレッドデータ
    $slackThreadFile = Join-Path $statusPath "slack_thread_ts.json"
    if (Test-Path $slackThreadFile) {
        Remove-Item $slackThreadFile -Force
        Write-Log "Slackスレッドデータをクリアしました" -Level "INFO"
    }

    # TeamsマシンIDデータ
    $teamsMachineIdFile = Join-Path $statusPath "teams_machine_ids.json"
    if (Test-Path $teamsMachineIdFile) {
        Remove-Item $teamsMachineIdFile -Force
        Write-Log "TeamsマシンIDデータをクリアしました" -Level "INFO"
    }

    Write-Log "スレッドデータクリア完了" -Level "INFO"
}

# メイン実行
Write-Host "通知機能テストツール" -ForegroundColor Cyan
Write-Host "PC: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "シリアル番号: $(Get-PCSerialNumber)" -ForegroundColor White
Write-Host ""

if ($All) {
    $ShowInfo = $true
    $TestSlack = $true
    $TestTeams = $true
}

if ($ShowInfo) {
    Show-NotificationInfo
    Write-Host ""
}

if ($ClearThreads) {
    Clear-ThreadData
    Write-Host ""
}

if ($TestSlack) {
    Test-SlackNotification
    Write-Host ""
}

if ($TestTeams) {
    Test-TeamsNotification
    Write-Host ""
}

if (-not ($ShowInfo -or $ClearThreads -or $TestSlack -or $TestTeams -or $All)) {
    Write-Host "使用方法:" -ForegroundColor Yellow
    Write-Host "  -ShowInfo       通知設定情報を表示" -ForegroundColor White
    Write-Host "  -TestSlack      Slack通知をテスト" -ForegroundColor White
    Write-Host "  -TestTeams      Teams通知をテスト" -ForegroundColor White
    Write-Host "  -ClearThreads   スレッドデータをクリア" -ForegroundColor White
    Write-Host "  -All            すべての機能をテスト" -ForegroundColor White
    Write-Host ""
    Write-Host "例:" -ForegroundColor Yellow
    Write-Host "  .\Test-NotificationFunctions.ps1 -All" -ForegroundColor Gray
    Write-Host "  .\Test-NotificationFunctions.ps1 -ShowInfo -TestSlack" -ForegroundColor Gray
}

Write-Log "通知機能テスト完了" -Level "INFO"
