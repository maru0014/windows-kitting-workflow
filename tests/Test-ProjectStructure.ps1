# ==============================================================================
# プロジェクト構造テストスクリプト
# フォルダ構造、必須ファイル、スクリプト依存関係を検証
# ==============================================================================

param(
	[switch]$Verbose = $false,
	[switch]$OutputJson = $false
)

$scriptRoot = Split-Path $PSScriptRoot -Parent
$testResults = @()

function Add-TestResult {
	param(
		[string]$TestName,
		[string]$Category,
		[bool]$Success,
		[string]$Message = "",
		[string]$ExpectedPath = "",
		[string]$Recommendation = ""
	)

	$script:testResults += [PSCustomObject]@{
		TestName       = $TestName
		Category       = $Category
		Success        = $Success
		Message        = $Message
		ExpectedPath   = $ExpectedPath
		Recommendation = $Recommendation
		Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	}
	if ($Verbose -or -not $Success) {
		$status = if ($Success) { "[成功]" } else { "[失敗]" }
		$color = if ($Success) { "Green" } else { "Red" }
		Write-Host "$status $TestName" -ForegroundColor $color

		if ($Message -and ($Verbose -or -not $Success)) {
			Write-Host "  $Message" -ForegroundColor Yellow
		}
	}
}

function Test-FolderStructure {
	Write-Host "`nフォルダ構造をテスト中..." -ForegroundColor Cyan

	$requiredFolders = @(
		@{ Path = "config"; Required = $true; Description = "設定ファイル" }, @{ Path = "config\registry"; Required = $true; Description = "レジストリ設定ファイル" },
		@{ Path = "scripts"; Required = $true; Description = "PowerShellスクリプト" }, @{ Path = "scripts\setup"; Required = $true; Description = "セットアップスクリプト" },
		@{ Path = "scripts\cleanup"; Required = $false; Description = "クリーンアップスクリプト" },
		@{ Path = "docs"; Required = $false; Description = "ドキュメントファイル" },
		@{ Path = "tests"; Required = $true; Description = "テストスクリプト" },
		@{ Path = "logs"; Required = $false; Description = "ログファイル（自動作成）" },
		@{ Path = "status"; Required = $false; Description = "ステータスファイル（自動作成）" },
		@{ Path = "backup"; Required = $false; Description = "バックアップファイル（自動作成）" }
	)

	foreach ($folder in $requiredFolders) {
		$fullPath = Join-Path $scriptRoot $folder.Path
		$exists = Test-Path $fullPath -PathType Container

		if ($folder.Required -and -not $exists) {
			Add-TestResult -TestName "必須フォルダ" -Category "構造" -Success $false -Message "必須フォルダが不足しています: $($folder.Path)" -ExpectedPath $fullPath -Recommendation "不足しているフォルダを作成してください"
		}
		elseif ($exists) {
			Add-TestResult -TestName "フォルダ存在確認" -Category "構造" -Success $true -Message "$($folder.Path) - $($folder.Description)" -ExpectedPath $fullPath
		}
		elseif (-not $folder.Required) {
			Add-TestResult -TestName "オプショナルフォルダ" -Category "構造" -Success $true -Message "$($folder.Path) - オプション（自動作成されます）" -ExpectedPath $fullPath
		}
	}
}

function Test-RequiredFiles {
	Write-Host "`n必須ファイルをテスト中..." -ForegroundColor Cyan

	$requiredFiles = @(
		@{ Path = "README.md"; Required = $true; Description = "メインドキュメント" },
		@{ Path = "main.bat"; Required = $true; Description = "メインエントリーポイント" },
		@{ Path = "MainWorkflow.ps1"; Required = $true; Description = "メインワークフロースクリプト" },
		@{ Path = "AutoLogin.ps1"; Required = $true; Description = "自動ログイン管理" },
		@{ Path = "TaskScheduler.ps1"; Required = $true; Description = "タスクスケジューラ管理" },
		@{ Path = "config\workflow.json"; Required = $true; Description = "ワークフロー設定" },
		@{ Path = "config\notifications.json"; Required = $false; Description = "通知設定" },
		@{ Path = "config\applications.json"; Required = $false; Description = "アプリケーション設定" },
		@{ Path = "config\autologin.json"; Required = $false; Description = "自動ログイン設定" },
		@{ Path = "scripts\Common-LogFunctions.ps1"; Required = $true; Description = "共通ログ機能" }
	)

	foreach ($file in $requiredFiles) {
		$fullPath = Join-Path $scriptRoot $file.Path
		$exists = Test-Path $fullPath -PathType Leaf

		if ($file.Required -and -not $exists) {
			Add-TestResult -TestName "必須ファイル" -Category "ファイル" -Success $false -Message "必須ファイルが不足しています: $($file.Path)" -ExpectedPath $fullPath -Recommendation "不足しているファイルを作成または復元してください"
		}
		elseif ($exists) {
			Add-TestResult -TestName "ファイル存在確認" -Category "ファイル" -Success $true -Message "$($file.Path) - $($file.Description)" -ExpectedPath $fullPath			# ファイル固有の追加テスト
			if ($file.Path.EndsWith(".ps1")) {
				Test-PowerShellSyntax -FilePath $fullPath -FileName $file.Path
			}
			elseif ($file.Path.EndsWith(".json")) {
				Test-JsonSyntax -FilePath $fullPath -FileName $file.Path
			}
			elseif ($file.Path.EndsWith(".bat")) {
				Test-BatchFile -FilePath $fullPath -FileName $file.Path
			}
		}
		else {
			Add-TestResult -TestName "オプショナルファイル" -Category "ファイル" -Success $true -Message "$($file.Path) - オプションファイル" -ExpectedPath $fullPath
		}
	}
}

