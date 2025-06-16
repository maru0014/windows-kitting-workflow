# ==============================================================================
# テストランナー - 包括的なレポート機能付きですべてのテストスイートを実行
# CI/CD統合と自動テストワークフローをサポート
# ==============================================================================

param(
	[string[]]$TestSuites = @("JsonConfiguration", "ProjectStructure"),
	[switch]$Fix = $false,
	[switch]$Verbose = $false,
	[switch]$OutputJson = $false,
	[switch]$ContinueOnFailure = $false,
	[string]$OutputPath = "",
	[switch]$GenerateReport = $false
)

$scriptRoot = Split-Path $PSScriptRoot -Parent
$overallResults = @()

function Write-TestHeader {
	param([string]$Title)

	$border = "=" * 60
	Write-Host ""
	Write-Host $border -ForegroundColor Cyan
	Write-Host $Title.ToUpper().PadLeft(($border.Length + $Title.Length) / 2) -ForegroundColor White
	Write-Host $border -ForegroundColor Cyan
	Write-Host ""
}

function Write-TestFooter {
	param([string]$TestName, [bool]$Success, [int]$PassCount, [int]$FailCount)

	$status = if ($Success) { "成功" } else { "失敗" }
	$color = if ($Success) { "Green" } else { "Red" }

	Write-Host ""
	Write-Host "$TestName の結果: $status ($PassCount 個成功, $FailCount 個失敗)" -ForegroundColor $color
	Write-Host ("-" * 60) -ForegroundColor Gray
}

function Invoke-JsonConfigurationTests {
	Write-TestHeader "JSON設定ファイルテスト"

	$testScript = Join-Path $PSScriptRoot "Test-JsonConfiguration.ps1"
	if (-not (Test-Path $testScript)) {
		Write-Host "テストスクリプトが見つかりません: $testScript" -ForegroundColor Red
		return $false
	}

	try {
		$params = @{
			Verbose    = $Verbose
			OutputJson = $OutputJson
		}
		if ($Fix) { $params.Fix = $true }

		& $testScript @params
		$success = $LASTEXITCODE -eq 0

		$script:overallResults += [PSCustomObject]@{
			TestSuite = "JsonConfiguration"
			Success   = $success
			ExitCode  = $LASTEXITCODE
			Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		}

		return $success	}
 catch {
		Write-Host "JSON設定テストの実行中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
		return $false
	}
}

function Invoke-ProjectStructureTests {
	Write-TestHeader "プロジェクト構造テスト"

	$testScript = Join-Path $PSScriptRoot "Test-ProjectStructure.ps1"
	if (-not (Test-Path $testScript)) {
		Write-Host "テストスクリプトが見つかりません: $testScript" -ForegroundColor Red
		return $false
	}

	try {
		$params = @{
			Verbose    = $Verbose
			OutputJson = $OutputJson
		}

		& $testScript @params
		$success = $LASTEXITCODE -eq 0

		$script:overallResults += [PSCustomObject]@{
			TestSuite = "ProjectStructure"
			Success   = $success
			ExitCode  = $LASTEXITCODE
			Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		}

		return $success	}
 catch {
		Write-Host "プロジェクト構造テストの実行中にエラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
		return $false
	}
}

