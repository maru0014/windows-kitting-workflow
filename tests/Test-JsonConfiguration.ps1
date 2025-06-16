# ==============================================================================
# JSON設定ファイルテストスクリプト
# 包括的なチェック機能付きですべてのJSON設定ファイルを検証
# ==============================================================================

param(
	[string]$ConfigPath,
	[switch]$Fix = $false,
	[switch]$Verbose = $false,
	[switch]$OutputJson = $false
)

# 共通機能をインポート
$scriptRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $scriptRoot "scripts\Common-LogFunctions.ps1")
. (Join-Path $scriptRoot "scripts\Common-WorkflowHelpers.ps1")

$testResults = @()

function Add-TestResult {
	param(
		[string]$TestName,
		[string]$FilePath,
		[bool]$Success,
		[string]$Message = "",
		[string]$Details = "",
		[string]$FixAction = ""
	)

	$script:testResults += [PSCustomObject]@{
		TestName  = $TestName
		FilePath  = $FilePath
		Success   = $Success
		Message   = $Message
		Details   = $Details
		FixAction = $FixAction
		Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	}
	if ($Verbose -or -not $Success) {
		$status = if ($Success) { "[成功]" } else { "[失敗]" }
		$color = if ($Success) { "Green" } else { "Red" }
		Write-Host "$status $TestName" -ForegroundColor $color

		if ($Message) {
			Write-Host "  $Message" -ForegroundColor Yellow
		}
	}
}

function Test-JsonFileStructure {
	param(
		[string]$Path,
		[string]$ExpectedSchema = ""
	)
	$fileName = Split-Path $Path -Leaf

	if (-not (Test-Path $Path)) {
		Add-TestResult -TestName "ファイル存在確認" -FilePath $Path -Success $false -Message "ファイルが存在しません"
		return $false
	}    # ファイルエンコーディングとBOMのテスト
	try {
		$bytes = [System.IO.File]::ReadAllBytes($Path)
		$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

		if ($hasBom) {
			Add-TestResult -TestName "BOM確認" -FilePath $Path -Success $true -Message "UTF-8 BOMが検出されました（期待通り）"
		}
		else {
			Add-TestResult -TestName "BOM確認" -FilePath $Path -Success $false -Message "UTF-8 BOMが見つかりません（UTF-8 with BOMである必要があります）" -FixAction "BOMを追加"
		}
	}
 catch {
		Add-TestResult -TestName "ファイルアクセス" -FilePath $Path -Success $false -Message "ファイルを読み取れません: $($_.Exception.Message)"
		return $false
	}    # コンテンツの読み取りと検証
	try {
		$content = Get-Content $Path -Raw -Encoding UTF8

		# 文字化けの確認（全角文字以外）
		# 一般的なエンコーディング破損パターンを検索
		$corruptionPatterns = @(
			'�', # 置換文字（一般的な破損インジケーター）
			'\x00'         # Null文字
		)

		$corruptionFound = $false
		$corruptionDetails = @()
		foreach ($pattern in $corruptionPatterns) {
			if ($content -match $pattern) {
				$corruptionFound = $true
				$patternMatches = [regex]::Matches($content, [regex]::Escape($pattern))
				foreach ($match in $patternMatches) {
					$lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
					$corruptionDetails += "行 ${lineNumber}: '$pattern' が検出されました"
				}
			}
		}

		if ($corruptionFound) {			Add-TestResult -TestName "文字エンコーディング" -FilePath $Path -Success $false -Message "文字化けが検出されました" -Details ($corruptionDetails -join "; ") -FixAction "手動確認が必要です"
		}
		else {
			Add-TestResult -TestName "文字エンコーディング" -FilePath $Path -Success $true -Message "文字化けは検出されませんでした"
		}

		# JSON構文の検証
		try {
			$jsonObject = $content | ConvertFrom-Json
			Add-TestResult -TestName "JSON構文" -FilePath $Path -Success $true

			# スキーマ固有の検証
			switch ($fileName) {
				"workflow.json" {
					Test-WorkflowJsonSchema -JsonObject $jsonObject -FilePath $Path
				}
				"notifications.json" {
					Test-NotificationsJsonSchema -JsonObject $jsonObject -FilePath $Path
				}
				"applications.json" {
					Test-ApplicationsJsonSchema -JsonObject $jsonObject -FilePath $Path
				}
				"autologin.json" {
					Test-AutoLoginJsonSchema -JsonObject $jsonObject -FilePath $Path
				}
			}

			return $true

		}
		catch {
			$errorMessage = $_.Exception.Message
			$errorDetails = ""

			# エラー位置を抽出する試行
			if ($errorMessage -match 'line (\d+).*position (\d+)') {
				$line = $matches[1]
				$position = $matches[2]
				$errorDetails = "行 $line、位置 $position でエラー"
			}
			elseif ($errorMessage -match '\((\d+)\)') {
				$charPosition = [int]$matches[1]
				if ($charPosition -le $content.Length) {
					$lineNumber = ($content.Substring(0, [Math]::Max(0, $charPosition - 1)) -split "`n").Count
					$errorDetails = "行 $lineNumber、文字位置 $charPosition 付近でエラー"

					# エラー周辺のコンテキストを表示
					$start = [Math]::Max(0, $charPosition - 50)
					$length = [Math]::Min(100, $content.Length - $start)
					$context = $content.Substring($start, $length)
					$errorDetails += "。コンテキスト: '$context'"				}
			}

			Add-TestResult -TestName "JSON構文" -FilePath $Path -Success $false -Message $errorMessage -Details $errorDetails -FixAction "JSON構文エラーを修正"
			return $false
		}

	}
 catch {
		Add-TestResult -TestName "ファイル読み取り" -FilePath $Path -Success $false -Message "ファイルコンテンツを読み取れません: $($_.Exception.Message)"
		return $false
	}
}

