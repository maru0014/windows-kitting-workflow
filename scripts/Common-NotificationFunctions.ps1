# ============================================================================
# 共通通知機能ライブラリ
# Slack、Teams通知の統合機能
# ============================================================================

# グローバル変数（通知設定用）
$Global:NotificationConfig = $null

# 通知設定読み込み
function Import-NotificationConfig {
	param(
		[string]$ConfigPath
	)

	try {
		if (-not $ConfigPath) {
			# デフォルトパスを設定
			$ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\notifications.json"
		}

		if (-not (Test-Path $ConfigPath)) {
			Write-Warning "通知設定ファイルが見つかりません: $ConfigPath"
			return $false
		}

		$configContent = Get-Content $ConfigPath -Raw -Encoding UTF8
		$Global:NotificationConfig = $configContent | ConvertFrom-Json

		Write-Verbose "通知設定ファイルを読み込みました: $ConfigPath"
		return $true
	}
	catch {
		Write-Warning "通知設定ファイルの読み込みに失敗しました: $($_.Exception.Message)"
		return $false
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
			Write-Warning "PCシリアル番号を取得できませんでした。コンピューター名を使用します"
			return $env:COMPUTERNAME
		}

		# シリアル番号をクリーンアップ（空白と特殊文字を削除）
		$cleanSerialNumber = $serialNumber -replace '\s+', '' -replace '[^\w]', ''

		Write-Verbose "PCシリアル番号を取得しました: $cleanSerialNumber"
		return $cleanSerialNumber
	}
	catch {
		Write-Warning "PCシリアル番号取得でエラー: $($_.Exception.Message)"
		return $env:COMPUTERNAME
	}
}

# Slack通知送信（chat.postMessage API使用）
function Send-SlackNotification {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	try {
		if (-not $Global:NotificationConfig) {
			Write-Warning "通知設定が読み込まれていません"
			return $false
		}

		$slackConfig = $Global:NotificationConfig.notifications.providers.slack
		if (-not $slackConfig.enabled) {
			Write-Verbose "Slack通知が無効になっています"
			return $true
		}

		$threadConfig = $slackConfig.thread

		# Bot Tokenが設定されているかチェック
		if (-not $slackConfig.botToken -or $slackConfig.botToken -eq "xoxb-YOUR-BOT-TOKEN-HERE") {
			Write-Warning "Slack Bot Tokenが設定されていません"
			return $false
		}

		# チャンネルが設定されているかチェック
		if (-not $slackConfig.channel) {
			Write-Warning "Slackチャンネルが設定されていません"
			return $false
		}

		# ユーザー名の設定（perMachineが有効な場合はシリアル番号を追加）
		$username = $slackConfig.username
		if ($threadConfig -and $threadConfig.enabled -and $threadConfig.perMachine) {
			$serialNumber = Get-PCSerialNumber
			$username = "$($slackConfig.username)-$serialNumber"
			Write-Verbose "perMachine有効: ユーザー名にシリアル番号を追加しました: $username"
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
				Write-Verbose "Slack通知を送信しました"
				return $true
			}
			else {
				Write-Warning "Slack通知送信でエラー: $($response.error)"
				return $false
			}
		}

		# スレッドTS管理ファイルのパス
		$statusPath = Join-Path (Split-Path $PSScriptRoot -Parent) "status"
		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path (Split-Path $PSScriptRoot -Parent) $threadConfig.tsStoragePath
		}
		else {
			Join-Path $statusPath "slack_thread_ts.json"
		}

		$serialNumber = Get-PCSerialNumber

		# 既存のスレッドTSを確認
		$threadTs = $null
		if (Test-Path $threadTsFile) {
			try {
				$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json
				if ($threadConfig.perMachine -and $threadData.$serialNumber) {
					$threadTs = $threadData.$serialNumber
					Write-Verbose "既存のスレッドTS取得 (perMachine): $threadTs"
				}
				elseif (-not $threadConfig.perMachine -and $threadData.global) {
					$threadTs = $threadData.global
					Write-Verbose "既存のスレッドTS取得 (global): $threadTs"
				}
			}
			catch {
				Write-Warning "スレッドTSファイル読み込みエラー: $($_.Exception.Message)"
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
			Write-Warning "Slack API エラー: $($response.error)"
			return $false
		}

		# 初回投稿の場合、レスポンスからtsを保存
		if (-not $threadTs -and $response.ts) {
			Write-Verbose "新しいスレッドTS保存: $($response.ts)"

			# スレッドTSファイルを作成/更新
			$threadData = @{}
			if (Test-Path $threadTsFile) {
				try {
					$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json
				}
				catch {
					Write-Warning "既存スレッドTSファイル読み込みエラー: $($_.Exception.Message)"
					$threadData = @{}
				}
			}

			if ($threadConfig.perMachine) {
				$threadData | Add-Member -NotePropertyName $serialNumber -NotePropertyValue $response.ts -Force
			}
			else {
				$threadData | Add-Member -NotePropertyName "global" -NotePropertyValue $response.ts -Force
			}

			# statusディレクトリが存在しない場合は作成
			$parentDir = Split-Path $threadTsFile -Parent
			if (-not (Test-Path $parentDir)) {
				New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
			}

			$threadData | ConvertTo-Json | Out-File -FilePath $threadTsFile -Encoding UTF8
		}

		Write-Verbose "Slack通知を送信しました$(if ($threadTs) { " (スレッド)" }) - ts: $($response.ts)"
		return $true

	}
	catch {
		Write-Warning "Slack通知送信でエラー: $($_.Exception.Message)"
		return $false
	}
}

