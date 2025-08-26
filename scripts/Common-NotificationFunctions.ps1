﻿# ============================================================================
# 共通通知機能ライブラリ
# Slack、Teams通知の統合機能
# ============================================================================

# グローバル変数（通知設定用）
$Global:NotificationConfig = $null

# TTS用シンセサイザー（初期化済みを再利用）
$script:SpeechSynthesizer = $null
$script:SpeechSynthesizerEngine = $null  # "SystemSpeech" or "SAPI"

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

# TTS 初期化
function Initialize-TTSSynthesizer {
	param(
		[PSCustomObject]$TtsConfig
	)

	try {
		# 1) まず System.Speech を試行（Windows PowerShell 5.1 互換 / 一部の pwsh でも利用可）
		try {
			Add-Type -AssemblyName System.Speech -ErrorAction Stop
			$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

			if ($null -ne $TtsConfig.rate) { $synth.Rate = [int]$TtsConfig.rate }
			if ($null -ne $TtsConfig.volume) { $synth.Volume = [int]$TtsConfig.volume }

			# 音声選択: voiceName > preferJapanese
			if ($TtsConfig.voiceName) {
				try { $synth.SelectVoice($TtsConfig.voiceName) } catch { }
			}
			elseif ($TtsConfig.preferJapanese -eq $true) {
				$ja = $synth.GetInstalledVoices() |
				Where-Object { $_.VoiceInfo.Culture.Name -like 'ja-*' } |
				Select-Object -First 1
				if ($ja) { $synth.SelectVoice($ja.VoiceInfo.Name) }
			}

			$script:SpeechSynthesizer = $synth
			$script:SpeechSynthesizerEngine = "SystemSpeech"
			return $true
		}
		catch {
			# 2) 代替として COM SAPI.SpVoice（PowerShell 7 でも安定）
			$synth = New-Object -ComObject SAPI.SpVoice

			if ($null -ne $TtsConfig.rate) { $synth.Rate = [int]$TtsConfig.rate }
			if ($null -ne $TtsConfig.volume) { $synth.Volume = [int]$TtsConfig.volume }

			# 音声選択: voiceName > preferJapanese（COM の言語コード 0x0411 = 1041 = ja-JP）
			if ($TtsConfig.voiceName) {
				$voices = $synth.GetVoices()
				for ($i = 0; $i -lt $voices.Count; $i++) {
					$v = $voices.Item($i)
					if ($v.GetDescription() -like "*$($TtsConfig.voiceName)*") { $synth.Voice = $v; break }
				}
			}
			elseif ($TtsConfig.preferJapanese -eq $true) {
				$jaVoices = $synth.GetVoices("Language=411")
				if ($jaVoices.Count -gt 0) { $synth.Voice = $jaVoices.Item(0) }
			}

			$script:SpeechSynthesizer = $synth
			$script:SpeechSynthesizerEngine = "SAPI"
			return $true
		}
	}
	catch {
		Write-Verbose "TTS 初期化に失敗しました: $($_.Exception.Message)"
		$script:SpeechSynthesizer = $null
		$script:SpeechSynthesizerEngine = $null
		return $false
	}
}

