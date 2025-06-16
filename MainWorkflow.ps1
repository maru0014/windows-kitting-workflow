# ============================================================================
# Windows Kitting Workflow メインワークフローエンジン
# Windows 11 PC フルオートセットアップ
# ============================================================================

param(
	[Parameter(Mandatory = $true)]
	[string]$ConfigPath,

	[Parameter(Mandatory = $true)]
	[string]$NotificationConfigPath,

	[string]$LogLevel = "INFO",

	[switch]$DryRun
)

# グローバル変数
$Global:WorkflowConfig = $null
$Global:NotificationConfig = $null
$Global:WorkflowStartTime = Get-Date
$Global:LogPath = Join-Path $PSScriptRoot "logs\workflow.log"
$Global:ErrorLogPath = Join-Path $PSScriptRoot "logs\error.log"
$Global:StatusPath = Join-Path $PSScriptRoot "status"
$Global:LogLevel = $LogLevel

# LogLevelの優先度を定義
$Global:LogLevelPriority = @{
	"DEBUG" = 0
	"INFO"  = 1
	"WARN"  = 2
	"ERROR" = 3
}

# LogLevelをチェックする関数
function Test-LogLevel {
	param(
		[string]$MessageLevel
	)

	# 現在の設定LogLevelを取得（workflow.json > パラメータ > デフォルト）
	$currentLogLevel = "INFO"
	if ($Global:WorkflowConfig -and $Global:WorkflowConfig.workflow.settings.logLevel) {
		$currentLogLevel = $Global:WorkflowConfig.workflow.settings.logLevel
	}
 elseif ($Global:LogLevel) {
		$currentLogLevel = $Global:LogLevel
	}

	$currentPriority = $Global:LogLevelPriority[$currentLogLevel]
	$messagePriority = $Global:LogLevelPriority[$MessageLevel]

	return $messagePriority -ge $currentPriority
}

# ログ関数
function Write-Log {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	# LogLevelチェック - 設定レベル未満のログは出力しない
	if (-not (Test-LogLevel -MessageLevel $Level)) {
		return
	}

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logMessage = "[$timestamp] [$Level] $Message"

	# コンソール出力
	switch ($Level) {
		"ERROR" { Write-Host $logMessage -ForegroundColor Red }
		"WARN" { Write-Host $logMessage -ForegroundColor Yellow }
		"INFO" { Write-Host $logMessage -ForegroundColor Green }
		"DEBUG" { Write-Host $logMessage -ForegroundColor Cyan }
	}

	# ファイル出力（UTF-8 with BOM）
	Write-LogToFile -Path $Global:LogPath -Message $logMessage

	if ($Level -eq "ERROR") {
		Write-LogToFile -Path $Global:ErrorLogPath -Message $logMessage
	}
}

# UTF-8 with BOM でログファイルに出力する関数
function Write-LogToFile {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	# ログディレクトリの作成
	$logDir = Split-Path $Path -Parent
	if (-not (Test-Path $logDir)) {
		New-Item -ItemType Directory -Path $logDir -Force | Out-Null
	}

	# UTF-8 with BOM でファイルに追記
	$utf8WithBom = New-Object System.Text.UTF8Encoding($true)
	$messageWithNewline = $Message + [Environment]::NewLine

	# ファイルが存在しない場合は新規作成、存在する場合は追記
	if (Test-Path $Path) {
		$fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
	}
 else {
		$fileStream = [System.IO.File]::Create($Path)
	}

	try {
		$bytes = $utf8WithBom.GetBytes($messageWithNewline)
		$fileStream.Write($bytes, 0, $bytes.Length)
	}
	finally {
		$fileStream.Close()
	}
}