# Teams通知送信（アダプティブカード使用）
function Send-TeamsNotification {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message
	)

	try {
		if (-not $Global:NotificationConfig) {
			Write-Warning "通知設定が読み込まれていません"
			return $false
		}

		$teamsConfig = $Global:NotificationConfig.notifications.providers.teams
		if (-not $teamsConfig.enabled) {
			Write-Verbose "Teams通知が無効になっています"
			return $true
		}

		$threadConfig = $teamsConfig.thread

		# Flow URLが設定されているかチェック
		if (-not $teamsConfig.flowUrl -or $teamsConfig.flowUrl -eq "https://your-teams-flow-url-here") {
			Write-Warning "Teams Flow URLが設定されていません"
			return $false
		}

		# シリアル番号-PC名をプレフィックスとして追加
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
						type = 'TextBlock'
						text = $prefixedMessage
						wrap = $true
						size = 'Medium'
					}
				)
			}

			$attachments = @(
				@{
					contentType = 'application/vnd.microsoft.card.adaptive'
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
			Write-Verbose "Teams通知を送信しました (アダプティブカード)"
			return $true
		}

		# スレッドTS管理ファイルのパス（Teamsは独自のファイル）
		$statusPath = Join-Path (Split-Path $PSScriptRoot -Parent) "status"
		$threadTsFile = if ($threadConfig.tsStoragePath) {
			Join-Path (Split-Path $PSScriptRoot -Parent) $threadConfig.tsStoragePath
		}
		else {
			Join-Path $statusPath "teams_thread_ts.json"
		}

		# 既存のスレッドIDを確認
		$threadId = $null
		if (Test-Path $threadTsFile) {
			try {
				$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json
				if ($threadConfig.perMachine -and $threadData.$serialNumber) {
					$threadId = $threadData.$serialNumber
					Write-Verbose "既存のTeamsスレッドID取得 (perMachine): $threadId"
				}
				elseif (-not $threadConfig.perMachine -and $threadData.global) {
					$threadId = $threadData.global
					Write-Verbose "既存のTeamsスレッドID取得 (global): $threadId"
				}
			}
			catch {
				Write-Warning "TeamsスレッドTSファイル読み込みエラー: $($_.Exception.Message)"
			}
		}

		# スレッドIDが存在しない場合は新規作成
		if (-not $threadId) {
			$threadId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
			Write-Verbose "新しいTeamsスレッドID生成: $threadId"

			# スレッドIDを保存
			$threadData = @{}
			if (Test-Path $threadTsFile) {
				try {
					$threadData = Get-Content $threadTsFile -Raw | ConvertFrom-Json
				}
				catch {
					Write-Warning "既存TeamsスレッドTSファイル読み込みエラー: $($_.Exception.Message)"
					$threadData = @{}
				}
			}

			if ($threadConfig.perMachine) {
				$threadData | Add-Member -NotePropertyName $serialNumber -NotePropertyValue $threadId -Force
			}
			else {
				$threadData | Add-Member -NotePropertyName "global" -NotePropertyValue $threadId -Force
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
					type = 'TextBlock'
					text = $prefixedMessage
					wrap = $true
					size = 'Medium'
				}
			)
		}

		$attachments = @(
			@{
				contentType = 'application/vnd.microsoft.card.adaptive'
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

		Write-Verbose "Teams通知を送信しました (アダプティブカード, スレッドID: $threadId)"
		return $true

	}
	catch {
		Write-Warning "Teams通知送信でエラー: $($_.Exception.Message)"
		return $false
	}
}