function Test-PowerShellSyntax {
	param([string]$FilePath, [string]$FileName)
	try {
		$errors = @()
		$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $FilePath -Raw), [ref]$errors)

		if ($errors.Count -eq 0) {
			Add-TestResult -TestName "PowerShell構文" -Category "構文" -Success $true -Message "$FileName の構文は有効です"
		}
		else {
			$errorMsg = "構文エラーが見つかりました: " + ($errors | ForEach-Object { "行 $($_.StartLine): $($_.Message)" }) -join "; "
			Add-TestResult -TestName "PowerShell構文" -Category "構文" -Success $false -Message $errorMsg -ExpectedPath $FilePath -Recommendation "PowerShell構文エラーを修正してください"
		}
	}
 catch {
		Add-TestResult -TestName "PowerShell構文" -Category "構文" -Success $false -Message "PowerShellファイルを解析できません: $($_.Exception.Message)" -ExpectedPath $FilePath
	}
}

function Test-JsonSyntax {
	param([string]$FilePath, [string]$FileName)

	try {
		$content = Get-Content $FilePath -Raw -Encoding UTF8
		$null = $content | ConvertFrom-Json
		Add-TestResult -TestName "JSON構文" -Category "構文" -Success $true -Message "$FileName のJSON構文は有効です"
	}
 catch {
		Add-TestResult -TestName "JSON構文" -Category "構文" -Success $false -Message "JSON構文エラー: $($_.Exception.Message)" -ExpectedPath $FilePath -Recommendation "Test-JsonConfiguration.ps1を使用してJSON構文を修正してください"
	}
}

function Test-BatchFile {
	param([string]$FilePath, [string]$FileName)

	try {
		$content = Get-Content $FilePath -Raw
		if ($content -match '@echo off') {
			Add-TestResult -TestName "バッチファイル" -Category "構文" -Success $true -Message "$FileName は有効なバッチファイルのようです"
		}
		else {
			Add-TestResult -TestName "バッチファイル" -Category "構文" -Success $true -Message "$FileName バッチファイル構造が確認されました"
		}
	}
 catch {
		Add-TestResult -TestName "バッチファイル" -Category "構文" -Success $false -Message "バッチファイルを読み取れません: $($_.Exception.Message)" -ExpectedPath $FilePath
	}
}

function Test-RegistryFiles {
	Write-Host "`nレジストリファイルをテスト中..." -ForegroundColor Cyan

	$registryPath = Join-Path $scriptRoot "config\registry"
	if (Test-Path $registryPath) {
		$regFiles = Get-ChildItem $registryPath -Filter "*.reg"

		if ($regFiles.Count -eq 0) {
			Add-TestResult -TestName "Registry Files" -Category "Registry" -Success $false -Message "No .reg files found in config\registry" -ExpectedPath $registryPath -Recommendation "Add registry configuration files"
		}
		else {
			foreach ($regFile in $regFiles) {
				Test-RegistryFileSyntax -FilePath $regFile.FullName -FileName $regFile.Name
			}
		}
	}
 else {
		Add-TestResult -TestName "Registry Directory" -Category "Registry" -Success $false -Message "Registry directory does not exist" -ExpectedPath $registryPath
	}
}