# 設定ファイル読み込み
function Read-Configuration {
	param(
		[string]$ConfigPath,
		[string]$NotificationConfigPath
	)

	try {
		Write-Log "設定ファイルを読み込み中..."
		Write-Log "Workflow Config Path: $ConfigPath"
		Write-Log "Notification Config Path: $NotificationConfigPath"

		if (-not (Test-Path $ConfigPath)) {
			throw "ワークフロー設定ファイルが見つかりません: $ConfigPath"
		}

		if (-not (Test-Path $NotificationConfigPath)) {
			throw "通知設定ファイルが見つかりません: $NotificationConfigPath"
		}

		# ファイルの文字エンコーディングを確認
		Write-Log "設定ファイルの内容を確認中..."
		try {
			$workflowContent = Get-Content $ConfigPath -Raw -Encoding UTF8
			Write-Log "ワークフロー設定ファイルのサイズ: $($workflowContent.Length) 文字"

			# JSON形式の検証
			if (-not $workflowContent.Trim().StartsWith('{')) {
				throw "ワークフロー設定ファイルが正しいJSON形式ではありません"
			}

			# 全角文字の確認
			if ($workflowContent -match '[：，｛｝［］]') {
				Write-Log "警告: ワークフロー設定ファイルに全角文字が含まれている可能性があります" -Level "WARN"
			}

			$Global:WorkflowConfig = $workflowContent | ConvertFrom-Json
			Write-Log "ワークフロー設定ファイルの読み込みが完了しました"

		}
		catch {
			Write-Log "ワークフロー設定ファイルの読み込みでエラー: $($_.Exception.Message)" -Level "ERROR"

			# エラー位置の特定
			if ($_.Exception.Message -match '\((\d+)\)') {
				$errorPos = [int]$matches[1]
				Write-Log "エラー位置: $errorPos" -Level "ERROR"

				if ($errorPos -lt $workflowContent.Length) {
					$errorChar = $workflowContent[$errorPos - 1]
					$errorCharCode = [int][char]$errorChar
					Write-Log "エラー位置の文字: '$errorChar' (Unicode: $errorCharCode)" -Level "ERROR"

					$start = [Math]::Max(0, $errorPos - 50)
					$end = [Math]::Min($workflowContent.Length, $errorPos + 50)
					$errorContext = $workflowContent.Substring($start, $end - $start)
					Write-Log "エラー周辺の内容: $errorContext" -Level "ERROR"
				}
			}

			Write-Log "ファイル内容の最初の100文字: $($workflowContent.Substring(0, [Math]::Min(100, $workflowContent.Length)))" -Level "ERROR"
			Write-Log "診断ツールを実行してください: .\tools\Diagnose-JsonFiles.ps1" -Level "ERROR"
			throw
		}        try {
			$notificationContent = Get-Content $NotificationConfigPath -Raw -Encoding UTF8
			Write-Log "通知設定ファイルのサイズ: $($notificationContent.Length) 文字"

			# JSON形式の検証
			if (-not $notificationContent.Trim().StartsWith('{')) {
				throw "通知設定ファイルが正しいJSON形式ではありません"
			}

			# 全角文字の確認
			if ($notificationContent -match '[：，｛｝［］]') {
				Write-Log "警告: 通知設定ファイルに全角文字が含まれている可能性があります" -Level "WARN"
			}

			$Global:NotificationConfig = $notificationContent | ConvertFrom-Json
			# Dummy usage to suppress 'assigned but never used' warning
			$null = $Global:NotificationConfig
			Write-Log "通知設定ファイルの読み込みが完了しました"

		}
		catch {
			Write-Log "通知設定ファイルの読み込みでエラー: $($_.Exception.Message)" -Level "ERROR"

			# エラー位置の特定
			if ($_.Exception.Message -match '\((\d+)\)') {
				$errorPos = [int]$matches[1]
				Write-Log "エラー位置: $errorPos" -Level "ERROR"

				if ($errorPos -lt $notificationContent.Length) {
					$errorChar = $notificationContent[$errorPos - 1]
					$errorCharCode = [int][char]$errorChar
					Write-Log "エラー位置の文字: '$errorChar' (Unicode: $errorCharCode)" -Level "ERROR"

					$start = [Math]::Max(0, $errorPos - 50)
					$end = [Math]::Min($notificationContent.Length, $errorPos + 50)
					$errorContext = $notificationContent.Substring($start, $end - $start)
					Write-Log "エラー周辺の内容: $errorContext" -Level "ERROR"
				}
			}

			Write-Log "ファイル内容の最初の100文字: $($notificationContent.Substring(0, [Math]::Min(100, $notificationContent.Length)))" -Level "ERROR"
			Write-Log "診断ツールを実行してください: .\tools\Diagnose-JsonFiles.ps1" -Level "ERROR"
			throw
		}

		Write-Log "設定ファイルを正常に読み込みました"
		Write-Log "ワークフロー名: $($Global:WorkflowConfig.workflow.name)"
		Write-Log "ステップ数: $($Global:WorkflowConfig.workflow.steps.Count)"

	}
 catch {
		Write-Log "設定ファイルの読み込みに失敗しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# 通知送信
function Send-Notification {
	param(
		[Parameter(Mandatory = $true)]
		[string]$EventType,

		[hashtable]$Variables = @{}
	)

	try {
		if (-not $Global:NotificationConfig.notifications.enabled) {
			return
		}        $eventConfig = $Global:NotificationConfig.notifications.events.$EventType
		if (-not $eventConfig.enabled) {
			return
		}

		$message = $eventConfig.message

		# 変数の置換
		$Variables.machineName = $env:COMPUTERNAME
		$Variables.timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

		foreach ($key in $Variables.Keys) {
			$message = $message -replace "\{$key\}", $Variables[$key]
		}

		Write-Log "通知送信: $EventType - $message"

		# Slack通知
		if ($Global:NotificationConfig.notifications.providers.slack.enabled) {
			Send-SlackNotification -Message $message
		}

		# Teams通知
		if ($Global:NotificationConfig.notifications.providers.teams.enabled) {
			Send-TeamsNotification -Message $message
		}

	}
 catch {
		Write-Log "通知送信でエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
	}
}

# PCのシリアル番号を取得する関数
function Get-PCSerialNumber {
	try {
		$serialNumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
		if ([string]::IsNullOrWhiteSpace($serialNumber)) {
			# WMIで取得できない場合はCIMを試行
			$serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
		}

		if ([string]::IsNullOrWhiteSpace($serialNumber)) {
			Write-Log "PCシリアル番号を取得できませんでした。コンピューター名を使用します" -Level "WARN"
			return $env:COMPUTERNAME
		}

		# シリアル番号をクリーンアップ（空白と特殊文字を削除）
		$cleanSerialNumber = $serialNumber -replace '\s+', '' -replace '[^\w]', ''

		Write-Log "PCシリアル番号を取得しました: $cleanSerialNumber" -Level "DEBUG"
		return $cleanSerialNumber
	}
	catch {
		Write-Log "PCシリアル番号取得でエラー: $($_.Exception.Message)" -Level "WARN"
		return $env:COMPUTERNAME
	}
}

# Slackメッセージエンコード変換
function Convert-ToSlackMessageEncoding {
	param (
		[Parameter(Mandatory = $true)]
		[string]$InputText
	)
	$encode = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
	$utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($InputText)
	$convertedText = $encode.GetString($utf8Bytes)
	return $convertedText
}

# Slack通知送信
# Slack通知送信（chat.postMessage API使用）
function Send-SlackNotification {
	param([string]$Message)

	try {
		$slackConfig = $Global:NotificationConfig.notifications.providers.slack
		$threadConfig = $slackConfig.thread

		# Bot Tokenが設定されているかチェック
		if (-not $slackConfig.botToken -or $slackConfig.botToken -eq "xoxb-YOUR-BOT-TOKEN-HERE") {
			Write-Log "Slack Bot Tokenが設定されていません" -Level "WARN"
			return
		}

		# チャンネルが設定されているかチェック
		if (-not $slackConfig.channel) {
			Write-Log "Slackチャンネルが設定されていません" -Level "WARN"
			return
		}
		# ユーザー名の設定（perMachineが有効な場合はシリアル番号を追加）
		$username = $slackConfig.username
		if ($threadConfig -and $threadConfig.enabled -and $threadConfig.perMachine) {
			$serialNumber = Get-PCSerialNumber
			$username = "$($slackConfig.username)-$serialNumber"
			Write-Log "perMachine有効: ユーザー名にシリアル番号を追加しました: $username" -Level "DEBUG"
		}

		# スレッド機能が無効な場合は従来通り（Bot Token使用）
		if (-not $threadConfig -or -not $threadConfig.enabled) {
			$headers = @{
				"Authorization" = "Bearer $($slackConfig.botToken)"
				"Content-Type"  = "application/json"
			}

			$payload = @{
				channel    = $slackConfig.channel
				text       = $Message
				username   = $username
				icon_emoji = $slackConfig.iconEmoji
			}

			# 日本語文字化け対策
			$jsonPayload = $payload | ConvertTo-Json
			$convertedText = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

			$response = Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Method POST -Body $convertedText -Headers $headers

			if ($response.ok) {
				Write-Log "Slack通知を送信しました" -Level "DEBUG"
			}
			else {
				Write-Log "Slack通知送信でエラー: $($response.error)" -Level "WARN"
			}
			return
		}

		# スレッドTS管理ファイルのパス
		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path $PSScriptRoot $threadConfig.tsStoragePath
		}
		else {
			Join-Path $Global:StatusPath "slack_thread_ts.json"
  }

		$serialNumber = Get-PCSerialNumber

		# 既存のスレッドTSを確認
		$threadTs = $null
		if (Test-Path $threadTsFile) {
			try {
				$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json
				if ($threadConfig.perMachine -and $threadData.$serialNumber) {
					$threadTs = $threadData.$serialNumber
					Write-Log "既存のスレッドTS使用: $threadTs" -Level "DEBUG"
				}
				elseif (-not $threadConfig.perMachine -and $threadData.global) {
					$threadTs = $threadData.global
					Write-Log "既存のグローバルスレッドTS使用: $threadTs" -Level "DEBUG"
				}
			}
			catch {
				Write-Log "スレッドTSファイル読み込みエラー: $($_.Exception.Message)" -Level "WARN"
			}
		}

		# ヘッダー設定
		$headers = @{
			"Authorization" = "Bearer $($slackConfig.botToken)"
			"Content-Type"  = "application/json"
		}
		# Slackペイロード作成（chat.postMessage API用）
		$payload = @{
			channel    = $slackConfig.channel
			text       = $Message
			username   = $username
			icon_emoji = $slackConfig.iconEmoji
		}

		# スレッドTSが存在する場合は追加
		if ($threadTs) {
			$payload.thread_ts = $threadTs
		}

		# 日本語文字化け対策
		$jsonPayload = $payload | ConvertTo-Json
		$convertedText = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

		# Slack API呼び出し
		$response = Invoke-RestMethod -Uri "https://slack.com/api/chat.postMessage" -Method POST -Body $convertedText -Headers $headers

		# API応答の確認
		if (-not $response.ok) {
			Write-Log "Slack API エラー: $($response.error)" -Level "WARN"
			return
		}

		# 初回投稿の場合、レスポンスからtsを保存
		if (-not $threadTs -and $response.ts) {
			Write-Log "新しいスレッドTS保存: $($response.ts)" -Level "DEBUG"

			# スレッドTSファイルを作成/更新
			$threadData = @{}
			if (Test-Path $threadTsFile) {
				try {
					$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json -AsHashtable
				}
				catch {
					Write-Log "スレッドTSファイル解析エラー、新規作成します" -Level "WARN"
					$threadData = @{}
				}
			}			if ($threadConfig.perMachine) {
				$threadData[$serialNumber] = $response.ts
			}
			else {
				$threadData["global"] = $response.ts
			}

			# statusディレクトリが存在しない場合は作成
			$parentDir = Split-Path $threadTsFile -Parent
			if (-not (Test-Path $parentDir)) {
				New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
			}

			$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
		}
		Write-Log "Slack通知を送信しました$(if ($threadTs) { " (スレッド)" }) - ts: $($response.ts)" -Level "DEBUG"

	}
	catch {
		Write-Log "Slack通知送信でエラー: $($_.Exception.Message)" -Level "WARN"
	}
}

# スレッドTSクリア関数（テスト用）
function Clear-SlackThreadTs {
	param(
		[string]$SerialNumber,
		[switch]$All
	)

	try {
		# SerialNumberが指定されていない場合は現在のPCのシリアル番号を取得
		if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
			$SerialNumber = Get-PCSerialNumber
		}
		$threadConfig = $Global:NotificationConfig.notifications.providers.slack.thread
		if (-not $threadConfig -or -not $threadConfig.enabled) {
			Write-Log "スレッド機能が無効です" -Level "WARN"
			return
		}

		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path $PSScriptRoot $threadConfig.tsStoragePath
		}
		else {
			Join-Path $Global:StatusPath "slack_thread_ts.json"
		}

		if (Test-Path $threadTsFile) {
			if ($All) {
				Remove-Item $threadTsFile -Force
				Write-Log "全てのスレッドTSをクリアしました" -Level "INFO"
			}
			else {
				$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json -AsHashtable

				if ($threadConfig.perMachine -and $threadData.ContainsKey($SerialNumber)) {
					$threadData.Remove($SerialNumber)
					$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
					Write-Log "スレッドTS cleared for serial: $SerialNumber" -Level "INFO"
				}
				elseif (-not $threadConfig.perMachine -and $threadData.ContainsKey("global")) {
					$threadData.Remove("global")
					$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
					Write-Log "グローバルスレッドTSをクリアしました" -Level "INFO"
				}
				else {
					Write-Log "スレッドTS not found for serial: $SerialNumber" -Level "WARN"
				}
			}
		}
		else {
			Write-Log "スレッドTSファイルが見つかりません" -Level "WARN"
		}
	}
	catch {
		Write-Log "スレッドTSクリアでエラー: $($_.Exception.Message)" -Level "ERROR"
	}
}