# 統合通知送信関数
function Send-Notification {
	param(
		[Parameter(Mandatory = $true)]
		[string]$EventType,

		[hashtable]$Variables = @{},

		[string]$CustomMessage = ""
	)

	try {
		if (-not $Global:NotificationConfig) {
			Write-Warning "通知設定が読み込まれていません"
			return $false
		}

		if (-not $Global:NotificationConfig.notifications.enabled) {
			Write-Verbose "通知機能が無効になっています"
			return $true
		}

		# カスタムメッセージが指定されている場合はそれを使用
		if ($CustomMessage) {
			$message = $CustomMessage
		}
		else {
			# イベント設定からメッセージを取得
			$eventConfig = $Global:NotificationConfig.notifications.events.$EventType
			if (-not $eventConfig -or -not $eventConfig.enabled) {
				Write-Verbose "イベント '$EventType' が無効または未定義です"
				return $true
			}

			$message = $eventConfig.message
		}

		# 変数の置換
		$Variables.machineName = $env:COMPUTERNAME
		$Variables.timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

		foreach ($key in $Variables.Keys) {
			$message = $message -replace "\{$key\}", $Variables[$key]
		}

		Write-Verbose "通知送信: $EventType - $message"

		$results = @()

		# Slack通知
		if ($Global:NotificationConfig.notifications.providers.slack.enabled) {
			$slackResult = Send-SlackNotification -Message $message
			$results += $slackResult
		}

		# Teams通知
		if ($Global:NotificationConfig.notifications.providers.teams.enabled) {
			$teamsResult = Send-TeamsNotification -Message $message
			$results += $teamsResult
		}

		# 少なくとも一つの通知が成功した場合は成功とする
		return ($results -contains $true)

	}
	catch {
		Write-Warning "通知送信でエラーが発生しました: $($_.Exception.Message)"
		return $false
	}
}

# スレッドTSクリア関数（テスト用）
function Clear-NotificationThreads {
	param(
		[string]$SerialNumber,
		[switch]$All,
		[ValidateSet("Slack", "Teams", "Both")]
		[string]$Provider = "Both"
	)

	try {
		# SerialNumberが指定されていない場合は現在のPCのシリアル番号を取得
		if ([string]::IsNullOrWhiteSpace($SerialNumber)) {
			$SerialNumber = Get-PCSerialNumber
		}

		$statusPath = Join-Path (Split-Path $PSScriptRoot -Parent) "status"

		if ($Provider -eq "Slack" -or $Provider -eq "Both") {
			$slackThreadFile = Join-Path $statusPath "slack_thread_ts.json"
			if (Test-Path $slackThreadFile) {
				if ($All) {
					Remove-Item $slackThreadFile -Force
					Write-Verbose "Slackスレッドファイルを全削除しました"
				}
				else {
					$threadData = Get-Content $slackThreadFile -Raw | ConvertFrom-Json
					$threadData.PSObject.Properties.Remove($SerialNumber)
					$threadData | ConvertTo-Json | Out-File -FilePath $slackThreadFile -Encoding UTF8
					Write-Verbose "Slackスレッド '$SerialNumber' をクリアしました"
				}
			}
		}

		if ($Provider -eq "Teams" -or $Provider -eq "Both") {
			$teamsThreadFile = Join-Path $statusPath "teams_thread_ts.json"
			if (Test-Path $teamsThreadFile) {
				if ($All) {
					Remove-Item $teamsThreadFile -Force
					Write-Verbose "Teamsスレッドファイルを全削除しました"
				}
				else {
					$threadData = Get-Content $teamsThreadFile -Raw | ConvertFrom-Json
					$threadData.PSObject.Properties.Remove($SerialNumber)
					$threadData | ConvertTo-Json | Out-File -FilePath $teamsThreadFile -Encoding UTF8
					Write-Verbose "Teamsスレッド '$SerialNumber' をクリアしました"
				}
			}
		}

		return $true
	}
	catch {
		Write-Warning "スレッドクリアでエラー: $($_.Exception.Message)"
		return $false
	}
}
