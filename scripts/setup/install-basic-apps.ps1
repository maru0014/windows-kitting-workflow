# ============================================================================
# アプリケーションインストールスクリプト
# JSONファイルで定義されたアプリケーションの一括インストール
# winget、MSI、EXEファイルのインストールに対応
# ============================================================================

param(
	[string]$ConfigPath = "",
	[string[]]$IncludeApps = @(),
	[string[]]$ExcludeApps = @(),
	[string[]]$Categories = @(),
	[int]$MaxPriority = 3,
	[switch]$Force,
	[switch]$DryRun,
	[switch]$Quiet,
	[switch]$Help
)

# ヘルプ表示
if ($Help) {
	Write-Host @"
アプリケーション一括インストールスクリプト

使用方法:
    .\install-basic-apps.ps1 [オプション]

パラメータ:
    -ConfigPath <path>         アプリケーション設定ファイルのパス
                               (デフォルト: config\applications.json)

    -IncludeApps <apps>        インストールするアプリのIDを指定
                               例: -IncludeApps "git","vscode"

    -ExcludeApps <apps>        除外するアプリのIDを指定
                               例: -ExcludeApps "teams","chrome"

    -Categories <categories>   対象カテゴリを指定
                               例: -Categories "Development","Utilities"

    -MaxPriority <number>      インストールする最大優先度 (デフォルト: 3)
                               1=必須, 2=推奨, 3=オプション

    -Force                     既にインストール済みでも強制再インストール

    -DryRun                    実際のインストールは行わず、実行予定を表示

    -Quiet                     コンソール出力を抑制（ログファイルには出力）

    -Help                      このヘルプを表示

使用例:
    # 全ての有効なアプリケーションをインストール (優先度3まで)
    .\install-basic-apps.ps1

    # ドライラン - 何がインストールされるか確認
    .\install-basic-apps.ps1 -DryRun

    # 優先度1のアプリのみをインストール
    .\install-basic-apps.ps1 -MaxPriority 1

    # 開発カテゴリのアプリのみをインストール
    .\install-basic-apps.ps1 -Categories "Development"

    # 特定のアプリのみをインストール
    .\install-basic-apps.ps1 -IncludeApps "git","vscode"

    # Teamsを除外してインストール
    .\install-basic-apps.ps1 -ExcludeApps "teams"    # 強制再インストール
    .\install-basic-apps.ps1 -Force -IncludeApps "git"

    # 静かなモード（コンソール出力なし）
    .\install-basic-apps.ps1 -Quiet

"@ -ForegroundColor Cyan
	exit 0
}

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
		[string]$Level = "INFO",
		[bool]$NoConsoleOutput = $script:Quiet
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "BasicApps" -LogFileName "basic-apps.log" -NoConsoleOutput $NoConsoleOutput
}

