# =============================================================================
# パスコピー スクリプト（ネットワーク資格情報対応）
# - フォルダ/ファイルのコピーに対応
# - 宛先/送信元が UNC の場合、資格情報が指定されていれば一時的に PSDrive をマッピング
# - 共通ログ/ヘルパー使用、DryRun/Quiet/Force 対応
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath,

    # 宛先用資格情報（優先して使用）
    [System.Management.Automation.PSCredential]$DestinationCredential,

    # 送信元用資格情報（必要時に使用）
    [System.Management.Automation.PSCredential]$SourceCredential,

    # 宛先/送信元のどちらにも適用可能な共通資格情報（個別指定が無い場合に使用）
    [System.Management.Automation.PSCredential]$Credential,

    # JSON 等からプレーンテキストで受け取る場合の代替（Destination 優先）
    [string]$DestinationUsername,
    [string]$DestinationPassword,

    # JSON 等からプレーンテキストで受け取る場合の代替（Source 用）
    [string]$SourceUsername,
    [string]$SourcePassword,

    # 共通のテキスト資格情報（個別指定が無い場合のフォールバック）
    [string]$Username,
    [string]$Password,

    [switch]$Force,
    [switch]$Recurse,
    [switch]$DryRun,
    [switch]$Quiet,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
パスコピー スクリプト（ネットワーク資格情報対応）

使用例:
  # フォルダを再帰コピー（UNC 宛先、資格情報指定）
  .\copy_path_with_network.ps1 -SourcePath C:\Data\BitLocker -DestinationPath \\fileserver\secure\recovery -DestinationCredential (Get-Credential) -Recurse -Force

  # ファイルをコピー（送信元も UNC の例）
  .\copy_path_with_network.ps1 -SourcePath \\srv\share\report.txt -DestinationPath D:\Backup\report.txt -SourceCredential (Get-Credential)

  # JSON 等からテキストで資格情報を渡す例（推奨はしないが対応）
  .\copy_path_with_network.ps1 -SourcePath C:\Data -DestinationPath \\fileserver\share -DestinationUsername "domain\\user" -DestinationPassword "P@ssw0rd!" -Recurse

パラメータ:
  -SourcePath, -DestinationPath    コピー元/コピー先のパス。フォルダ/ファイルいずれも可。
  -DestinationCredential            宛先 UNC への接続に使用する資格情報。
  -SourceCredential                 送信元 UNC への接続に使用する資格情報。
  -Credential                       上記個別指定が無い場合に使用する共通資格情報。
  -DestinationUsername/Password     宛先用のテキスト資格情報（Credential よりも優先）。
  -SourceUsername/Password          送信元用のテキスト資格情報（共通よりも優先）。
  -Username/Password                個別指定がない場合に使う共通テキスト資格情報。
  -Recurse                          フォルダコピー時に再帰的にコピー。
  -Force                            既存ファイルを上書き。
  -DryRun                           実際のコピーは行わず内容をログ出力。
  -Quiet                            コンソール出力を抑制（ログには出力）。
  -Help                             このヘルプを表示。
"@
    exit 0
}

# 共通ログ関数/ヘルパーの読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

$ScriptName = "copy_path_with_network"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG","INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    Write-ScriptLog -Message $Message -Level $Level -ScriptName $ScriptName -LogFileName "copy_path_with_network.log" -NoConsoleOutput:$Quiet
}

Write-Log "コピー処理を開始します"

# ユーティリティ関数 ---------------------------------------------------------

function Resolve-Placeholders {
    param(
        [string]$Path
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $pcname = $env:COMPUTERNAME
    # 置換文字列に特殊解釈が入らないよう、MatchEvaluatorでリテラル置換
    $pattern = '(?i)\{pcname\}'
    $evaluator = {
        param($m)
        return $pcname
    }
    $resolved = [System.Text.RegularExpressions.Regex]::Replace($Path, $pattern, $evaluator)
    return $resolved
}

function New-CredentialFromText {
    param(
        [string]$User,
        [string]$Pass
    )
    if ([string]::IsNullOrWhiteSpace($User) -and [string]::IsNullOrWhiteSpace($Pass)) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Pass)) {
        throw "テキスト資格情報の指定が不完全です。Username/Password を両方指定してください。"
    }
    $secure = ConvertTo-SecureString -String $Pass -AsPlainText -Force
    return [System.Management.Automation.PSCredential]::new($User, $secure)
}

function Test-UncPath {
    param([string]$Path)
    return ($Path -match "^\\\\")
}

function Get-UncShareRoot {
    param([Parameter(Mandatory=$true)][string]$UncPath)
    # \\server\share\... -> \\server\share
    $m = [regex]::Match($UncPath, "^\\\\[^\\]+\\[^\\]+")
    if ($m.Success) { return $m.Value }
    throw "UNC 共有ルートを特定できません: $UncPath"
}

function Get-AvailableDriveLetter {
    # Z→Y→X ... の順で探す
    $letters = [char[]]([char]'Z'..[char]'A')
    $inUse = (Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name)
    foreach ($l in $letters) {
        if ($inUse -notcontains $l) { return "$(
$l):" }
    }
    throw "利用可能なドライブレターが見つかりません。"
}