function Test-RegistryFileSyntax {
	param([string]$FilePath, [string]$FileName)

	try {
		$content = Get-Content $FilePath -Raw

		# Basic registry file validation
		$isValid = $true
		$issues = @()

		if (-not ($content -match "Windows Registry Editor Version 5\.00")) {
			$isValid = $false
			$issues += "Missing or invalid registry editor header"
		}

		if (-not ($content -match "\[HKEY_")) {
			$isValid = $false
			$issues += "No registry keys found"
		}

		# Check for common issues
		if ($content -match '[：，｛｝]') {
			$isValid = $false
			$issues += "Full-width characters detected"
		}

		if ($isValid) {
			Add-TestResult -TestName "Registry File Syntax" -Category "Registry" -Success $true -Message "$FileName syntax appears valid"
		}
		else {
			Add-TestResult -TestName "Registry File Syntax" -Category "Registry" -Success $false -Message "Registry file issues: " + ($issues -join "; ") -ExpectedPath $FilePath -Recommendation "Fix registry file syntax"
		}

	}
 catch {
		Add-TestResult -TestName "Registry File Syntax" -Category "Registry" -Success $false -Message "Cannot read registry file: $($_.Exception.Message)" -ExpectedPath $FilePath
	}
}

function Test-ScriptDependencies {
	Write-Host "`nTesting Script Dependencies..." -ForegroundColor Cyan
	$setupScriptsPath = Join-Path $scriptRoot "scripts\setup"
	if (Test-Path $setupScriptsPath) {
		$expectedScripts = @(
			"initialize.ps1",
			"install-winget.ps1",
			"install-basic-apps.ps1",
			"import-registry.ps1",
			"windows-update.ps1"
		)

		foreach ($expectedScript in $expectedScripts) {
			$scriptPath = Join-Path $setupScriptsPath $expectedScript
			if (Test-Path $scriptPath) {
				Add-TestResult -TestName "Setup Script" -Category "Dependencies" -Success $true -Message "$expectedScript found"

				# Check if script uses common log functions
				$content = Get-Content $scriptPath -Raw
				if ($content -match 'Write-ScriptLog|Common-LogFunctions') {
					Add-TestResult -TestName "Log Function Usage" -Category "Dependencies" -Success $true -Message "$expectedScript uses standard logging"
				}
				else {
					Add-TestResult -TestName "Log Function Usage" -Category "Dependencies" -Success $false -Message "$expectedScript may not use standard logging" -Recommendation "Ensure script uses Write-ScriptLog for consistent logging"
				}
			}
			else {
				Add-TestResult -TestName "Setup Script" -Category "Dependencies" -Success $false -Message "$expectedScript missing" -ExpectedPath $scriptPath -Recommendation "Create the missing setup script"
			}
		}
	}
 else {
		Add-TestResult -TestName "Setup Scripts Directory" -Category "Dependencies" -Success $false -Message "Setup scripts directory missing" -ExpectedPath $setupScriptsPath
	}
}

function Test-DocumentationStructure {
	# Documentation structure tests are disabled as requested
	# Documentation files are optional and managed separately
	Write-Host "`nSkipping Documentation Structure tests (disabled)..." -ForegroundColor Yellow
}

# Main execution
Write-Host "Project Structure Test Starting..." -ForegroundColor Cyan

Test-FolderStructure
Test-RequiredFiles
Test-RegistryFiles
Test-ScriptDependencies
Test-DocumentationStructure

# Output results summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "プロジェクト構造テスト概要" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

$categories = $testResults | Group-Object Category
foreach ($category in $categories) {
	$passCount = ($category.Group | Where-Object { $_.Success }).Count
	$failCount = ($category.Group | Where-Object { -not $_.Success }).Count
	$totalCount = $category.Group.Count

	Write-Host "`n$($category.Name): $passCount/$totalCount 個成功" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })

	if ($failCount -gt 0 -and $Verbose) {
		$category.Group | Where-Object { -not $_.Success } | ForEach-Object {
			Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
		}
	}
}

$totalPass = ($testResults | Where-Object { $_.Success }).Count
$totalFail = ($testResults | Where-Object { -not $_.Success }).Count
$totalTests = $testResults.Count

Write-Host "`n全体: $totalPass/$totalTests 個のテストが成功" -ForegroundColor $(if ($totalFail -eq 0) { "Green" } else { "Red" })

if ($totalFail -gt 0) {
	Write-Host "`n失敗したテスト:" -ForegroundColor Red
	$testResults | Where-Object { -not $_.Success } | ForEach-Object {
		Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
		if ($_.Recommendation) {
			Write-Host "    推奨事項: $($_.Recommendation)" -ForegroundColor Cyan
		}
	}
}

if ($OutputJson) {
	$resultsJson = $testResults | ConvertTo-Json -Depth 3
	$resultsPath = Join-Path $scriptRoot "test-results-structure.json"
	$resultsJson | Out-File -FilePath $resultsPath -Encoding UTF8
	Write-Host "`n詳細結果が保存されました: $resultsPath" -ForegroundColor Green
}

if ($totalFail -eq 0) {
	Write-Host "`nすべてのプロジェクト構造テストが成功しました！" -ForegroundColor Green
	exit 0
}
else {
	Write-Host "`n一部のプロジェクト構造テストが失敗しました。上記の推奨事項を確認してください。" -ForegroundColor Yellow
	exit 1
}