# TeamsスレッドTSクリア関数（テスト用）
function Clear-TeamsThreadTs {
	param(
		[string]$SerialNumber,
		[switch]$All
	)

	try {
		# SerialNumberが指定されていない場合は現在のPCのシリアル番号を取得
		if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
			$SerialNumber = Get-PCSerialNumber
		}

		$threadConfig = $Global:NotificationConfig.notifications.providers.teams.thread
		if (-not $threadConfig -or -not $threadConfig.enabled) {
			Write-Log "Teamsスレッド機能が無効です" -Level "WARN"
			return
		}

		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path $PSScriptRoot $threadConfig.tsStoragePath
		}
		else {
			Join-Path $Global:StatusPath "teams_thread_ts.json"
		}

		if (Test-Path $threadTsFile) {
			if ($All) {
				Remove-Item $threadTsFile -Force
				Write-Log "全てのTeamsスレッドTSをクリアしました" -Level "INFO"
			}
			else {
				$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json -AsHashtable

				if ($threadConfig.perMachine -and $threadData.ContainsKey($SerialNumber)) {
					$threadData.Remove($SerialNumber)
					$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
					Write-Log "TeamsスレッドTS cleared for serial: $SerialNumber" -Level "INFO"
				}
				elseif (-not $threadConfig.perMachine -and $threadData.ContainsKey("global")) {
					$threadData.Remove("global")
					$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
					Write-Log "グローバルTeamsスレッドTSをクリアしました" -Level "INFO"
				}
				else {
					Write-Log "TeamsスレッドTS not found for serial: $SerialNumber" -Level "WARN"
				}
			}
		}
		else {
			Write-Log "TeamsスレッドTSファイルが見つかりません" -Level "WARN"
		}
	}
	catch {
		Write-Log "TeamsスレッドTSクリアでエラー: $($_.Exception.Message)" -Level "ERROR"
	}
}