# TTS 通知送信
function Send-TTSNotification {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[Parameter(Mandatory = $false)]
		[string]$EventType
	)

	try {
		if (-not $Global:NotificationConfig) {
			Write-Warning "通知設定が読み込まれていません"
			return $false
		}

		$ttsConfig = $Global:NotificationConfig.notifications.providers.tts
		if (-not $ttsConfig -or -not $ttsConfig.enabled) {
			Write-Verbose "TTS 通知が無効になっています"
			return $true
		}

		if (-not $script:SpeechSynthesizer) {
			$null = Initialize-TTSSynthesizer -TtsConfig $ttsConfig
		}

		if (-not $script:SpeechSynthesizer) {
			Write-Verbose "TTS シンセサイザーが初期化できませんでした"
			return $false
		}

		# イベントフィルタリング
		$speakEvents = @()
		if ($ttsConfig.speakEvents) { $speakEvents = @($ttsConfig.speakEvents) }
		if ($speakEvents.Count -gt 0 -and $EventType) {
			if ($EventType -notin $speakEvents) {
				Write-Verbose "TTS: イベント '$EventType' は speakEvents に含まれていないため読み上げをスキップ"
				return $true
			}
		}

		# メッセージ整形（改行を区切りとして読みやすく）
		$spoken = $Message -replace "`r`n|`r|`n", "。 "

		# 非同期で再生できる環境では非同期、なければ同期
		if ($script:SpeechSynthesizer.PSObject.Methods.Name -contains 'SpeakAsync') {
			$null = $script:SpeechSynthesizer.SpeakAsync($spoken)
		}
		else {
			$null = $script:SpeechSynthesizer.Speak($spoken)
		}

		Write-Verbose "TTS 通知を再生しました ($script:SpeechSynthesizerEngine)"
		return $true
	}
	catch {
		Write-Warning "TTS 通知送信でエラー: $($_.Exception.Message)"
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

# マシンID管理関数
function Get-OrCreate-MachineId {
	param(
		[string]$StoragePath = "status/teams_machine_ids.json"
	)

	try {
		$serialNumber = Get-PCSerialNumber
		$idFile = Join-Path (Split-Path $PSScriptRoot -Parent) $StoragePath

		# 既存IDの確認
		if (Test-Path $idFile) {
			$machineIds = Get-Content $idFile -Raw | ConvertFrom-Json
			if ($machineIds.$serialNumber) {
				Write-Verbose "既存のマシンID取得: $($machineIds.$serialNumber)"
				return $machineIds.$serialNumber
			}
		}

		# 新規ID生成
		$newId = [System.Guid]::NewGuid().ToString("N").Substring(0, 12)
		Write-Verbose "新しいマシンID生成: $newId"

		# ID保存
		$machineIds = @{}
		if (Test-Path $idFile) {
			$machineIds = Get-Content $idFile -Raw | ConvertFrom-Json
		}
		$machineIds | Add-Member -NotePropertyName $serialNumber -NotePropertyValue $newId -Force

		# statusディレクトリが存在しない場合は作成
		$parentDir = Split-Path $idFile -Parent
		if (-not (Test-Path $parentDir)) {
			New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
		}

		$machineIds | ConvertTo-Json | Out-File -FilePath $idFile -Encoding UTF8

		return $newId
	}
	catch {
		Write-Warning "マシンID管理でエラー: $($_.Exception.Message)"
		# エラー時はシリアル番号をそのまま使用
		return $serialNumber
	}
}

# Teams通知送信（新スレッド化方式）
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

		# Flow URLが設定されているかチェック
		if (-not $teamsConfig.flowUrl -or $teamsConfig.flowUrl -eq "https://your-teams-flow-url-here") {
			Write-Warning "Teams Flow URLが設定されていません"
			return $false
		}

		# 必須設定の確認
		if (-not $teamsConfig.teamId) {
			Write-Warning "Teams Team IDが設定されていません"
			return $false
		}

		if (-not $teamsConfig.channelId) {
			Write-Warning "Teams Channel IDが設定されていません"
			return $false
		}

		# マシンIDの取得・生成
		$machineId = Get-OrCreate-MachineId -StoragePath $teamsConfig.idStoragePath

		# 改行文字を適切に処理
		$processedMessage = $Message -replace "`r`n", "`n" -replace "`r", "`n"

		# デバッグ用：元のメッセージと処理後のメッセージをログ出力
		Write-Verbose "元のメッセージ: $Message"
		Write-Verbose "改行正規化後: $processedMessage"

		# Teams対応の改行処理（HTML改行タグを使用）
		# Power Automate側でcontentType: "html"を指定することで<br>タグが正しく反映される
		$htmlMessage = $processedMessage -replace "`n", "<br>"
		Write-Verbose "HTML改行タグ適用後: $htmlMessage"

		# 新しいペイロード形式
		$payload = @{
			id         = $machineId
			team_id    = $teamsConfig.teamId
			channel_id = $teamsConfig.channelId
			message    = $htmlMessage
		}

		# 日本語文字化け対策（改行を保持）
		$jsonPayload = $payload | ConvertTo-Json
		Write-Verbose "送信するJSONペイロード: $jsonPayload"
		$convertedText = [System.Text.Encoding]::UTF8.GetBytes($jsonPayload)

		# PowerAutomateフロー呼び出し
		$headers = @{
			"Content-Type" = "application/json; charset=utf-8"
		}

		Invoke-RestMethod -Uri $teamsConfig.flowUrl -Method POST -Headers $headers -Body $convertedText

		Write-Verbose "Teams通知を送信しました (新スレッド方式, マシンID: $machineId)"
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
		if (-not $Variables.ContainsKey("machineName") -or [string]::IsNullOrWhiteSpace($Variables.machineName)) {
			$Variables.machineName = Get-PreferredMachineName
		}
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

		# TTS通知
		if ($Global:NotificationConfig.notifications.providers.tts.enabled) {
			$ttsResult = Send-TTSNotification -Message $message -EventType $EventType
			$results += $ttsResult
		}

		# 少なくとも一つの通知が成功した場合は成功とする
		return ($results -contains $true)

	}
	catch {
		Write-Warning "通知送信でエラーが発生しました: $($_.Exception.Message)"
		return $false
	}
}

# CSV から推奨PC名を解決（該当なし・エラー時は現在のコンピューター名）
function Get-PreferredMachineName {
	try {
		$serial = Get-PCSerialNumber
		if ([string]::IsNullOrWhiteSpace($serial)) { return $env:COMPUTERNAME }

		# 比較用にシリアルを正規化（空白/記号を除去）
		$normalizedSerial = $serial -replace '\s+', '' -replace '[^\w]', ''

		$csvPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config\machine_list.csv"
		if (-not (Test-Path $csvPath)) { return $env:COMPUTERNAME }

		$rows = Import-Csv -Path $csvPath
		$matched = $rows |
		Where-Object {
			$csvSerial = ($_.'Serial Number')
			if ($null -eq $csvSerial) { return $false }
			$csvNormalized = ([string]$csvSerial) -replace '\s+', '' -replace '[^\w]', ''
			return $csvNormalized -eq $normalizedSerial
		}

		if ($matched -and -not [string]::IsNullOrWhiteSpace($matched.'Machine Name')) {
			return [string]$matched.'Machine Name'
		}
		return $env:COMPUTERNAME
	}
	catch { return $env:COMPUTERNAME }
}

# マシンIDクリア関数（テスト用）
function Clear-MachineIds {
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
			$teamsMachineIdFile = Join-Path $statusPath "teams_machine_ids.json"
			if (Test-Path $teamsMachineIdFile) {
				if ($All) {
					Remove-Item $teamsMachineIdFile -Force
					Write-Verbose "TeamsマシンIDファイルを全削除しました"
				}
				else {
					$machineIds = Get-Content $teamsMachineIdFile -Raw | ConvertFrom-Json
					$machineIds.PSObject.Properties.Remove($SerialNumber)
					$machineIds | ConvertTo-Json | Out-File -FilePath $teamsMachineIdFile -Encoding UTF8
					Write-Verbose "TeamsマシンID '$SerialNumber' をクリアしました"
				}
			}
		}

		return $true
	}
	catch {
		Write-Warning "マシンIDクリアでエラー: $($_.Exception.Message)"
		return $false
	}
}