function Invoke-IntegrationTests {
	Write-TestHeader "統合テスト"

	Write-Host "コンポーネント間の依存関係をテスト中..." -ForegroundColor Yellow
	$integrationResults = @()

	# テスト 1: workflow.jsonが既存のスクリプトを参照していることを確認
	try {
		$workflowPath = Join-Path $scriptRoot "config\workflow.json"
		if (Test-Path $workflowPath) {
			$workflow = Get-Content $workflowPath -Raw | ConvertFrom-Json

			if ($workflow.workflow.steps) {
				foreach ($step in $workflow.workflow.steps) {
					if ($step.script) {
						$scriptPath = Join-Path $scriptRoot $step.script
						if (Test-Path $scriptPath) {
							$integrationResults += [PSCustomObject]@{
								Test    = "スクリプト参照"
								Target  = $step.script
								Success = $true
								Message = "スクリプトファイルが存在します"
							}
						}
						else {
							$integrationResults += [PSCustomObject]@{
								Test    = "スクリプト参照"
								Target  = $step.script
								Success = $false
								Message = "参照されているスクリプトファイルが存在しません"
							}
						}
					}
				}
			}
		}
	}
 catch {		$integrationResults += [PSCustomObject]@{
			Test    = "ワークフロー設定"
			Target  = "workflow.json"
			Success = $false
			Message = "ワークフロー設定を解析できません: $($_.Exception.Message)"
		}
	}

	# テスト 2: applications.jsonのwingetパッケージを確認（サンプルチェック）
	try {
		$appsPath = Join-Path $scriptRoot "config\applications.json"
		if (Test-Path $appsPath) {
			$apps = Get-Content $appsPath -Raw | ConvertFrom-Json

			if ($apps.applications) {
				$wingetApps = $apps.applications | Where-Object { $_.installMethod -eq "winget" }
				$integrationResults += [PSCustomObject]@{
					Test    = "アプリケーション設定"
					Target  = "applications.json"
					Success = $true
					Message = "$($wingetApps.Count) 個のwingetアプリケーションが設定されています"
				}
			}
		}
		else {
			$integrationResults += [PSCustomObject]@{
				Test    = "アプリケーション設定"
				Target  = "applications.json"
				Success = $true
				Message = "オプションのapplications.jsonが存在しません"
			}
		}
	}
 catch {
		$integrationResults += [PSCustomObject]@{
			Test    = "アプリケーション設定"
			Target  = "applications.json"
			Success = $false
			Message = "アプリケーション設定を解析できません: $($_.Exception.Message)"
		}
	}

	# テスト 3: 共通ログ機能が読み込み可能であることを確認
	try {
		$logFunctionsPath = Join-Path $scriptRoot "scripts\Common-LogFunctions.ps1"
		if (Test-Path $logFunctionsPath) {
			# 構文エラーをチェックするためにファイルをドットソースで読み込み
			$tempScript = {
				param($Path)
				. $Path
			}
			$null = & $tempScript $logFunctionsPath

			$integrationResults += [PSCustomObject]@{
				Test    = "共通機能"
				Target  = "Common-LogFunctions.ps1"
				Success = $true
				Message = "共通ログ機能が正常に読み込まれました"
			}
		}
		else {
			$integrationResults += [PSCustomObject]@{
				Test    = "共通機能"
				Target  = "Common-LogFunctions.ps1"
				Success = $false
				Message = "共通ログ機能ファイルが見つかりません"
			}
		}
	}
 catch {
		$integrationResults += [PSCustomObject]@{
			Test    = "共通機能"
			Target  = "Common-LogFunctions.ps1"
			Success = $false
			Message = "共通機能の読み込み中にエラーが発生しました: $($_.Exception.Message)"
		}
	}

	# 統合テスト結果を表示
	$passCount = ($integrationResults | Where-Object { $_.Success }).Count
	$failCount = ($integrationResults | Where-Object { -not $_.Success }).Count

	foreach ($result in $integrationResults) {
		$status = if ($result.Success) { "[成功]" } else { "[失敗]" }
		$color = if ($result.Success) { "Green" } else { "Red" }
		Write-Host "$status $($result.Test) - $($result.Target)" -ForegroundColor $color

		if (-not $result.Success -or $Verbose) {
			Write-Host "  $($result.Message)" -ForegroundColor Yellow
		}
	}

	$success = $failCount -eq 0

	$script:overallResults += [PSCustomObject]@{
		TestSuite = "Integration"
		Success   = $success
		ExitCode  = if ($success) { 0 } else { 1 }
		Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		Details   = $integrationResults
	}

	Write-TestFooter "統合テスト" $success $passCount $failCount
	return $success
}