# TeamsスレッドTS管理関数
function Get-TeamsThreadTs {
	param(
		[string]$SerialNumber
	)

	try {
		# SerialNumberが指定されていない場合は現在のPCのシリアル番号を取得
		if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
			$SerialNumber = Get-PCSerialNumber
		}

		$threadConfig = $Global:NotificationConfig.notifications.providers.teams.thread
		if (-not $threadConfig -or -not $threadConfig.enabled) {
			return $null
		}

		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path $PSScriptRoot $threadConfig.tsStoragePath
		}
		else {
			Join-Path $Global:StatusPath "teams_thread_ts.json"
		}

		if (Test-Path $threadTsFile) {
			$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json

			if ($threadConfig.perMachine -and $threadData.$SerialNumber) {
				return $threadData.$SerialNumber
			}
			elseif (-not $threadConfig.perMachine -and $threadData.global) {
				return $threadData.global
			}
		}

		return $null
	}
	catch {
		Write-Log "TeamsスレッドTS取得エラー: $($_.Exception.Message)" -Level "WARN"
		return $null
	}
}

# Teams通知送信（アダプティブカード使用）
function Send-TeamsNotification {
	param([string]$Message)

	try {
		$teamsConfig = $Global:NotificationConfig.notifications.providers.teams
		$threadConfig = $teamsConfig.thread

		# Flow URLが設定されているかチェック
		if (-not $teamsConfig.flowUrl -or $teamsConfig.flowUrl -eq "https://your-teams-flow-url-here") {
			Write-Log "Teams Flow URLが設定されていません" -Level "WARN"
			return
		}		# シリアル番号-PC名をプレフィックスとして追加
		$serialNumber = Get-PCSerialNumber
		$pcName = $env:COMPUTERNAME
		$prefixedMessage = "**[$serialNumber-$pcName]**`r`n`r`n$Message"

		# スレッド機能が無効な場合は従来通り
		if (-not $threadConfig -or -not $threadConfig.enabled) {
			# アダプティブカードコンテンツ作成
			$cardContent = @{
				'$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
				type      = 'AdaptiveCard'
				version   = '1.2'
				body      = @(
					@{
						type     = 'TextBlock'
						text     = $prefixedMessage
						wrap     = $true
						markdown = $true
						size     = 'Medium'
					}
				)
			}

			$attachments = @(
				@{
					contentType = "application/vnd.microsoft.card.adaptive"
					content     = $cardContent
				}
			)

			$payload = @{
				attachments = $attachments
			}

			# 日本語文字化け対策
			$jsonPayload = $payload | ConvertTo-Json -Depth 10 -Compress
			$convertedText = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

			Invoke-RestMethod -Uri $teamsConfig.flowUrl -Method POST -Body $convertedText -ContentType "application/json; charset=utf-8"
			Write-Log "Teams通知を送信しました (アダプティブカード)" -Level "DEBUG"
			return
		}

		# スレッドTS管理ファイルのパス（Teamsは独自のファイル）
		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path $PSScriptRoot $threadConfig.tsStoragePath
		}
		else {
			Join-Path $Global:StatusPath "teams_thread_ts.json"
		}

		$serialNumber = Get-PCSerialNumber

		# 既存のスレッドIDを確認
		$threadId = $null
		if (Test-Path $threadTsFile) {
			try {
				$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json
				if ($threadConfig.perMachine -and $threadData.$serialNumber) {
					$threadId = $threadData.$serialNumber
					Write-Log "既存のTeamsスレッドID使用: $threadId" -Level "DEBUG"
				}
				elseif (-not $threadConfig.perMachine -and $threadData.global) {
					$threadId = $threadData.global
					Write-Log "既存のグローバルTeamsスレッドID使用: $threadId" -Level "DEBUG"
				}
			}
			catch {
				Write-Log "TeamsスレッドTSファイル読み込みエラー: $($_.Exception.Message)" -Level "WARN"
			}
		}

		# スレッドIDが存在しない場合は新規作成
		if (-not $threadId) {
			$threadId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
			Write-Log "新しいTeamsスレッドID生成: $threadId" -Level "DEBUG"

			# スレッドIDを保存
			$threadData = @{}
			if (Test-Path $threadTsFile) {
				try {
					$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json -AsHashtable
				}
				catch {
					Write-Log "TeamsスレッドTSファイル解析エラー、新規作成します" -Level "WARN"
					$threadData = @{}
				}
			}

			if ($threadConfig.perMachine) {
				$threadData[$serialNumber] = $threadId
			}
			else {
				$threadData["global"] = $threadId
			}

			# statusディレクトリが存在しない場合は作成
			$parentDir = Split-Path $threadTsFile -Parent
			if (-not (Test-Path $parentDir)) {
				New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
			}

			$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
		}

		# アダプティブカードコンテンツ作成（スレッド対応）
		$cardContent = @{
			'$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
			type      = 'AdaptiveCard'
			version   = '1.2'
			body      = @(
				@{
					type     = 'TextBlock'
					text     = $prefixedMessage
					wrap     = $true
					markdown = $true
					size     = 'Medium'
				}
			)
		}

		$attachments = @(
			@{
				contentType = "application/vnd.microsoft.card.adaptive"
				content     = $cardContent
			}
		)

		# ペイロード作成（スレッドID付き）
		$payload = @{
			attachments = $attachments
			threadId    = $threadId
		}

		# 日本語文字化け対策
		$jsonPayload = $payload | ConvertTo-Json -Depth 10 -Compress
		$convertedText = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

		# Teams Flow呼び出し
		Invoke-RestMethod -Uri $teamsConfig.flowUrl -Method POST -Body $convertedText -ContentType "application/json; charset=utf-8"

		Write-Log "Teams通知を送信しました (アダプティブカード, スレッドID: $threadId)" -Level "DEBUG"

	}
	catch {
		Write-Log "Teams通知送信でエラー: $($_.Exception.Message)" -Level "WARN"
	}
}

