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
# 通知関数の読み込み
.(Join-Path (Split-Path $PSScriptRoot -Parent) "Common-NotificationFunctions.ps1")

# ログ関数
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    Write-ScriptLog -Message $Message -Level $Level -ScriptName "Initialize" -LogFileName "initialize.log"
}

# ワークフローステップ一覧メッセージを生成（config/workflow.json から）
function Get-WorkflowStepsMessageFromConfig {
    try {
        $workflowRoot = Get-WorkflowRoot
        $configPath = Join-Path $workflowRoot "config\\workflow.json"
        if (-not (Test-Path $configPath)) {
            return "• ワークフロー設定が見つかりません"
        }

        $json = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $json.workflow -or -not $json.workflow.steps) {
            return "• ワークフローステップが定義されていません"
        }

        $stepsList = @()
        foreach ($step in $json.workflow.steps) {
            $stepName = $step.name
            $additional = @()
            if ($step.rebootRequired -eq $true) { $additional += "再起動あり" }
            if ($step.id -eq "init") { $additional += "初回のみ" }
            if ($step.onError -eq "continue") { $additional += "エラー時継続" }
            if ($additional.Count -gt 0) { $stepName += "（" + ($additional -join "、") + "）" }
            $stepsList += "- $stepName"
        }
        return $stepsList -join "`n"
    }
    catch {
        return "- ワークフローステップの取得に失敗しました"
    }
}

