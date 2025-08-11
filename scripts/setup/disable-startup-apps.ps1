# ============================================================================
# スタートアップアプリ無効化スクリプト
# 指定名に一致するスタートアップ登録を無効化します
# ============================================================================

param(
    [Parameter(Mandatory)][string]$Name,
    [switch]$AllUsers,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
スタートアップアプリ無効化スクリプト

使用例:
  # OneDrive を現在ユーザーで無効化
  .\disable-startup-apps.ps1 -Name "OneDrive"

  # Teams を全ユーザー領域も含めて無効化（管理者で実行）
  .\disable-startup-apps.ps1 -Name "Teams" -AllUsers
"@ -ForegroundColor Cyan
    exit 0
}

# 共通ログ関数/ヘルパーの読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

$ScriptName = "DisableStartupApps"
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    Write-ScriptLog -Message $Message -Level $Level -ScriptName $ScriptName -LogFileName "disable-startup-apps.log"
}

function Test-IsAdministrator {
    try {
        $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Disable-StartupAppByName {
    <#
    .SYNOPSIS
      タスク マネージャーの「スタートアップ アプリ」で指定名に一致する項目を無効化します。
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$AllUsers
    )

    $paths = [System.Collections.Generic.List[string]]::new()
    $paths.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run')
    $paths.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32')
    $paths.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder')
    $runPaths = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')

    if ($AllUsers) {
        $paths.Add('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run')
        $paths.Add('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32')
        $runPaths += 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    }

    $changed = @()

    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $key = Get-Item $p
        foreach ($val in $key.GetValueNames()) {
            if ($val -like "*$Name*") {
                $data = [byte[]]($key.GetValue($val, $null, 'DoNotExpandEnvironmentNames'))
                if (-not $data) { continue }
                if ($PSCmdlet.ShouldProcess("$p\\$val", "Disable (set first byte 0x03)")) {
                    if ($data[0] -ne 0x03) {
                        $data[0] = 0x03
                        Set-ItemProperty -Path $p -Name $val -Value $data | Out-Null
                        $changed += [pscustomobject]@{ Path = $p; Name = $val; Action = "Disabled" }
                    }
                    else {
                        $changed += [pscustomobject]@{ Path = $p; Name = $val; Action = "AlreadyDisabled" }
                    }
                }
            }
        }
    }

    # StartupApproved に項目が無いが Run 側にあるケース → 無効レコードを新規作成
    foreach ($rp in $runPaths) {
        if (-not (Test-Path $rp)) { continue }
        $runKey = Get-Item $rp
        foreach ($val in $runKey.GetValueNames()) {
            if ($val -like "*$Name*") {
                $approvedTargets = @(
                    $rp.Replace('\\CurrentVersion\\Run', '\\CurrentVersion\\Explorer\\StartupApproved\\Run'),
                    $rp.Replace('\\CurrentVersion\\Run', '\\CurrentVersion\\Explorer\\StartupApproved\\Run32')
                )
                foreach ($ap in $approvedTargets) {
                    if (-not (Test-Path $ap)) { New-Item -Path $ap -Force | Out-Null }
                    if ($PSCmdlet.ShouldProcess("$ap\\$val", "Create disabled entry")) {
                        $disabled = [byte[]](0x03, 0, 0, 0, 0, 0, 0, 0)
                        New-ItemProperty -Path $ap -Name $val -PropertyType Binary -Value $disabled -Force | Out-Null
                        $changed += [pscustomobject]@{ Path = $ap; Name = $val; Action = "CreatedDisabledEntry" }
                    }
                }
            }
        }
    }

    return $changed
}

try {
    Write-Log "スタートアップ無効化処理を開始します: Name='$Name' AllUsers=$([bool]$AllUsers)"

    # ワークフローのルート解決（ログ出力のため）
    $null = Get-WorkflowRoot $PSScriptRoot

    if ($AllUsers -and -not (Test-IsAdministrator)) {
        Write-Log "AllUsers オプションには管理者権限が必要です" -Level "ERROR"
        exit 1
    }

    $changed = Disable-StartupAppByName -Name $Name -AllUsers:$AllUsers

    if (-not $changed -or $changed.Count -eq 0) {
        Write-Log "『$Name』に一致するスタートアップ項目は見つかりませんでした" -Level "WARN"
    }
    else {
        Write-Log "変更内容:"
        $changed | ForEach-Object { Write-Log "  - $($_.Action): $($_.Path)\\$($_.Name)" }
        Write-Log "完了。必要に応じてサインアウト/再起動してください。"
    }

    # 完了マーカー
    $markerName = "disable-startup-apps-$($Name.ToLower())"
    if ($AllUsers) { $markerName += "-allusers" }
    $completionMarker = Get-CompletionMarkerPath -TaskName $markerName
    @{
        completedAt  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        name         = $Name
        allUsers     = [bool]$AllUsers
        changedCount = ($changed | Measure-Object).Count
        changes      = $changed
    } | ConvertTo-Json -Depth 4 | Out-File -FilePath $completionMarker -Encoding UTF8

    # 他のセットアップスクリプトに合わせ、処理自体が成功したら 0 を返す
    exit 0
}
catch {
    Write-Log "スタートアップ無効化処理でエラー: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