# BIOSパスワード解除確認ダイアログ（初回のみ）
function Show-BIOSPasswordDialog {
	Write-Log "BIOSパスワード解除確認を開始中..."

	# ステータスファイルのパス
	$statusFile = Join-Path $Global:StatusPath "bios-password-confirmed.completed"

	# 既に確認済みの場合はスキップ
	if (Test-Path $statusFile) {
		Write-Log "BIOSパスワード解除は既に確認済みです。ダイアログをスキップします。"
		return $true
	}

	Write-Log "初回実行のため、BIOSパスワード解除確認ダイアログを表示します。"

	# Windows Formsアセンブリの読み込み
	Add-Type -AssemblyName System.Windows.Forms

	# メッセージボックスで確認
	$message = @"
このPCのBIOSパスワードは既に解除済みですか？

セットアップを開始する前に、以下を確認してください：
・BIOSパスワードが設定されていないこと
・セキュアブートの設定が適切に行われていること
・TPMの設定が正しく構成されていること

準備が完了している場合は「はい」を、
まだ準備ができていない場合は「いいえ」を選択してください。
"@

	# シンプルなメッセージボックスを表示
	$result = [System.Windows.Forms.MessageBox]::Show(
		$message,
		"Windows Kitting Workflow - 初回実行確認",
		[System.Windows.Forms.MessageBoxButtons]::YesNo,
		[System.Windows.Forms.MessageBoxIcon]::Question,
		[System.Windows.Forms.MessageBoxDefaultButton]::Button2
	)

	if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
		Write-Log "ユーザーがBIOSパスワード解除を確認しました。ワークフローを続行します。"

		# 確認済みステータスファイルを作成
		try {
			$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
			$statusContent = @"
BIOS Password Confirmation Completed
=====================================
Confirmed Date: $timestamp
Computer Name: $env:COMPUTERNAME
User: $env:USERNAME
Status: Confirmed by user dialog
"@
			[System.IO.File]::WriteAllText($statusFile, $statusContent, [System.Text.Encoding]::UTF8)
			Write-Log "BIOSパスワード確認完了ステータスファイルを作成しました: $statusFile"
		}
		catch {
			Write-Log "ステータスファイルの作成に失敗しました: $($_.Exception.Message)" -Level "WARN"
		}

		return $true
	}
	else {
		Write-Log "ユーザーがセットアップのキャンセルを選択しました。プログラムを終了します。"
		return $false
	}
}