function Mount-UncIfNeeded {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [System.Management.Automation.PSCredential]$Cred
    )
    $result = [ordered]@{
        Path              = $Path
        Mounted           = $false
        DriveName         = $null
        DriveRoot         = $null
        OriginalUncRoot   = $null
    }

    if (-not (Test-UncPath -Path $Path) -or -not $Cred) {
        return $result
    }

    $uncRoot = Get-UncShareRoot -UncPath $Path
    $driveLetter = Get-AvailableDriveLetter
    $driveName = $driveLetter.TrimEnd(':')

    Write-Log "UNC を一時マウントします: $uncRoot -> $driveLetter"

    New-PSDrive -Name $driveName -PSProvider FileSystem -Root $uncRoot -Credential $Cred -Scope Global -ErrorAction Stop | Out-Null

    $relative = ($Path.Substring($uncRoot.Length)).TrimStart('\\')
    $mappedPath = if ([string]::IsNullOrEmpty($relative)) { $driveLetter } else { Join-Path $driveLetter $relative }

    $result.Path = $mappedPath
    $result.Mounted = $true
    $result.DriveName = $driveName
    $result.DriveRoot = $driveLetter
    $result.OriginalUncRoot = $uncRoot
    return $result
}

function Dismount-IfMounted {
    param($MountInfo)
    if ($MountInfo -and $MountInfo.Mounted -and $MountInfo.DriveName) {
        try {
            Write-Log "一時マウントを解除します: $($MountInfo.DriveRoot) ($($MountInfo.OriginalUncRoot))"
            Remove-PSDrive -Name $MountInfo.DriveName -Force -ErrorAction Stop
        } catch {
            Write-Log "一時マウントの解除に失敗: $($_.Exception.Message)" -Level "WARN"
        }
    }
}

# 入力の正規化 ---------------------------------------------------------------

try {
    # プレースホルダ解決
    $SourcePath = Resolve-Placeholders -Path $SourcePath
    $DestinationPath = Resolve-Placeholders -Path $DestinationPath

    # 相対パスをワークフロー ルート基準に解決
    $workflowRoot = Get-WorkflowRoot
    if ($SourcePath -and -not (Test-UncPath -Path $SourcePath) -and -not ([System.IO.Path]::IsPathRooted($SourcePath))) {
        $SourcePath = Join-Path $workflowRoot $SourcePath
    }
    if ($DestinationPath -and -not (Test-UncPath -Path $DestinationPath) -and -not ([System.IO.Path]::IsPathRooted($DestinationPath))) {
        $DestinationPath = Join-Path $workflowRoot $DestinationPath
    }
    Write-Log "解決後のパス: Source='$SourcePath', Destination='$DestinationPath'" -Level "DEBUG"

    # 資格情報の解決（優先度: Destination/Source 個別 PSCredential > Destination/Source 個別テキスト > 共通 PSCredential > 共通テキスト）
    $commonTextCred = New-CredentialFromText -User $Username -Pass $Password

    $effectiveSourceCred = if ($SourceCredential) {
        $SourceCredential
    } else {
        $srcText = New-CredentialFromText -User $SourceUsername -Pass $SourcePassword
        if ($srcText) { $srcText }
        elseif ($Credential) { $Credential }
        else { $commonTextCred }
    }
    $sourceMount = Mount-UncIfNeeded -Path $SourcePath -Cred $effectiveSourceCred
    $effectiveSourcePath = $sourceMount.Path

    if (-not (Test-Path -LiteralPath $effectiveSourcePath)) {
        throw "コピー元が存在しません: $SourcePath"
    }

    $isDirectory = (Get-Item -LiteralPath $effectiveSourcePath).PSIsContainer

    # 宛先の準備
    $effectiveDestCred = if ($DestinationCredential) {
        $DestinationCredential
    } else {
        $dstText = New-CredentialFromText -User $DestinationUsername -Pass $DestinationPassword
        if ($dstText) { $dstText }
        elseif ($Credential) { $Credential }
        else { $commonTextCred }
    }
    $destMount = Mount-UncIfNeeded -Path $DestinationPath -Cred $effectiveDestCred
    $effectiveDestinationPath = $destMount.Path

    Write-Log "コピー元: $effectiveSourcePath"
    Write-Log "コピー先: $effectiveDestinationPath"

    if ($DryRun) {
        Write-Log "[DryRun] 実行内容を表示します"
    }

    # 宛先ディレクトリの作成（ファイル指定時は親を作成）
    $destParent = if ($isDirectory) { $effectiveDestinationPath } else { Split-Path -Path $effectiveDestinationPath -Parent }
    if (-not [string]::IsNullOrWhiteSpace($destParent) -and -not (Test-Path -LiteralPath $destParent)) {
        if ($DryRun) {
            Write-Log "[DryRun] 宛先ディレクトリを作成: $destParent"
        } else {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            Write-Log "宛先ディレクトリを作成: $destParent"
        }
    }

    # コピー実行
    if ($DryRun) {
        $desc = if ($isDirectory) { "[DryRun] ディレクトリをコピー (Recurse=$Recurse, Force=$Force)" } else { "[DryRun] ファイルをコピー (Force=$Force)" }
        Write-Log "$(
$desc): '$effectiveSourcePath' -> '$effectiveDestinationPath'"
    } else {
        if ($isDirectory) {
            $copyParams = @{ Path = $effectiveSourcePath; Destination = $effectiveDestinationPath; Force = $Force }
            if ($Recurse) { $copyParams["Recurse"] = $true }
            Copy-Item @copyParams
        } else {
            Copy-Item -Path $effectiveSourcePath -Destination $effectiveDestinationPath -Force:$Force
        }
        Write-Log "コピーが完了しました"
    }

    # 完了マーカー
    $statusPath = Get-CompletionMarkerPath -TaskName $ScriptName
    if (-not $DryRun) {
        Set-Content -Path $statusPath -Value ("Completed at " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")) -Encoding UTF8
    }

}
catch {
    Write-Log "コピー処理でエラー: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "スタック: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
finally {
    Dismount-IfMounted -MountInfo $sourceMount
    Dismount-IfMounted -MountInfo $destMount
}

Write-Log "コピー処理を終了します"
