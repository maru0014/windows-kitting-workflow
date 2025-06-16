# PC名変更スクリプト
param(
    [string]$ConfigPath = "config\machine_list.csv",
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

    Write-ScriptLog -Message $Message -Level $Level -ScriptName "RenameComputer" -LogFileName "rename-computer.log"
}

function Get-SerialNumber {
    try {
        $serialNumber = (Get-WmiObject -Class Win32_SystemEnclosure).SerialNumber
        if ([string]::IsNullOrWhiteSpace($serialNumber)) {
            $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
        }
        return $serialNumber.Trim()
    }
    catch {
        Write-Log "シリアル番号の取得に失敗しました: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Import-MachineList {
    param([string]$CsvPath)

    try {
        if (-not (Test-Path $CsvPath)) {
            Write-Log "機器リストファイルが見つかりません: $CsvPath" -Level "ERROR"
            return $null
        }

        $machines = Import-Csv $CsvPath
        Write-Log "機器リスト読み込み完了: $($machines.Count)台"
        return $machines
    }
    catch {
        Write-Log "機器リストの読み込みに失敗しました: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Find-MachineBySerial {
    param(
        [array]$MachineList,
        [string]$SerialNumber
    )

    foreach ($machine in $MachineList) {
        if ($machine."Serial Number" -eq $SerialNumber) {
            return $machine
        }
    }
    return $null
}

function Rename-ComputerName {
    param(
        [string]$NewName,
        [switch]$Force
    )

    try {
        $currentName = $env:COMPUTERNAME

        if ($currentName -eq $NewName) {
            Write-Log "PC名は既に '$NewName' に設定されています"
            return $true
        }

        Write-Log "PC名を '$currentName' から '$NewName' に変更します"

        if ($Force -or (Read-Host "PC名を変更しますか？ (y/N)") -eq 'y') {
            Rename-Computer -NewName $NewName -Force -ErrorAction Stop
            Write-Log "PC名の変更が完了しました。再起動が必要です。"
            return $true
        }
        else {
            Write-Log "PC名の変更がキャンセルされました" -Level "WARN"
            return $false
        }
    }
    catch {
        Write-Log "PC名の変更に失敗しました: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function New-CompletionFlag {
    # ステータスディレクトリを取得
    $statusDir = Get-WorkflowPath -PathType "Status"
    if (-not (Test-Path $statusDir)) {
        New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
    }

    $flagFile = Join-Path $statusDir "rename-computer.completed"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $content = @"
PC名変更完了
実行時刻: $timestamp
変更前: $env:COMPUTERNAME
変更後: $($targetMachine."Machine Name")
シリアル番号: $serialNumber
"@
    Set-Content -Path $flagFile -Value $content -Encoding UTF8
    Write-Log "完了フラグファイルを作成しました: $flagFile"
}

# メイン処理
Write-Log "=== PC名変更処理開始 ==="

# 設定ファイルのパス確認
# ワークフローのルートディレクトリを取得
$workflowRoot = Get-WorkflowRoot

$fullConfigPath = Join-Path $workflowRoot $ConfigPath
if (-not (Test-Path $fullConfigPath)) {
    Write-Log "設定ファイルが見つかりません: $fullConfigPath" -Level "ERROR"
    exit 1
}

# シリアル番号取得
$serialNumber = Get-SerialNumber
if (-not $serialNumber) {
    Write-Log "シリアル番号が取得できませんでした" -Level "ERROR"
    exit 1
}
Write-Log "現在のシリアル番号: $serialNumber"

# 機器リスト読み込み
$machineList = Import-MachineList -CsvPath $fullConfigPath
if (-not $machineList) {
    exit 1
}

# 該当する機器情報を検索
$targetMachine = Find-MachineBySerial -MachineList $machineList -SerialNumber $serialNumber
if (-not $targetMachine) {
    Write-Log "シリアル番号 '$serialNumber' に対応する機器情報が見つかりません" -Level "ERROR"
    exit 1
}

$targetName = $targetMachine."Machine Name"
Write-Log "対象PC名: $targetName"

# PC名変更実行
$success = Rename-ComputerName -NewName $targetName -Force:$Force
if ($success) {
    New-CompletionFlag    Write-Log "=== PC名変更処理完了 ==="
    Write-Log "システムを再起動してください"
    exit 0
}
else {
    Write-Log "PC名変更処理に失敗しました" -Level "ERROR"
    exit 1
}