# 完了チェック
function Test-StepCompletion {
	param(
		[object]$Step
	)

	$completionCheck = $Step.completionCheck

	switch ($completionCheck.type) {
		"file" {
			$filePath = Join-Path $PSScriptRoot $completionCheck.path
			return Test-Path $filePath
		}
		"registry" {
			try {
				return $null -ne (Get-ItemProperty -Path $completionCheck.path -ErrorAction SilentlyContinue)
			}
			catch {
				return $false
			}
		}
		"service" {
			try {
				$service = Get-Service -Name $completionCheck.serviceName -ErrorAction SilentlyContinue
				return $service -and $service.Status -eq "Running"
			}
			catch {
				return $false
			}
		}
		default {
			Write-Log "不明な完了チェックタイプ: $($completionCheck.type)" -Level "WARN"
			return $false
		}
	}
}

# ステップ実行
function Invoke-WorkflowStep {
	param(
		[object]$Step
	)

	Write-Log "ステップ開始: $($Step.name)"

	# 完了チェック
	if (Test-StepCompletion -Step $Step) {
		Write-Log "ステップは既に完了しています: $($Step.name)"
		return $true
	}

	# 通知送信
	Send-Notification -EventType "onStepStart" -Variables @{
		stepName = $Step.name
		stepId   = $Step.id
	}

	$retryCount = 0
	$maxRetries = if ($Step.retryCount) { $Step.retryCount } else { $Global:WorkflowConfig.workflow.settings.maxRetries }
	do {
		try {
			# internalタイプの処理
			if ($Step.type -eq "internal") {
				Write-Log "内部関数を実行: $($Step.internal.function)"

				# 関数名を取得して実行
				$functionName = $Step.internal.function
				if (Get-Command $functionName -ErrorAction SilentlyContinue) {
					$result = & $functionName
					if ($result) {
						$exitCode = 0
					}
					else {
						throw "内部関数が false を返しました"
					}
				}
				else {
					throw "内部関数が見つかりません: $functionName"
				}
			}
			else {
				# 通常のスクリプト実行
				$scriptPath = Join-Path $PSScriptRoot $Step.script

				if (-not (Test-Path $scriptPath)) {
					throw "スクリプトファイルが見つかりません: $scriptPath"
				}

				Write-Log "スクリプト実行: $scriptPath"

				if ($DryRun) {
					Write-Log "[DRY RUN] スクリプトを実行します: $scriptPath"
					Start-Sleep -Seconds 2
					$exitCode = 0
				}
				else {
					# $Step.parameters がオブジェクトの場合はハッシュテーブル化
					if ($Step.parameters -and $Step.parameters.PSObject.Properties.Count -gt 0) {
						$parameters = @{}
						foreach ($prop in $Step.parameters.PSObject.Properties) {
							$parameters[$prop.Name] = $prop.Value
						}
					}
					else {
						$parameters = @()
					}

					if ($Step.type -eq "powershell") {
						& $scriptPath @parameters
						$exitCode = $LASTEXITCODE
					}
					else {
						& cmd /c $scriptPath @parameters
						$exitCode = $LASTEXITCODE
					}
				}
			}

			if ($exitCode -eq 0) {
				# 完了マーカー作成
				$completionMarker = Join-Path $PSScriptRoot $Step.completionCheck.path
				$completionDir = Split-Path $completionMarker -Parent
				if (-not (Test-Path $completionDir)) {
					New-Item -ItemType Directory -Path $completionDir -Force | Out-Null
				}

				if (-not $DryRun) {
					@{
						stepId      = $Step.id
						stepName    = $Step.name
						completedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
						exitCode    = $exitCode
					} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8
				}

				Write-Log "ステップが正常に完了しました: $($Step.name)"

				# 通知送信
				Send-Notification -EventType "onStepComplete" -Variables @{
					stepName = $Step.name
					stepId   = $Step.id
				}

				# 再起動が必要な場合
				if ($Step.rebootRequired -and -not $DryRun) {
					Write-Log "再起動が必要です。30秒後に再起動します..."

					Send-Notification -EventType "onRebootRequired" -Variables @{
						stepName = $Step.name
						stepId   = $Step.id
					}

					Start-Sleep -Seconds 30
					Restart-Computer -Force
				}

				return $true
			}
			else {
				throw "スクリプトがエラーコード $exitCode で終了しました"
			}

		}
		catch {
			$retryCount++
			$errorMessage = $_.Exception.Message

			Write-Log "ステップでエラーが発生しました: $($Step.name) - $errorMessage" -Level "ERROR"

			Send-Notification -EventType "onStepError" -Variables @{
				stepName     = $Step.name
				stepId       = $Step.id
				errorMessage = $errorMessage
				retryCount   = $retryCount
			}

			if ($retryCount -le $maxRetries -and $Step.onError -eq "retry") {
				Write-Log "ステップを再試行します: $($Step.name) (試行回数: $retryCount)" -Level "WARN"

				Send-Notification -EventType "onStepRetry" -Variables @{
					stepName   = $Step.name
					stepId     = $Step.id
					retryCount = $retryCount
				}

				Start-Sleep -Seconds $Global:WorkflowConfig.workflow.settings.retryDelay
			}
			else {
				if ($Step.onError -eq "stop") {
					throw "ステップが失敗しました。ワークフローを停止します: $($Step.name)"
				}
				else {
					Write-Log "ステップが失敗しましたが、続行します: $($Step.name)" -Level "WARN"
					return $false
				}
			}
		}
	} while ($retryCount -le $maxRetries)

	return $false
}