function New-TestReport {
	param([string]$OutputPath)

	$reportPath = if ($OutputPath) { $OutputPath } else { Join-Path $scriptRoot "test-report.html" }
	$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Windows Kitting Workflow テストレポート</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .test-suite { margin: 20px 0; border: 1px solid #ccc; border-radius: 5px; }
        .test-suite-header { background-color: #e0e0e0; padding: 10px; font-weight: bold; }
        .test-suite.passed .test-suite-header { background-color: #d4edda; color: #155724; }
        .test-suite.failed .test-suite-header { background-color: #f8d7da; color: #721c24; }
        .test-details { padding: 10px; }
        .timestamp { color: #666; font-size: 0.9em; }
        .summary { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Windows Kitting Workflow テストレポート</h1>
        <p class="timestamp">生成日時: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    </div>
"@
	foreach ($result in $overallResults) {
		$statusClass = if ($result.Success) { "passed" } else { "failed" }
		$statusText = if ($result.Success) { "成功" } else { "失敗" }

		$html += @"
    <div class="test-suite $statusClass">
        <div class="test-suite-header">
            $($result.TestSuite) - $statusText
        </div>
        <div class="test-details">
            <p><strong>終了コード:</strong> $($result.ExitCode)</p>
            <p><strong>実行時刻:</strong> $($result.Timestamp)</p>
"@

		if ($result.Details) {
			$html += "<h4>詳細:</h4><ul>"
			foreach ($detail in $result.Details) {
				$detailStatus = if ($detail.Success) { "✓" } else { "✗" }
				$html += "<li>$detailStatus $($detail.Test) - $($detail.Target): $($detail.Message)</li>"
			}
			$html += "</ul>"
		}

		$html += "</div></div>"
	}

	$totalTests = $overallResults.Count
	$passedTests = ($overallResults | Where-Object { $_.Success }).Count
	$failedTests = $totalTests - $passedTests

	$html += @"
    <div class="summary">
        <h3>概要</h3>
        <p><strong>総テストスイート数:</strong> $totalTests</p>
        <p><strong>成功:</strong> $passedTests</p>
        <p><strong>失敗:</strong> $failedTests</p>
        <p><strong>成功率:</strong> $(if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 })%</p>
    </div>
</body>
</html>
"@

	$html | Out-File -FilePath $reportPath -Encoding UTF8
	Write-Host "テストレポートが生成されました: $reportPath" -ForegroundColor Green
}

# メイン実行
Write-Host "Windows Kitting Workflow テストランナーを開始中..." -ForegroundColor Cyan
Write-Host "テストスイート: $($TestSuites -join ', ')" -ForegroundColor Yellow

if ($Fix) {
	Write-Host "自動修復モードが有効です" -ForegroundColor Yellow
}

$allTestsPassed = $true
$executedTests = 0

foreach ($testSuite in $TestSuites) {
	$testPassed = $false
	$executedTests++

	switch ($testSuite) {
		"JsonConfiguration" {
			$testPassed = Invoke-JsonConfigurationTests
		}
		"ProjectStructure" {
			$testPassed = Invoke-ProjectStructureTests
		}
		"Integration" {
			$testPassed = Invoke-IntegrationTests		}
		default {
			Write-Host "未知のテストスイート: $testSuite" -ForegroundColor Red
			$testPassed = $false
		}
	}

	if (-not $testPassed) {
		$allTestsPassed = $false

		if (-not $ContinueOnFailure) {
			Write-Host "テストスイート '$testSuite' が失敗しました。実行を停止します。" -ForegroundColor Red
			break
		}
		else {
			Write-Host "テストスイート '$testSuite' が失敗しました。残りのテストを続行します。" -ForegroundColor Yellow
		}
	}
}

# 明示的に除外されていない場合は常に統合テストを実行
if ($TestSuites -notcontains "Integration" -and $allTestsPassed) {
	Write-Host "`n統合テストを実行中..." -ForegroundColor Cyan
	$integrationPassed = Invoke-IntegrationTests
	if (-not $integrationPassed) {
		$allTestsPassed = $false
	}
}

# 最終概要
Write-TestHeader "最終テスト概要"

$totalSuites = $overallResults.Count
$passedSuites = ($overallResults | Where-Object { $_.Success }).Count
$failedSuites = $totalSuites - $passedSuites

Write-Host "実行されたテストスイート: $totalSuites" -ForegroundColor White
Write-Host "成功: $passedSuites" -ForegroundColor Green
Write-Host "失敗: $failedSuites" -ForegroundColor Red

if ($failedSuites -gt 0) {
	Write-Host "`n失敗したテストスイート:" -ForegroundColor Red
	$overallResults | Where-Object { -not $_.Success } | ForEach-Object {
		Write-Host "  - $($_.TestSuite) (終了コード: $($_.ExitCode))" -ForegroundColor Red
	}
}

# レポート生成（要求された場合）
if ($GenerateReport) {
	New-TestReport -OutputPath $OutputPath
}

# JSON結果のエクスポート（要求された場合）
if ($OutputJson) {
	$jsonPath = if ($OutputPath) {
		[System.IO.Path]::ChangeExtension($OutputPath, ".json")
	}
 else {
		Join-Path $scriptRoot "test-results-all.json"
	}

	$overallResults | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8
	Write-Host "JSON結果がエクスポートされました: $jsonPath" -ForegroundColor Green
}

# 適切な終了コードで終了
if ($allTestsPassed) {
	Write-Host "`nすべてのテストが正常に完了しました！" -ForegroundColor Green
	exit 0
}
else {
	Write-Host "`n一部のテストが失敗しました。詳細は上記の出力を確認してください。" -ForegroundColor Red
	exit 1
}
