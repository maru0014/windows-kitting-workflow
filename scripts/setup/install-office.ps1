# Office インストール実行スクリプト
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

    Write-ScriptLog -Message $Message -Level $Level -ScriptName "InstallOffice" -LogFileName "install-office.log"
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

function Get-CanonicalLicenseType {
    param([string]$LicenseType)

    if ([string]::IsNullOrWhiteSpace($LicenseType)) { return $null }

    $normalized = $LicenseType.Trim().ToLower()

    switch ($normalized) {
        "o365" { return "365" }
        "m365" { return "365" }
        "office365" { return "365" }
        "365" { return "365" }
        "bundle2019" { return "bundle2019" }
        "office2019" { return "bundle2019" }
        "perpetual2019" { return "bundle2019" }
        "bundle2021" { return "bundle2021" }
        "office2021" { return "bundle2021" }
        "perpetual2021" { return "bundle2021" }
        default { return $normalized }
    }
}

function Resolve-OdtPaths {
    param(
        [string]$CanonicalLicenseType
    )

    $workflowRoot = Get-WorkflowRoot
    $officeDir = Join-Path $workflowRoot "config\office"

    $setupCandidates = @(
        (Join-Path $officeDir "setup.exe")
    )

    $templateCandidates = switch ($CanonicalLicenseType) {
        "365" {
            @(
                (Join-Path $officeDir "configuration-Office365-x64.xml")
            )
        }
        "bundle2021" {
            @(
                (Join-Path $officeDir "configuration-Office2021.xml")
            )
        }
        default {
            @()
        }
    }

    $setupPath = $null
    foreach ($s in $setupCandidates) { if (Test-Path $s) { $setupPath = $s; break } }
    $templatePath = $null
    foreach ($t in $templateCandidates) { if (Test-Path $t) { $templatePath = $t; break } }

    return [PSCustomObject]@{
        SetupPath    = $setupPath
        TemplatePath = $templatePath
        OfficeDir    = $officeDir
    }
}

function Protect-ProductKey {
    param([string]$ProductKey)

    if ([string]::IsNullOrWhiteSpace($ProductKey)) { return "" }
    $trimmed = $ProductKey.Trim()
    if ($trimmed.Length -le 5) { return "*****" }
    $last = $trimmed.Substring($trimmed.Length - 5)
    return ("*" * 5) + "-*****-*****-*****-" + $last
}