# 依存関係チェック
function Test-StepDependencies {
	param(
		[object]$Step,
		[array]$CompletedSteps
	)

	if (-not $Step.dependsOn -or $Step.dependsOn.Count -eq 0) {
		return $true
	}

	foreach ($dependency in $Step.dependsOn) {
		if ($dependency -notin $CompletedSteps) {
			return $false
		}
	}

	return $true
}

# ワークフローステップリストを生成する関数
function Get-WorkflowStepsMessage {
	try {
		if (-not $Global:WorkflowConfig -or -not $Global:WorkflowConfig.workflow.steps) {
			return "• ワークフロー設定が読み込まれていません"
		}

		$steps = $Global:WorkflowConfig.workflow.steps
		$stepsList = @()

		foreach ($step in $steps) {
			$stepName = $step.name
			$additionalInfo = @()

			# 再起動が必要な場合の表示
			if ($step.rebootRequired -eq $true) {
				$additionalInfo += "再起動あり"
			}

			# 初回のみ実行される項目の表示
			if ($step.id -eq "bios-password-confirmation") {
				$additionalInfo += "初回のみ"
			}

			# エラー時の動作を表示
			if ($step.onError -eq "continue") {
				$additionalInfo += "エラー時継続"
			}

			# 追加情報がある場合は括弧内に表示
			if ($additionalInfo.Count -gt 0) {
				$stepName += "（" + ($additionalInfo -join "、") + "）"
			}

			$stepsList += "- $stepName"
		}

		return $stepsList -join "`n"
	}
	catch {
		Write-Log "ワークフローステップメッセージ生成でエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
		return "- ワークフローステップの取得に失敗しました"
	}
}

