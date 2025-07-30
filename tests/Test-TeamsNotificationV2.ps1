# ==============================================================================
# Teams通知新スレッド化方式テストツール
# 改良版PowerAutomateフローとの連携テスト
# ==============================================================================
param(
	[switch]$TestSend,
	[switch]$TestIdGeneration,
	[switch]$ShowInfo,
	[switch]$ClearIds,
	[switch]$TestLineBreaks,
	[switch]$All
)

# 共通関数の読み込み
$scriptPath = Split-Path $MyInvocation.MyCommand.Path -Parent
$commonFunctionsPath = Join-Path (Split-Path $scriptPath -Parent) "scripts\Common-NotificationFunctions.ps1"

if (Test-Path $commonFunctionsPath) {
	. $commonFunctionsPath
	Write-Host "共通関数を読み込みました: $commonFunctionsPath" -ForegroundColor Green
}
else {
	Write-Host "共通関数が見つかりません: $commonFunctionsPath" -ForegroundColor Red
	exit 1
}

# ログ関数（簡易版）
function Write-Log {
	param(
		[string]$Message,
		[string]$Level = "INFO"
	)
	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logMessage = "[$timestamp] [$Level] $Message"
	Write-Host $logMessage
}

# PCシリアル番号取得関数（簡易版）
function Get-PCSerialNumber {
	try {
		$serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
		if ([string]::IsNullOrWhiteSpace($serialNumber)) {
			$serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
		}
		if ([string]::IsNullOrWhiteSpace($serialNumber)) {
			return $env:COMPUTERNAME
		}
		return $serialNumber -replace '\s+', '' -replace '[^\w]', ''
	}
	catch {
		return $env:COMPUTERNAME
	}
}

# マシンID生成テスト
function Test-MachineIdGeneration {
	Write-Log "=== マシンID生成テスト ===" -Level "INFO"

	try {
		# 通知設定の読み込み
		$configPath = Join-Path (Split-Path $scriptPath -Parent) "config\notifications.json"
		if (-not (Import-NotificationConfig -ConfigPath $configPath)) {
			Write-Log "通知設定の読み込みに失敗しました" -Level "ERROR"
			return $false
		}

		# マシンIDの生成・取得
		$machineId = Get-OrCreate-MachineId
		Write-Log "生成されたマシンID: $machineId" -Level "INFO"

		# 再度取得して一意性を確認
		$machineId2 = Get-OrCreate-MachineId
		Write-Log "再取得されたマシンID: $machineId2" -Level "INFO"

		if ($machineId -eq $machineId2) {
			Write-Log "✅ マシンIDの一意性が確認されました" -Level "INFO"
			return $true
		}
		else {
			Write-Log "❌ マシンIDの一意性に問題があります" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "マシンID生成テストでエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# Teams通知送信テスト
function Test-TeamsNotificationSend {
	Write-Log "=== Teams通知送信テスト ===" -Level "INFO"

	try {
		# 通知設定の読み込み
		$configPath = Join-Path (Split-Path $scriptPath -Parent) "config\notifications.json"
		if (-not (Import-NotificationConfig -ConfigPath $configPath)) {
			Write-Log "通知設定の読み込みに失敗しました" -Level "ERROR"
			return $false
		}

		# テストメッセージの作成
		$testMessage = "🔄 新方式テスト: $(Get-Date -Format 'HH:mm:ss')`nPC名: $env:COMPUTERNAME`nシリアル番号: $(Get-PCSerialNumber)"

		Write-Log "送信するメッセージ:" -Level "INFO"
		Write-Log $testMessage -Level "INFO"

		# 通知送信
		$result = Send-TeamsNotification -Message $testMessage

		if ($result) {
			Write-Log "✅ Teams通知送信テストが成功しました" -Level "INFO"
			return $true
		}
		else {
			Write-Log "❌ Teams通知送信テストが失敗しました" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "Teams通知送信テストでエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}







# Teams情報表示
function Show-TeamsInfo {
	Write-Log "=== Teams設定情報 ===" -Level "INFO"

	try {
		# 通知設定の読み込み
		$configPath = Join-Path (Split-Path $scriptPath -Parent) "config\notifications.json"
		if (-not (Import-NotificationConfig -ConfigPath $configPath)) {
			Write-Log "通知設定の読み込みに失敗しました" -Level "ERROR"
			return $false
		}

		$teamsConfig = $Global:NotificationConfig.notifications.providers.teams

		Write-Log "Teams設定:" -Level "INFO"
		Write-Log "  有効: $($teamsConfig.enabled)" -Level "INFO"
		Write-Log "  Flow URL: $($teamsConfig.flowUrl)" -Level "INFO"
		Write-Log "  Team ID: $($teamsConfig.teamId)" -Level "INFO"
		Write-Log "  Channel ID: $($teamsConfig.channelId)" -Level "INFO"
		Write-Log "  ID保存パス: $($teamsConfig.idStoragePath)" -Level "INFO"

		# マシンID情報
		if ($teamsConfig.enabled) {
			$machineId = Get-OrCreate-MachineId -StoragePath $teamsConfig.idStoragePath
			Write-Log "  現在のマシンID: $machineId" -Level "INFO"
		}

		return $true
	}
	catch {
		Write-Log "Teams情報表示でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# マシンIDクリア
function Clear-MachineIds {
	Write-Log "=== マシンIDクリア ===" -Level "INFO"

	try {
		# 通知設定の読み込み
		$configPath = Join-Path (Split-Path $scriptPath -Parent) "config\notifications.json"
		if (-not (Import-NotificationConfig -ConfigPath $configPath)) {
			Write-Log "通知設定の読み込みに失敗しました" -Level "ERROR"
			return $false
		}

		$teamsConfig = $Global:NotificationConfig.notifications.providers.teams
		$idFile = Join-Path (Split-Path $scriptPath -Parent) $teamsConfig.idStoragePath

		if (Test-Path $idFile) {
			Remove-Item $idFile -Force
			Write-Log "✅ マシンIDファイルを削除しました: $idFile" -Level "INFO"
		}
		else {
			Write-Log "マシンIDファイルが見つかりません: $idFile" -Level "WARN"
		}

		return $true
	}
	catch {
		Write-Log "マシンIDクリアでエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# メイン実行
Write-Log "Teams通知新スレッド化方式テストツールを開始します" -Level "INFO"

$results = @()

if ($TestIdGeneration -or $All) {
	$results += Test-MachineIdGeneration
}

if ($TestSend -or $All) {
	$results += Test-TeamsNotificationSend
}

if ($TestLineBreaks -or $All) {
	$results += Test-TeamsNotificationSend
}

if ($ShowInfo -or $All) {
	$results += Show-TeamsInfo
}

if ($ClearIds) {
	$results += Clear-MachineIds
}

# 結果サマリー
Write-Log "=== テスト結果サマリー ===" -Level "INFO"
$successCount = ($results | Where-Object { $_ -eq $true }).Count
$totalCount = $results.Count

Write-Log "成功: $successCount / $totalCount" -Level "INFO"

if ($successCount -eq $totalCount) {
	Write-Log "✅ すべてのテストが成功しました" -Level "INFO"
	exit 0
}
else {
	Write-Log "❌ 一部のテストが失敗しました" -Level "ERROR"
	exit 1
}
