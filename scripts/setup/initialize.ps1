# ============================================================================
# 初期化処理スクリプト
# Windows Kitting Workflow環境の初期化
# ============================================================================

param(
    [switch]$Force
)

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

    Write-ScriptLog -Message $Message -Level $Level -ScriptName "Initialize" -LogFileName "initialize.log"
}

try {
    Write-Log "Windows Kitting Workflow環境の初期化を開始します"    # 作業ディレクトリの設定
    # ワークフローのルートディレクトリを取得
    $workflowRoot = Get-WorkflowRoot
    Set-Location $workflowRoot

    Write-Log "作業ディレクトリ: $workflowRoot"
    Write-Log "コンピューター名: $env:COMPUTERNAME"
    Write-Log "ユーザー名: $env:USERNAME"
    Write-Log "Windows バージョン: $([Environment]::OSVersion.VersionString)"

    # 必要なディレクトリの作成
    $directories = @(
        "logs\scripts", "status",
        "temp"
    )
    foreach ($dir in $directories) {
        $fullPath = Join-Path $workflowRoot $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
            Write-Log "ディレクトリを作成しました: $dir"
        }
    }

    # システム情報の収集
    Write-Log "システム情報を収集中..."

    $systemInfo = @{
        ComputerName      = $env:COMPUTERNAME
        UserName          = $env:USERNAME
        OSVersion         = [Environment]::OSVersion.VersionString
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Architecture      = [Environment]::Is64BitOperatingSystem
        TimeZone          = (Get-TimeZone).Id
        Culture           = (Get-Culture).Name
        InitializedAt     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        WorkflowRoot      = $workflowRoot
    }    # システム情報をファイルに保存
    $systemInfoPath = Get-WorkflowPath -PathType "Status" -SubPath "system-info.json"
    $systemInfo | ConvertTo-Json | Out-File -FilePath $systemInfoPath -Encoding UTF8
    Write-Log "システム情報を保存しました: $systemInfoPath"

    # PowerShell実行ポリシーの確認
    $executionPolicy = Get-ExecutionPolicy
    Write-Log "現在のPowerShell実行ポリシー: $executionPolicy"

    if ($executionPolicy -eq "Restricted" -or $executionPolicy -eq "AllSigned") {
        Write-Log "PowerShell実行ポリシーを変更します" -Level "WARN"
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force        Write-Log "PowerShell実行ポリシーをRemoteSignedに変更しました"
    }

    # ネットワーク接続の確認
    Write-Log "ネットワーク接続を確認中..."

    $testUrls = @(
        "google.com",
        "microsoft.com",
        "slack.com"
    )
    $networkStatus = @{}
    foreach ($url in $testUrls) {
        try {
            $result = Test-NetConnection  $url -Port 443
            $networkStatus[$url] = $result
            if ($result) {
                Write-Log "ネットワーク接続OK: $url"
            }
            else {
                Write-Log "ネットワーク接続NG: $url" -Level "WARN"
            }
        }
        catch {
            Write-Log "ネットワーク接続テストエラー: $url - $($_.Exception.Message)" -Level "WARN"
            $networkStatus[$url] = $false
        }
    }    # インターネット接続状況をファイルに保存
    $networkStatusPath = Get-WorkflowPath -PathType "Status" -SubPath "network-status.json"
    $networkStatus | ConvertTo-Json | Out-File -FilePath $networkStatusPath -Encoding UTF8

    # 利用可能なディスク容量の確認
    Write-Log "ディスク容量を確認中..."

    $drives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    foreach ($drive in $drives) {
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
        $usedPercentage = [math]::Round((($drive.Size - $drive.FreeSpace) / $drive.Size) * 100, 1)

        Write-Log "ドライブ $($drive.DeviceID) - 空き容量: ${freeSpaceGB}GB / ${totalSpaceGB}GB (使用率: ${usedPercentage}%)"

        if ($freeSpaceGB -lt 10) {
            Write-Log "ドライブ $($drive.DeviceID) の空き容量が不足しています" -Level "WARN"
        }
    }

    # Windows Defender の状態確認
    Write-Log "Windows Defender の状態を確認中..."

    try {
        $defenderStatus = Get-MpPreference
        Write-Log "リアルタイム保護: $($defenderStatus.DisableRealtimeMonitoring -eq $false)"
        Write-Log "クラウド保護: $($defenderStatus.MAPSReporting -ne 'Disabled')"
    }
    catch {
        Write-Log "Windows Defender 状態確認エラー: $($_.Exception.Message)" -Level "WARN"
    }    # 完了マーカーの作成
    $completionMarker = Get-CompletionMarkerPath -TaskName "init"
    @{
        completedAt            = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        computerName           = $env:COMPUTERNAME
        userName               = $env:USERNAME
        osVersion              = [Environment]::OSVersion.VersionString
        powershellVersion      = $PSVersionTable.PSVersion.ToString()
        networkStatus          = $networkStatus
        initializationDuration = (Get-Date) - (Get-Date $systemInfo.InitializedAt)
    } | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

    Write-Log "初期化処理が正常に完了しました"
    exit 0

}
catch {
    Write-Log "初期化処理でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