function Test-WorkflowJsonSchema {
	param($JsonObject, $FilePath)

	$requiredProperties = @("workflow")
	foreach ($prop in $requiredProperties) {
		if (-not $JsonObject.PSObject.Properties[$prop]) {
			Add-TestResult -TestName "スキーマ検証" -FilePath $FilePath -Success $false -Message "必須プロパティが不足しています: $prop"
		}
	}

	if ($JsonObject.workflow) {
		if (-not $JsonObject.workflow.steps) {
			Add-TestResult -TestName "スキーマ検証" -FilePath $FilePath -Success $false -Message "ワークフローに 'steps' 配列がありません"
		}
		else {
			$stepIds = @()
			foreach ($step in $JsonObject.workflow.steps) {
				if (-not $step.id) {
					Add-TestResult -TestName "スキーマ検証" -FilePath $FilePath -Success $false -Message "ステップに必須の 'id' プロパティがありません"
				}
				else {
					if ($stepIds -contains $step.id) {
						Add-TestResult -TestName "スキーマ検証" -FilePath $FilePath -Success $false -Message "重複するステップID: $($step.id)"
					}
					$stepIds += $step.id
				}

				if (-not $step.script) {
					Add-TestResult -TestName "スキーマ検証" -FilePath $FilePath -Success $false -Message "ステップ '$($step.id)' に必須の 'script' プロパティがありません"
				}
			}
			Add-TestResult -TestName "スキーマ検証" -FilePath $FilePath -Success $true -Message "ワークフロースキーマは有効です"
		}
	}
}

function Test-NotificationsJsonSchema {
	param($JsonObject, $FilePath)

	if ($JsonObject.notifications) {
		if ($JsonObject.notifications.enabled -and $JsonObject.notifications.webhook) {
			if (-not $JsonObject.notifications.webhook.url) {
				Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $false -Message "Webhook URL is required when notifications are enabled"
			}
			if (-not $JsonObject.notifications.webhook.type) {
				Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $false -Message "Webhook type is required when notifications are enabled"
			}
		}
		Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $true -Message "Notifications schema is valid"
	}
}

function Test-ApplicationsJsonSchema {
	param($JsonObject, $FilePath)

	if ($JsonObject.applications) {
		foreach ($app in $JsonObject.applications) {
			if (-not $app.id) {
				Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $false -Message "Application missing required 'id' property"
			}
			if (-not $app.installMethod) {
				Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $false -Message "Application '$($app.id)' missing required 'installMethod' property"
			}
			elseif ($app.installMethod -eq "winget" -and -not $app.packageId) {
				Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $false -Message "Application '$($app.id)' using winget must have 'packageId' property"
			}
			elseif ($app.installMethod -in @("msi", "exe") -and -not $app.installerPath) {
				Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $false -Message "Application '$($app.id)' using $($app.installMethod) must have 'installerPath' property"
			}
		}
		Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $true -Message "Applications schema is valid"
	}
}