function New-ConfiguredXmlFromTemplate {
    param(
        [string]$TemplatePath,
        [string]$OutputPath,
        [string]$SerialNumber,
        [string]$MachineName,
        [string]$ProductKey
    )

    try {
        $xmlContent = Get-Content -Path $TemplatePath -Raw -Encoding UTF8

        $replacements = @{
            "{{SERIAL_NUMBER}}" = $SerialNumber
            "{{MACHINE_NAME}}"  = $MachineName
            "{{PRODUCT_KEY}}"   = $ProductKey
        }

        foreach ($k in $replacements.Keys) {
            $v = [string]$replacements[$k]
            $xmlContent = $xmlContent -replace [Regex]::Escape($k), [System.Text.RegularExpressions.Regex]::Escape($v).Replace('\\', '\\')
        }

        Set-Content -Path $OutputPath -Value $xmlContent -Encoding UTF8
        Write-Log "ODT構成XMLを生成しました: $OutputPath (テンプレート: $TemplatePath)"
        return $true
    }
    catch {
        Write-Log "ODT構成XML生成でエラー: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Invoke-OdtConfigure {
    param(
        [string]$SetupPath,
        [string]$ConfiguredXmlPath
    )

    try {
        Write-Log "ODTを実行します: `"$SetupPath`" /configure `"$ConfiguredXmlPath`""
        $process = Start-Process -FilePath $SetupPath -ArgumentList @("/configure", $ConfiguredXmlPath) -PassThru -WorkingDirectory (Split-Path $SetupPath -Parent)
        if (-not $process) {
            Write-Log "ODTプロセスの開始に失敗しました" -Level "ERROR"
            return $false
        }
        $process.WaitForExit()
        if ($process.ExitCode -eq 0) {
            Write-Log "ODTの実行が正常に完了しました (ExitCode=$($process.ExitCode))"
            return $true
        }
        else {
            Write-Log "ODTの実行でエラーが発生しました (ExitCode=$($process.ExitCode))" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "ODT実行中に例外: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function New-CompletionFlag {
	param(
		[string]$SerialNumber,
		[string]$MachineName,
		[string]$LicenseType,
		[string]$InstallerPath,
		[string]$MaskedKey
	)
	# 完了マーカーは MainWorkflow 側で作成されます（ここでは詳細ログのみ）
	Write-Log "Office インストール完了: PC=$MachineName License=$LicenseType Installer=$InstallerPath Key=$MaskedKey"
}

# メイン処理
Write-Log "=== Officeインストール処理開始 ==="

# 設定ファイルのパス確認
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
if (-not $machineList) { exit 1 }

# 該当する機器情報を検索
$targetMachine = Find-MachineBySerial -MachineList $machineList -SerialNumber $serialNumber
if (-not $targetMachine) {
    Write-Log "シリアル番号 '$serialNumber' に対応する機器情報が見つかりません" -Level "ERROR"
    exit 1
}

$machineName = $targetMachine."Machine Name"
$licenseTypeRaw = $targetMachine."Office License Type"
$productKey = $targetMachine."Office Product Key"

Write-Log "対象PC名: $machineName | ライセンスタイプ: $licenseTypeRaw"

$canonical = Get-CanonicalLicenseType -LicenseType $licenseTypeRaw
if (-not $canonical) {
    Write-Log "ライセンスタイプが未指定、または不明です: '$licenseTypeRaw'" -Level "ERROR"
    exit 1
}

$paths = Resolve-OdtPaths -CanonicalLicenseType $canonical
if (-not $paths.SetupPath) {
    Write-Log "ODTの setup.exe が見つかりません: $($paths.OfficeDir)" -Level "ERROR"
    exit 1
}
if (-not $paths.TemplatePath) {
    Write-Log "ライセンスタイプ '$canonical' に対応する構成テンプレートXMLが見つかりません" -Level "ERROR"
    exit 1
}
Write-Log "ODT setup: $($paths.SetupPath)"
Write-Log "テンプレート: $($paths.TemplatePath)"

# 365 はそのまま既定XMLを使用、Bundle2021 はテンポラリにコピーして PRODUCT_KEY を置換
$configuredXmlPath = $null
if ($canonical -eq "365") {
    $configuredXmlPath = $paths.TemplatePath
    Write-Log "365ライセンス: 既定の構成XMLを使用します: $configuredXmlPath"
}
elseif ($canonical -eq "bundle2021") {
    if ([string]::IsNullOrWhiteSpace($productKey)) {
        Write-Log "Bundle2021 ライセンスでは 'Office Product Key' が必須です" -Level "ERROR"
        exit 1
    }

    $tempXml = Join-Path $env:TEMP ("odt-config-" + $serialNumber + "-" + $canonical + ".xml")
    $xmlOk = New-ConfiguredXmlFromTemplate -TemplatePath $paths.TemplatePath -OutputPath $tempXml -SerialNumber $serialNumber -MachineName $machineName -ProductKey $productKey
    if (-not $xmlOk) { exit 1 }
    $configuredXmlPath = $tempXml
    Write-Log "Bundle2021ライセンス: テンポラリ構成XMLを生成しました: $configuredXmlPath"
}
else {
    Write-Log "未対応のライセンスタイプです: '$canonical'" -Level "ERROR"
    exit 1
}

$success = Invoke-OdtConfigure -SetupPath $paths.SetupPath -ConfiguredXmlPath $configuredXmlPath
if ($success) {
    $maskedKey = Protect-ProductKey -ProductKey $productKey
    New-CompletionFlag -SerialNumber $serialNumber -MachineName $machineName -LicenseType $licenseTypeRaw -InstallerPath $paths.SetupPath -MaskedKey $maskedKey
    Write-Log "=== Officeインストール処理完了 ==="
    exit 0
}
else {
    Write-Log "Officeインストール処理に失敗しました" -Level "ERROR"
    exit 1
}