# メインワークフロー実行
function Start-MainWorkflow {
	try {
		Write-Log "Windows Kitting Workflow開始"
		Write-Log "コンピューター名: $env:COMPUTERNAME"
		Write-Log "開始時刻: $($Global:WorkflowStartTime)"

		# 初回起動かどうかを判定
		$workflowStartStatusFile = Join-Path $Global:StatusPath "workflow-started.completed"
		$isFirstRun = -not (Test-Path $workflowStartStatusFile)

		# 初回起動時のみ開始通知を送信
		if ($isFirstRun) {
			$workflowSteps = Get-WorkflowStepsMessage
			Send-Notification -EventType "onWorkflowStart" -Variables @{
				workflowSteps = $workflowSteps
			}

			# ワークフロー開始ステータスファイルを作成
			try {
				if (-not (Test-Path $Global:StatusPath)) {
					New-Item -ItemType Directory -Path $Global:StatusPath -Force | Out-Null
				}
				$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
				$statusContent = @"
Workflow Start Notification Sent
=================================
First Run Date: $timestamp
Computer Name: $env:COMPUTERNAME
User: $env:USERNAME
Status: Initial workflow start notification sent
"@
				[System.IO.File]::WriteAllText($workflowStartStatusFile, $statusContent, [System.Text.Encoding]::UTF8)
				Write-Log "ワークフロー開始通知ステータスファイルを作成しました: $workflowStartStatusFile"
			}
			catch {
				Write-Log "ワークフロー開始ステータスファイルの作成に失敗しました: $($_.Exception.Message)" -Level "WARN"
			}
		}
		else {
			Write-Log "再起動後の継続実行のため、開始通知をスキップします。"
		}

		$steps = $Global:WorkflowConfig.workflow.steps
		$completedSteps = @()
		$failedSteps = @()
		$totalSteps = $steps.Count

		# ステップ実行ループ
		while ($completedSteps.Count + $failedSteps.Count -lt $totalSteps) {
			$executed = $false

			foreach ($step in $steps) {
				if ($step.id -in $completedSteps -or $step.id -in $failedSteps) {
					continue
				}

				if (Test-StepDependencies -Step $step -CompletedSteps $completedSteps) {
					$success = Invoke-WorkflowStep -Step $step

					if ($success) {
						$completedSteps += $step.id
					}
					else {
						$failedSteps += $step.id
					}

					$executed = $true
					break
				}
			}

			if (-not $executed) {
				Write-Log "実行可能なステップがありません。依存関係を確認してください。" -Level "ERROR"
				break
			}
		}
		# 完了通知
		$duration = New-TimeSpan -Start $Global:WorkflowStartTime -End (Get-Date)

		Send-Notification -EventType "onWorkflowComplete" -Variables @{
			duration       = $duration.ToString()
			completedSteps = $completedSteps.Count
			totalSteps     = $totalSteps
			failedSteps    = $failedSteps.Count
			success        = if ($failedSteps.Count -eq 0) { "true" } else { "false" }
		}
		Write-Log "ワークフロー完了"
		Write-Log "完了ステップ: $($completedSteps.Count)/$totalSteps"
		Write-Log "実行時間: $($duration.ToString())"

		# すべての工程が完了した場合の処理
		if ($failedSteps.Count -eq 0) {
			Write-Log "すべてのステップが正常に完了しました" -Level "INFO"

			# 主要なログファイルをメモ帳で開く
			try {
				Write-Log "ログファイルを開いています..."

				# 開くログファイルのリスト
				$logFilesToOpen = @(
					$Global:LogPath,
					$Global:ErrorLogPath
				)

				# スクリプトログディレクトリから主要なログファイルを追加
				$scriptsLogDir = Join-Path $PSScriptRoot "logs\scripts"
				if (Test-Path $scriptsLogDir) {
					$scriptLogs = Get-ChildItem -Path $scriptsLogDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
					foreach ($log in $scriptLogs) {
						$logFilesToOpen += $log.FullName
					}
				}

				# 存在するログファイルのみを開く
				foreach ($logFile in $logFilesToOpen) {
					if (Test-Path $logFile) {
						Write-Log "ログファイルを開いています: $logFile"
						Start-Process -FilePath "notepad.exe" -ArgumentList "`"$logFile`"" -WindowStyle Normal
						Start-Sleep -Milliseconds 500  # 複数ファイルを開く際の間隔
					}
				}
			}
			catch {
				Write-Log "ログファイルを開く際にエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
			}
		}

		if ($failedSteps.Count -gt 0) {
			Write-Log "失敗したステップ: $($failedSteps -join ', ')" -Level "WARN"
			return 1
		}

		return 0

	}
 catch {
		$errorMessage = $_.Exception.Message
		Write-Log "ワークフローでエラーが発生しました: $errorMessage" -Level "ERROR"

		Send-Notification -EventType "onWorkflowError" -Variables @{
			errorMessage = $errorMessage
			logPath      = $Global:LogPath
		}

		return 1
	}
}

# メイン処理
try {
	# ログディレクトリ作成
	$logsDir = Join-Path $PSScriptRoot "logs"
	$statusDir = Join-Path $PSScriptRoot "status"
	$scriptsLogDir = Join-Path $logsDir "scripts"

	@($logsDir, $statusDir, $scriptsLogDir) | ForEach-Object {
		if (-not (Test-Path $_)) {
			New-Item -ItemType Directory -Path $_ -Force | Out-Null
		}
	}	# 設定読み込み
	Read-Configuration -ConfigPath $ConfigPath -NotificationConfigPath $NotificationConfigPath

	# ワークフロー実行
	$exitCode = Start-MainWorkflow
	# 結果の表示とユーザー確認
	Write-Host ""
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Windows Kitting Workflow 実行結果" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan

	$duration = New-TimeSpan -Start $Global:WorkflowStartTime -End (Get-Date)

	if ($exitCode -eq 0) {
		Write-Host "✓ ワークフローが正常に完了しました" -ForegroundColor Green
		Write-Host "  すべてのセットアップが完了しました。" -ForegroundColor Green
		Write-Host "  ログファイルが自動的に開かれました。" -ForegroundColor Green

		# 成功時の通知送信
		Send-Notification -EventType "onWorkflowSuccess" -Variables @{
			duration     = $duration.ToString()
			logPath      = $Global:LogPath
			computerName = $env:COMPUTERNAME
		}
	}
	else {
		Write-Host "✗ ワークフローがエラーで終了しました" -ForegroundColor Red
		Write-Host "  詳細はログファイルを確認してください。" -ForegroundColor Yellow

		# 失敗時の通知送信
		Send-Notification -EventType "onWorkflowFailure" -Variables @{
			duration     = $duration.ToString()
			logPath      = $Global:LogPath
			errorLogPath = $Global:ErrorLogPath
			computerName = $env:COMPUTERNAME
		}
	}
	Write-Host ""
	Write-Host "実行時間: $($duration.ToString())" -ForegroundColor White
	Write-Host "ログファイル: $Global:LogPath" -ForegroundColor White

	if ($exitCode -ne 0) {
		Write-Host "エラーログ: $Global:ErrorLogPath" -ForegroundColor Yellow
	}

	Write-Host ""
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "任意のキーを押してコンソールを閉じてください..." -ForegroundColor Yellow
	Write-Host "========================================" -ForegroundColor Cyan

	# ユーザーの入力を待つ
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

	exit $exitCode

}
catch {
	Write-Log "致命的なエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"

	# 致命的エラー時の通知送信
	Send-Notification -EventType "onWorkflowCriticalError" -Variables @{
		errorMessage = $_.Exception.Message
		logPath      = $Global:LogPath
		errorLogPath = $Global:ErrorLogPath
		computerName = $env:COMPUTERNAME
		duration     = if ($Global:WorkflowStartTime) { (New-TimeSpan -Start $Global:WorkflowStartTime -End (Get-Date)).ToString() } else { "計測不可" }
	}

	# エラー時の表示
	Write-Host ""
	Write-Host "========================================" -ForegroundColor Red
	Write-Host "致命的なエラーが発生しました" -ForegroundColor Red
	Write-Host "========================================" -ForegroundColor Red
	Write-Host "エラー: $($_.Exception.Message)" -ForegroundColor Yellow
	Write-Host "ログファイル: $Global:LogPath" -ForegroundColor White
	Write-Host "エラーログ: $Global:ErrorLogPath" -ForegroundColor White
	Write-Host ""
	Write-Host "========================================" -ForegroundColor Red
	Write-Host "任意のキーを押してコンソールを閉じてください..." -ForegroundColor Yellow
	Write-Host "========================================" -ForegroundColor Red

	# ユーザーの入力を待つ
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

	exit 1
}