# アプリケーション設定の読み込み
function Read-ApplicationConfig {
	param([string]$ConfigPath)
	try {
		if (-not $ConfigPath) {
			$ConfigPath = Get-WorkflowPath -PathType "Config" -SubPath "applications.json"
		}

		if (-not (Test-Path $ConfigPath)) {
			throw "アプリケーション設定ファイルが見つかりません: $ConfigPath"
		}

		Write-Log "アプリケーション設定を読み込み中: $ConfigPath"
		$configContent = Get-Content $ConfigPath -Raw -Encoding UTF8
		$config = $configContent | ConvertFrom-Json

		Write-Log "アプリケーション設定の読み込みが完了しました"
		Write-Log "定義済みアプリケーション数: $($config.applications.Count)"

		return $config.applications
	}
	catch {
		Write-Log "アプリケーション設定の読み込みに失敗しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# アプリケーションのフィルタリング
function Get-FilteredApplications {
	param(
		[array]$Applications,
		[string[]]$IncludeApps,
		[string[]]$ExcludeApps,
		[string[]]$Categories,
		[int]$MaxPriority
	)

	Write-Log "アプリケーションのフィルタリングを開始"

	# 有効なアプリケーションのみを抽出
	$filteredApps = $Applications | Where-Object { $_.enabled -eq $true }
	Write-Log "有効なアプリケーション: $($filteredApps.Count)個"

	# 優先度フィルタ
	$filteredApps = $filteredApps | Where-Object { $_.priority -le $MaxPriority }
	Write-Log "優先度 $MaxPriority 以下のアプリケーション: $($filteredApps.Count)個"

	# カテゴリフィルタ
	if ($Categories.Count -gt 0) {
		$filteredApps = $filteredApps | Where-Object { $_.category -in $Categories }
		Write-Log "指定カテゴリのアプリケーション: $($filteredApps.Count)個"
	}

	# 包含フィルタ
	if ($IncludeApps.Count -gt 0) {
		$filteredApps = $filteredApps | Where-Object { $_.id -in $IncludeApps }
		Write-Log "包含指定のアプリケーション: $($filteredApps.Count)個"
	}

	# 除外フィルタ
	if ($ExcludeApps.Count -gt 0) {
		$filteredApps = $filteredApps | Where-Object { $_.id -notin $ExcludeApps }
		Write-Log "除外後のアプリケーション: $($filteredApps.Count)個"
	}

	# 優先度順にソート
	$filteredApps = $filteredApps | Sort-Object priority, id

	Write-Log "フィルタリング完了。インストール対象: $($filteredApps.Count)個"
	return $filteredApps
}

# wingetの可用性確認
function Test-WingetAvailable {
	try {
		$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
		if ($wingetCmd) {
			$version = & winget --version 2>$null
			Write-Log "wingetが利用可能です: $version"
			return $true
		}
		else {
			Write-Log "wingetが利用できません" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "winget確認でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# wingetパッケージの存在確認
function Test-WingetPackageInstalled {
	param([string]$PackageId)	try {
		& winget list --id $PackageId --exact 2>$null | Out-Null
		return ($LASTEXITCODE -eq 0)
	}
	catch {
		Write-Log "wingetパッケージ確認でエラー: $PackageId - $($_.Exception.Message)" -Level "WARN"
		return $false
	}
}

# MSI/EXEファイルのインストール済み確認（レジストリベース）
function Test-InstallerPackageInstalled {
	param(
		[string]$AppName,
		[string]$AppId
	)

	try {
		# アンインストール情報からアプリケーションを検索
		$uninstallKeys = @(
			"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
			"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
		)

		foreach ($keyPath in $uninstallKeys) {
			$installedApps = Get-ItemProperty $keyPath -ErrorAction SilentlyContinue |
			Where-Object { $_.DisplayName -like "*$AppName*" -or $_.PSChildName -eq $AppId }

			if ($installedApps) {
				return $true
			}
		}

		return $false
	}
	catch {
		Write-Log "インストール済み確認でエラー: $AppName - $($_.Exception.Message)" -Level "WARN"
		return $false
	}
}

# wingetパッケージのインストール
function Install-WingetPackage {
	param(
		[PSCustomObject]$App
	)

	try {
		Write-Log "─────────────────────────────────────"
		Write-Log "🔄 wingetパッケージをインストール中: $($App.name)"
		Write-Log "   ID: $($App.packageId)"
		Write-Log "   カテゴリ: $($App.category) | 優先度: $($App.priority)"

		if ((Test-WingetPackageInstalled -PackageId $App.packageId) -and -not $Force) {
			Write-Log "✅ パッケージは既にインストールされています: $($App.name)"
			return $true
		}

		if ($DryRun) {
			Write-Log "🔍 [DRY RUN] winget install --id $($App.packageId) --exact --silent --accept-source-agreements --accept-package-agreements $($App.args -join ' ')"
			return $true
		}

		$wingetArgs = @("install", "--id", $App.packageId, "--exact", "--silent", "--accept-source-agreements", "--accept-package-agreements")
		if ($App.args -and $App.args.Count -gt 0) {
			$wingetArgs += $App.args
		}

		Write-Log "💻 実行コマンド: winget $($wingetArgs -join ' ')"

		$startTime = Get-Date
		& winget @wingetArgs

		$duration = ((Get-Date) - $startTime).TotalSeconds

		if ($LASTEXITCODE -eq 0) {
			Write-Log "✅ パッケージのインストールが完了しました: $($App.name) (所要時間: $([math]::Round($duration, 1))秒)"
			return $true
		}
		else {
			Write-Log "❌ パッケージのインストールに失敗しました: $($App.name) (Exit Code: $LASTEXITCODE)" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "❌ wingetパッケージインストールでエラー: $($App.name) - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# MSIファイルのインストール
function Install-MsiPackage {
	param(
		[PSCustomObject]$App
	)

	try {
		Write-Log "─────────────────────────────────────"
		Write-Log "🔄 MSIパッケージをインストール中: $($App.name)"
		Write-Log "   ファイル: $($App.installerPath)"
		Write-Log "   カテゴリ: $($App.category) | 優先度: $($App.priority)"

		$installerPath = $App.installerPath
		if (-not [System.IO.Path]::IsPathRooted($installerPath)) {
			$workflowRoot = Get-WorkflowRoot
			$installerPath = Join-Path $workflowRoot $installerPath
		}

		if (-not (Test-Path $installerPath)) {
			Write-Log "❌ インストーラーファイルが見つかりません: $installerPath" -Level "ERROR"
			return $false
		}

		if ((Test-InstallerPackageInstalled -AppName $App.name -AppId $App.id) -and -not $Force) {
			Write-Log "✅ アプリケーションは既にインストールされています: $($App.name)"
			return $true
		}

		if ($DryRun) {
			Write-Log "🔍 [DRY RUN] msiexec.exe /i `"$installerPath`" $($App.args -join ' ')"
			return $true
		}

		$msiArgs = @("/i", "`"$installerPath`"")
		if ($App.args -and $App.args.Count -gt 0) {
			$msiArgs += $App.args
		}

		Write-Log "💻 実行コマンド: msiexec.exe $($msiArgs -join ' ')"

		$startTime = Get-Date
		$process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

		$duration = ((Get-Date) - $startTime).TotalSeconds

		if ($process.ExitCode -eq 0) {
			Write-Log "✅ MSIパッケージのインストールが完了しました: $($App.name) (所要時間: $([math]::Round($duration, 1))秒)"
			return $true
		}
		else {
			Write-Log "❌ MSIパッケージのインストールに失敗しました: $($App.name) (Exit Code: $($process.ExitCode))" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "❌ MSIパッケージインストールでエラー: $($App.name) - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# EXEファイルのインストール
function Install-ExePackage {
	param(
		[PSCustomObject]$App
	)

	try {
		Write-Log "─────────────────────────────────────"
		Write-Log "🔄 EXEパッケージをインストール中: $($App.name)"
		Write-Log "   ファイル: $($App.installerPath)"
		Write-Log "   カテゴリ: $($App.category) | 優先度: $($App.priority)"

		$installerPath = $App.installerPath
		if (-not [System.IO.Path]::IsPathRooted($installerPath)) {
			$workflowRoot = Get-WorkflowRoot
			$installerPath = Join-Path $workflowRoot $installerPath
		}

		if (-not (Test-Path $installerPath)) {
			Write-Log "❌ インストーラーファイルが見つかりません: $installerPath" -Level "ERROR"
			return $false
		}

		if ((Test-InstallerPackageInstalled -AppName $App.name -AppId $App.id) -and -not $Force) {
			Write-Log "✅ アプリケーションは既にインストールされています: $($App.name)"
			return $true
		}

		if ($DryRun) {
			Write-Log "🔍 [DRY RUN] `"$installerPath`" $($App.args -join ' ')"
			return $true
		}

		$exeArgs = @()
		if ($App.args -and $App.args.Count -gt 0) {
			$exeArgs = $App.args
		}

		Write-Log "💻 実行コマンド: `"$installerPath`" $($exeArgs -join ' ')"

		$startTime = Get-Date
		$process = Start-Process -FilePath $installerPath -ArgumentList $exeArgs -Wait -PassThru -NoNewWindow
		$duration = ((Get-Date) - $startTime).TotalSeconds

		if ($process.ExitCode -eq 0) {
			Write-Log "✅ EXEパッケージのインストールが完了しました: $($App.name) (所要時間: $([math]::Round($duration, 1))秒)"
			return $true
		}
		else {
			Write-Log "❌ EXEパッケージのインストールに失敗しました: $($App.name) (Exit Code: $($process.ExitCode))" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "❌ EXEパッケージインストールでエラー: $($App.name) - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# アプリケーションのインストール
function Install-Application {
	param(
		[PSCustomObject]$App
	)

	try {
		switch ($App.installMethod.ToLower()) {
			"winget" {
				return Install-WingetPackage -App $App
			}
			"msi" {
				return Install-MsiPackage -App $App
			}
			"exe" {
				return Install-ExePackage -App $App
			}
			default {
				Write-Log "❌ サポートされていないインストール方法: $($App.installMethod)" -Level "ERROR"
				return $false
			}
		}
	}
	catch {
		Write-Log "❌ アプリケーションインストールでエラー: $($App.name) - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# メイン処理
try {
	$scriptStartTime = Get-Date
	Write-Log "========================================="
	Write-Log "🚀 アプリケーションインストールを開始"
	Write-Log "========================================="

	# パラメータの表示
	if ($IncludeApps.Count -gt 0) {
		Write-Log "📦 包含アプリ: $($IncludeApps -join ', ')"
	}
	if ($ExcludeApps.Count -gt 0) {
		Write-Log "🚫 除外アプリ: $($ExcludeApps -join ', ')"
	}
	if ($Categories.Count -gt 0) {
		Write-Log "📂 対象カテゴリ: $($Categories -join ', ')"
	}    Write-Log "🔢 最大優先度: $MaxPriority"
	if ($Force) { Write-Log "💪 強制インストール: 有効" }
	if ($DryRun) { Write-Log "🔍 ドライラン: 有効" }
	if ($Quiet) { Write-Log "🔇 静かなモード: 有効" }

	# アプリケーション設定の読み込み
	$applications = Read-ApplicationConfig -ConfigPath $ConfigPath

	# アプリケーションのフィルタリング
	$targetApps = Get-FilteredApplications -Applications $applications -IncludeApps $IncludeApps -ExcludeApps $ExcludeApps -Categories $Categories -MaxPriority $MaxPriority

	if ($targetApps.Count -eq 0) {
		Write-Log "⚠️  インストール対象のアプリケーションがありません" -Level "WARN"
		exit 0
	}

	# winget方式のアプリがある場合はwingetの確認
	$wingetApps = $targetApps | Where-Object { $_.installMethod -eq "winget" }
	if ($wingetApps.Count -gt 0) {
		Write-Log "🔍 wingetの可用性を確認中..."
		if (-not (Test-WingetAvailable)) {
			Write-Log "❌ wingetが利用できないため、wingetアプリのインストールをスキップします" -Level "ERROR"
			$targetApps = $targetApps | Where-Object { $_.installMethod -ne "winget" }
		}
	}

	# インストール対象の一覧表示
	Write-Log "─────────────────────────────────────"
	Write-Log "📋 インストール対象アプリケーション一覧"
	Write-Log "─────────────────────────────────────"
	foreach ($app in $targetApps) {
		$methodInfo = switch ($app.installMethod) {
			"winget" { "winget: $($app.packageId)" }
			"msi" { "MSI: $($app.installerPath)" }
			"exe" { "EXE: $($app.installerPath)" }
			default { "Unknown: $($app.installMethod)" }
		}
		Write-Log "🔹 $($app.name) [$($app.category)] - $methodInfo"
	}

	# インストール実行
	Write-Log "─────────────────────────────────────"
	Write-Log "🎬 インストール開始"
	Write-Log "─────────────────────────────────────"

	$results = @()
	$successCount = 0
	$failCount = 0

	foreach ($app in $targetApps) {
		$installSuccess = Install-Application -App $app

		$results += [PSCustomObject]@{
			Name     = $app.name
			ID       = $app.id
			Method   = $app.installMethod
			Category = $app.category
			Priority = $app.priority
			Success  = $installSuccess
		}

		if ($installSuccess) {
			$successCount++
		}
		else {
			$failCount++
		}

		# 次のアプリとの間隔（最後以外）
		if ($app -ne $targetApps[-1]) {
			Start-Sleep -Seconds 2
		}
	}

	# 結果サマリー
	$totalDuration = ((Get-Date) - $scriptStartTime).TotalMinutes
	Write-Log "========================================="
	Write-Log "📊 インストール結果サマリー"
	Write-Log "========================================="
	Write-Log "📦 総アプリケーション数: $($results.Count)"
	Write-Log "✅ 成功: $successCount"
	Write-Log "❌ 失敗: $failCount"
	Write-Log "⏱️  総所要時間: $([math]::Round($totalDuration, 1))分"

	if ($failCount -gt 0) {
		Write-Log "─────────────────────────────────────"
		Write-Log "❌ 失敗したアプリケーション:"
		$failedApps = $results | Where-Object { -not $_.Success }
		foreach ($failed in $failedApps) {
			Write-Log "   • $($failed.Name) [$($failed.Method)]"
		}
	}    # カテゴリ別サマリー
	Write-Log "─────────────────────────────────────"
	Write-Log "📂 カテゴリ別結果:"
	$results | Group-Object Category | ForEach-Object {
		$success = ($_.Group | Where-Object Success).Count
		$total = $_.Count
		Write-Log "   • $($_.Name): $success/$total 成功"
	}	# 完了マーカーの作成
	$completionMarker = Get-CompletionMarkerPath -TaskName "install-basic-apps"
	$completionData = @{
		completedAt          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		totalApplications    = $results.Count
		successfulInstalls   = $successCount
		failedInstalls       = $failCount
		totalDurationMinutes = [math]::Round($totalDuration, 1)
		results              = $results
	}
	$completionData | ConvertTo-Json -Depth 3 | Out-File -FilePath $completionMarker -Encoding UTF8

	Write-Log "========================================="
	if ($failCount -eq 0) {
		Write-Log "🎉 全てのアプリケーションのインストールが完了しました！"
		exit 0
	}
 else {
		Write-Log "⚠️  一部のアプリケーションのインストールに失敗しました"
		exit 1
	}

}
catch {
	Write-Log "❌ スクリプト実行中に致命的なエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	Write-Log "スタックトレース: $($_.ScriptStackTrace)" -Level "ERROR"
	exit 1
}