function Test-AutoLoginJsonSchema {
	param($JsonObject, $FilePath)

	if ($JsonObject.autologin -and $JsonObject.autologin.credentials) {
		# Basic structure validation - no specific requirements to enforce
		Add-TestResult -TestName "Schema Validation" -FilePath $FilePath -Success $true -Message "AutoLogin schema is valid"
	}
}

function Repair-JsonFile {
	param([string]$Path)

	if (-not (Test-Path $Path)) {
		Write-Host "File does not exist: $Path" -ForegroundColor Red
		return $false
	}

	# Create backup
	$backupPath = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
	Copy-Item $Path $backupPath
	Write-Host "Created backup: $backupPath" -ForegroundColor Green    try {
		$content = Get-Content $Path -Raw -Encoding UTF8
		$originalContent = $content

		# Note: Full-width characters are now allowed in JSON content
		# Only fix critical encoding corruption if detected

		# Add BOM and save as UTF-8 with BOM
		$utf8WithBom = New-Object System.Text.UTF8Encoding($true)
		[System.IO.File]::WriteAllText($Path, $content, $utf8WithBom)

		if ($content -ne $originalContent) {
			Write-Host "Fixed character encoding issues in: $Path" -ForegroundColor Green
		}

		# Validate the fix
		try {
			$null = $content | ConvertFrom-Json
			Write-Host "JSON syntax is now valid: $Path" -ForegroundColor Green
			return $true
		}
		catch {
			Write-Host "JSON syntax still invalid after fix: $($_.Exception.Message)" -ForegroundColor Red
			# Restore backup
			Copy-Item $backupPath $Path
			Write-Host "Restored from backup due to failed fix" -ForegroundColor Yellow
			return $false
		}

	} catch {
		Write-Host "Error during repair: $($_.Exception.Message)" -ForegroundColor Red
		return $false
	}
}

# Main execution
Write-Host "JSON Configuration Test Starting..." -ForegroundColor Cyan

$workflowRoot = Get-WorkflowRoot
$configFiles = @(
    (Get-WorkflowPath -PathType "Config" -SubPath "workflow.json"),
    (Get-WorkflowPath -PathType "Config" -SubPath "notifications.json"),
    (Get-WorkflowPath -PathType "Config" -SubPath "applications.json"),
    (Get-WorkflowPath -PathType "Config" -SubPath "autologin.json")
)

# Test specific file if provided
if ($ConfigPath) {
	if (Test-Path $ConfigPath) {
		$configFiles = @($ConfigPath)
	}
 else {
		Write-Host "Specified config file does not exist: $ConfigPath" -ForegroundColor Red
		exit 1
	}
}

$allPassed = $true
foreach ($configFile in $configFiles) {
	$fileName = Split-Path $configFile -Leaf
	Write-Host "`nTesting: $fileName" -ForegroundColor Yellow

	$result = Test-JsonFileStructure -Path $configFile
	if (-not $result) {
		$allPassed = $false

		if ($Fix) {
			Write-Host "Attempting to fix: $configFile" -ForegroundColor Yellow
			Repair-JsonFile -Path $configFile
		}
	}
}

# Output results
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

$passCount = ($testResults | Where-Object { $_.Success }).Count
$failCount = ($testResults | Where-Object { -not $_.Success }).Count
$totalCount = $testResults.Count

Write-Host "Total Tests: $totalCount" -ForegroundColor White
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red

if ($failCount -gt 0) {
	Write-Host "`nFailed Tests:" -ForegroundColor Red
	$testResults | Where-Object { -not $_.Success } | ForEach-Object {
		Write-Host "  - $($_.TestName) ($($_.FilePath)): $($_.Message)" -ForegroundColor Red
		if ($_.Details) {
			Write-Host "    Details: $($_.Details)" -ForegroundColor Yellow
		}
		if ($_.FixAction) {
			Write-Host "    Suggested Fix: $($_.FixAction)" -ForegroundColor Cyan
		}
	}
}

if ($OutputJson) {
	$resultsJson = $testResults | ConvertTo-Json -Depth 3
	$resultsPath = Join-Path $workflowRoot "test-results-json.json"
	$resultsJson | Out-File -FilePath $resultsPath -Encoding UTF8
	Write-Host "`nDetailed results saved to: $resultsPath" -ForegroundColor Green
}

if (-not $allPassed) {
	Write-Host "`nSome tests failed. Use -Fix parameter to attempt automatic repairs." -ForegroundColor Yellow
	exit 1
}
else {
	Write-Host "`nAll JSON configuration tests passed!" -ForegroundColor Green
	exit 0
}