# PCシリアル番号を取得する関数
function Get-PCSerialNumber {
    try {
        $serialNumber = (Get-WmiObject -Class Win32_SystemEnclosure).SerialNumber
        if ([string]::IsNullOrWhiteSpace($serialNumber)) {
            $serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
        }
        if ([string]::IsNullOrWhiteSpace($serialNumber)) {
            Write-Log "PCシリアル番号を取得できませんでした" -Level "WARN"
            return $null
        }
        return $serialNumber.Trim()
    }
    catch {
        Write-Log "PCシリアル番号取得でエラー: $($_.Exception.Message)" -Level "WARN"
        return $null
    }
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

    # BIOSパスワード解除確認＋ユーザー入力（初回のみ）
    try {
        if (-not $Force) {
            $biosConfirmMarker = Get-WorkflowPath -PathType "Status" -SubPath "bios-password-confirmed.completed"

            if (-not (Test-Path $biosConfirmMarker)) {
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -AssemblyName System.Drawing

                # 既定値の準備
                $serial = Get-PCSerialNumber

                # machine_list.csv からPC名既定値を取得
                $machineListPath = Join-Path $workflowRoot "config\machine_list.csv"
                $defaultPCName = $env:COMPUTERNAME
                if (Test-Path $machineListPath) {
                    try {
                        $csv = Import-Csv -Path $machineListPath
                        $matched = $csv | Where-Object { $_.'Serial Number' -eq $serial }
                        if ($matched) {
                            $defaultPCName = $matched.'Machine Name'
                        }
                    }
                    catch {
                        Write-Log "machine_list.csv の読み込みに失敗: $($_.Exception.Message)" -Level "WARN"
                    }
                }

                # local_user.json からユーザー既定値を取得
                $localUserPath = Join-Path $workflowRoot "config\local_user.json"
                $defaultUser = "User001"
                $defaultPass = "User1234"
                $defaultGroups = "Administrators"
                if (Test-Path $localUserPath) {
                    try {
                        $lu = Get-Content -Path $localUserPath -Encoding UTF8 -Raw | ConvertFrom-Json
                        if ($lu.UserName) { $defaultUser = [string]$lu.UserName }
                        if ($lu.Password) { $defaultPass = [string]$lu.Password }
                        if ($lu.Groups -and $lu.Groups.Count -gt 0) { $defaultGroups = ($lu.Groups -join ',') }
                    }
                    catch {
                        Write-Log "local_user.json の読み込みに失敗: $($_.Exception.Message)" -Level "WARN"
                    }
                }

                # 入力フォーム作成
                $form = New-Object System.Windows.Forms.Form
                $form.Text = "Windows Kitting Workflow - 初回実行確認"
                $form.Size = New-Object System.Drawing.Size(560, 300)
                $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

                $labelMsg = New-Object System.Windows.Forms.Label
                $labelMsg.AutoSize = $true
                $labelMsg.Text = "このPCのBIOSパスワードは解除済みか確認し、各項目を確認/編集してください。"
                $labelMsg.Location = New-Object System.Drawing.Point(12, 12)
                $form.Controls.Add($labelMsg)

                $y = 50
                function Add-Row([string]$label, [string]$value, [bool]$isPassword = $false) {
                    $lbl = New-Object System.Windows.Forms.Label
                    $lbl.Text = $label
                    $lbl.Size = New-Object System.Drawing.Size(140, 23)
                    $lbl.Location = New-Object System.Drawing.Point -ArgumentList @([int]12, [int]$script:y)
                    $tb = New-Object System.Windows.Forms.TextBox
                    $tb.Text = $value
                    $tb.Size = New-Object System.Drawing.Size(360, 23)
                    $tb.Location = New-Object System.Drawing.Point -ArgumentList @([int]160, [int]$script:y)
                    if ($isPassword) { $tb.UseSystemPasswordChar = $true }
                    $form.Controls.Add($lbl)
                    $form.Controls.Add($tb)
                    $script:y = $y + 32
                    return $tb
                }

                $txtPCName = Add-Row "PC名" $defaultPCName $false
                $txtUser = Add-Row "ユーザー" $defaultUser $false
                $txtPass = Add-Row "パスワード" $defaultPass $false
                $txtGroups = Add-Row "所属グループ(カンマ区切り)" $defaultGroups $false

                $btnOk = New-Object System.Windows.Forms.Button
                $btnOk.Text = "確認"
                $btnOk.Size = New-Object System.Drawing.Size(100, 30)
                $btnOk.Location = New-Object System.Drawing.Point -ArgumentList @([int]320, [int]($script:y + 10))
                $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $form.AcceptButton = $btnOk

                $btnCancel = New-Object System.Windows.Forms.Button
                $btnCancel.Text = "キャンセル"
                $btnCancel.Size = New-Object System.Drawing.Size(100, 30)
                $btnCancel.Location = New-Object System.Drawing.Point -ArgumentList @([int]430, [int]($script:y + 10))
                $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
                $form.CancelButton = $btnCancel

                $form.Controls.Add($btnOk)
                $form.Controls.Add($btnCancel)

                $dialogResult = $form.ShowDialog()
                if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
                    Write-Log "ユーザーがセットアップのキャンセルを選択しました。プログラムを終了します。"
                    exit 1
                }

                # 入力値取得
                $newPCName = $txtPCName.Text.Trim()
                $newUser = $txtUser.Text.Trim()
                $newPass = $txtPass.Text
                $newGroups = $txtGroups.Text.Trim()

                # machine_list.csv へ書き戻し（シリアル一致行があれば更新、なければ追記）
                try {
                    $csvRows = @()
                    $header = @("Serial Number", "Machine Name", "Office License Type", "Office Product Key")
                    if (Test-Path $machineListPath) {
                        $csvRows = Import-Csv -Path $machineListPath
                    }
                    $existing = $csvRows | Where-Object { $_.'Serial Number' -eq $serial }
                    if ($existing) {
                        foreach ($row in $csvRows) {
                            if ($row.'Serial Number' -eq $serial) {
                                $row.'Machine Name' = $newPCName
                            }
                        }
                    }
                    else {
                        $obj = [pscustomobject]@{
                            'Serial Number'       = $serial
                            'Machine Name'        = $newPCName
                            'Office License Type' = ''
                            'Office Product Key'  = ''
                        }
                        $csvRows += $obj
                    }
                    # 明示的にUTF8で保存（ヘッダー順を維持）
                    $out = $csvRows | Select-Object $header
                    $out | Export-Csv -Path $machineListPath -NoTypeInformation -Encoding UTF8
                    Write-Log "machine_list.csv を更新しました: $machineListPath"
                }
                catch {
                    Write-Log "machine_list.csv の更新に失敗: $($_.Exception.Message)" -Level "WARN"
                }

                # local_user.json へ書き戻し
                try {
                    $groupsArray = @()
                    if (-not [string]::IsNullOrWhiteSpace($newGroups)) {
                        $groupsArray = $newGroups.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
                    }
                    if ($groupsArray.Count -eq 0) { $groupsArray = @("Administrators") }

                    $userObj = [pscustomobject]@{
                        UserName = $newUser
                        Password = $newPass
                        Groups   = $groupsArray
                    }
                    $userObj | ConvertTo-Json | Out-File -FilePath $localUserPath -Encoding UTF8
                    Write-Log "local_user.json を更新しました: $localUserPath"
                }
                catch {
                    Write-Log "local_user.json の更新に失敗: $($_.Exception.Message)" -Level "WARN"
                }

                # 確認マーカーの作成
                $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $statusContent = @"
BIOS Password Confirmation Completed
=====================================
Confirmed Date: $timestamp
Computer Name: $newPCName
User: $newUser
Status: Confirmed by user dialog
"@
                [System.IO.File]::WriteAllText($biosConfirmMarker, $statusContent, [System.Text.Encoding]::UTF8)
                Write-Log "BIOSパスワード確認完了ステータスファイルを作成しました: $biosConfirmMarker"
            }
            else {
                Write-Log "BIOSパスワード解除は既に確認済みです。ダイアログをスキップします。"
            }
        }
        else {
            Write-Log "-Force 指定のため、BIOSパスワード解除確認をスキップします。" -Level "WARN"
        }
    }
    catch {
        Write-Log "BIOSパスワード解除確認でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }

    # 初回起動時のみ開始通知を送信（CSVの最新PC名を反映）
    try {
        $statusDir = Get-WorkflowPath -PathType "Status"
        $workflowStartStatusFile = Join-Path $statusDir "workflow-started.completed"
        $workflowInitialStartFile = Join-Path $statusDir "workflow-initial-start.json"

        $isFirstRun = -not (Test-Path $workflowStartStatusFile)
        if ($isFirstRun) {
            # 通知設定読み込み
            $workflowRoot = Get-WorkflowRoot
            $notifPath = Join-Path $workflowRoot "config\\notifications.json"
            $null = Import-NotificationConfig -ConfigPath $notifPath

            # メッセージ生成
            $workflowSteps = Get-WorkflowStepsMessageFromConfig

            # 開始通知送信（machineName は通知関数側で CSV 優先に解決）
            $null = Send-Notification -EventType "onWorkflowStart" -Variables @{ workflowSteps = $workflowSteps }

            # ステータスファイル作成
            if (-not (Test-Path $statusDir)) { New-Item -ItemType Directory -Path $statusDir -Force | Out-Null }
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $effectivePCName = if ($newPCName -and -not [string]::IsNullOrWhiteSpace($newPCName)) { $newPCName } else { $env:COMPUTERNAME }
            $statusContent = @"
Workflow Start Notification Sent
=================================
First Run Date: $timestamp
Computer Name: $effectivePCName
User: $env:USERNAME
Status: Initial workflow start notification sent
"@
            [System.IO.File]::WriteAllText($workflowStartStatusFile, $statusContent, [System.Text.Encoding]::UTF8)

            # 初回実行情報を記録（未存在時のみ）
            if (-not (Test-Path $workflowInitialStartFile)) {
                $initialStartInfo = @{
                    initialStartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
                    computerName     = $effectivePCName
                    userName         = $env:USERNAME
                    timeZone         = [System.TimeZoneInfo]::Local.Id
                }
                $initialStartInfo | ConvertTo-Json | Out-File -FilePath $workflowInitialStartFile -Encoding UTF8
                Write-Log "初回実行情報ファイルを作成しました: $workflowInitialStartFile"
            }
            else {
                Write-Log "初回実行情報ファイルは既に存在するため作成をスキップします: $workflowInitialStartFile"
            }

            Write-Log "初回開始通知を送信し、ステータスを作成しました"
            Start-Sleep -Seconds 5
        }
        else {
            Write-Log "初回開始通知は既に送信済みのためスキップします"
        }
    }
    catch {
        Write-Log "開始通知処理でエラー: $($_.Exception.Message)" -Level "WARN"
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
    }    # 完了マーカーは MainWorkflow 側で作成されます
    Write-Log "初期化処理の完了（マーカーはMainWorkflowが作成）"

    Write-Log "初期化処理が正常に完了しました"
    exit 0

}
catch {
    Write-Log "初期化処理でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
