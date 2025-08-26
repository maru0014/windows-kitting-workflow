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

# 共通通知関数の読み込み
. (Join-Path $PSScriptRoot "scripts\Common-NotificationFunctions.ps1")
# ワークフロー共通ヘルパーの読み込み（パス解決・マーカー支援）
. (Join-Path $PSScriptRoot "scripts\Common-WorkflowHelpers.ps1")

# グローバル変数
$Global:WorkflowConfig = $null
$Global:NotificationConfig = $null
$Global:WorkflowStartTime = Get-Date
$Global:WorkflowInitialStartTime = $null  # 初回実行時刻（再起動を跨いで保持）
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

# ワークフロー実行時間を計算するヘルパー関数
function Get-WorkflowDurations {
	param(
		[DateTime]$CurrentTime = (Get-Date)
	)

	$totalDuration = if ($Global:WorkflowInitialStartTime) {
		New-TimeSpan -Start $Global:WorkflowInitialStartTime -End $CurrentTime
	}
	else {
		New-TimeSpan -Start $Global:WorkflowStartTime -End $CurrentTime
	}

	$sessionDuration = New-TimeSpan -Start $Global:WorkflowStartTime -End $CurrentTime

	return @{
		Total   = $totalDuration
		Session = $sessionDuration
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

		# 共通通知ライブラリを初期化
		if (-not (Import-NotificationConfig -ConfigPath $NotificationConfigPath)) {
			Write-Log "共通通知ライブラリの初期化に失敗しました" -Level "WARN"
		}
		else {
			Write-Log "共通通知ライブラリを初期化しました"
		}

	}
 catch {
		Write-Log "設定ファイルの読み込みに失敗しました: $($_.Exception.Message)" -Level "ERROR"
		throw
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
function Resolve-CompletionMarkerPath {
	param(
		[object]$Step
	)

	# 既定テンプレート
	$defaultTemplate = "status/{id}.completed"

	$relativePath = $null
	$pathFromConfig = $null
	if ($Step -and $Step.completionCheck -and $Step.completionCheck.type -eq "file") {
		$pathFromConfig = $Step.completionCheck.path
	}

	if ([string]::IsNullOrWhiteSpace($pathFromConfig)) {
		# 未指定なら既定テンプレート
		$relativePath = Expand-PathPlaceholders -Template $defaultTemplate -Step $Step
	}
	else {
		# 指定あり
		$hasTemplateToken = ($pathFromConfig -match "\{.+\}")
		if ($hasTemplateToken) {
			$relativePath = Expand-PathPlaceholders -Template $pathFromConfig -Step $Step
		}
		else {
			$relativePath = $pathFromConfig
		}
	}

	# 絶対/相対を判定してフルパスへ
	if ([System.IO.Path]::IsPathRooted($relativePath)) {
		return $relativePath
	}
	else {
		return (Join-Path $PSScriptRoot $relativePath)
	}
}

function Test-StepCompletion {
	param(
		[object]$Step
	)

	$completionCheck = $Step.completionCheck

	switch ($completionCheck.type) {
		"file" {
			# 既定のステップIDマーカー、または互換用の completionCheck.path のどちらかが存在すれば完了
			$defaultPath = Expand-PathPlaceholders -Template "status/{id}.completed" -Step $Step
			$defaultFull = if ([System.IO.Path]::IsPathRooted($defaultPath)) { $defaultPath } else { (Join-Path $PSScriptRoot $defaultPath) }
			if (Test-Path $defaultFull) { return $true }

			# 互換: completionCheck.path が指定されている場合はそちらも許可
			if ($Step -and $Step.completionCheck -and $Step.completionCheck.path -and -not [string]::IsNullOrWhiteSpace($Step.completionCheck.path)) {
				$configuredFull = Resolve-CompletionMarkerPath -Step $Step
				if ($configuredFull -and ($configuredFull -ne $defaultFull) -and (Test-Path $configuredFull)) {
					return $true
				}
			}

			return $false
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

					# 環境変数でステップ情報を渡す
					$previousStepId = $env:WKF_STEP_ID
					$previousRunId = $env:WKF_RUN_ID
					$env:WKF_STEP_ID = $Step.id
					$runIdSource = if ($Global:WorkflowInitialStartTime) { $Global:WorkflowInitialStartTime } else { Get-Date }
					$env:WKF_RUN_ID = $runIdSource.ToString("yyyyMMdd-HHmmssfff")

					try {
						if ($Step.type -eq "powershell") {
							& $scriptPath @parameters
							$exitCode = $LASTEXITCODE
						}
						else {
							& cmd /c $scriptPath @parameters
							$exitCode = $LASTEXITCODE
						}
					}
					finally {
						if ($null -ne $previousStepId) { $env:WKF_STEP_ID = $previousStepId } else { Remove-Item Env:\WKF_STEP_ID -ErrorAction SilentlyContinue }
						if ($null -ne $previousRunId) { $env:WKF_RUN_ID = $previousRunId } else { Remove-Item Env:\WKF_RUN_ID -ErrorAction SilentlyContinue }
					}
				}
			}

			if ($exitCode -eq 0) {
				# 完了マーカー作成（集中管理・上書き回避）
				$completionMarker = Resolve-CompletionMarkerPath -Step $Step
				$completionDir = Split-Path $completionMarker -Parent
				if (-not (Test-Path $completionDir)) {
					New-Item -ItemType Directory -Path $completionDir -Force | Out-Null
				}

				if (-not $DryRun) {
					if (-not (Test-Path $completionMarker)) {
						@{
							stepId      = $Step.id
							stepName    = $Step.name
							completedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
							exitCode    = $exitCode
						} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8
					}
					else {
						Write-Log "既存の完了マーカーを検出したため上書きしません: $completionMarker" -Level "DEBUG"
					}
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
		$workflowInitialStartFile = Join-Path $Global:StatusPath "workflow-initial-start.json"
		$isFirstRun = -not (Test-Path $workflowStartStatusFile)
		# 初回実行時刻を記録または取得
		if ($isFirstRun) {
			# 初回実行時刻をグローバル変数に設定
			$Global:WorkflowInitialStartTime = $Global:WorkflowStartTime

			# 初回実行時刻をファイルに記録
			$initialStartInfo = @{
				initialStartTime = $Global:WorkflowStartTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
				computerName     = $env:COMPUTERNAME
				userName         = $env:USERNAME
				timeZone         = [System.TimeZoneInfo]::Local.Id
			}

			try {
				$initialStartInfo | ConvertTo-Json | Out-File -FilePath $workflowInitialStartFile -Encoding UTF8
				Write-Log "初回実行時刻を記録しました: $($Global:WorkflowInitialStartTime)"
			}
			catch {
				Write-Log "初回実行時刻の記録に失敗しました: $($_.Exception.Message)" -Level "WARN"
			}
		}
		else {
			# 既存の初回実行時刻を読み込み
			try {
				if (Test-Path $workflowInitialStartFile) {
					$initialStartInfo = Get-Content -Path $workflowInitialStartFile -Encoding UTF8 | ConvertFrom-Json
					$Global:WorkflowInitialStartTime = [DateTime]::ParseExact($initialStartInfo.initialStartTime, "yyyy-MM-dd HH:mm:ss.fff", $null)
					Write-Log "初回実行時刻を復元しました: $($Global:WorkflowInitialStartTime)"
				}
				else {
					Write-Log "初回実行時刻ファイルが見つかりません。現在時刻を初回時刻として使用します。" -Level "WARN"
					$Global:WorkflowInitialStartTime = $Global:WorkflowStartTime
				}
			}
			catch {
				Write-Log "初回実行時刻の復元に失敗しました: $($_.Exception.Message)" -Level "WARN"
				$Global:WorkflowInitialStartTime = $Global:WorkflowStartTime
			}
		}

		# 初回起動時のみ開始通知を送信
		if ($isFirstRun) {
			$workflowSteps = Get-WorkflowStepsMessage
			$null = Send-Notification -EventType "onWorkflowStart" -Variables @{
				workflowSteps = $workflowSteps
			}
			Start-Sleep -Seconds 5

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
		# 完了通知（総実行時間を正確に計算）
		$durations = Get-WorkflowDurations
		$null = Send-Notification -EventType "onWorkflowComplete" -Variables @{
			totalDuration   = $durations.Total.ToString()
			sessionDuration = $durations.Session.ToString()
			completedSteps  = $completedSteps.Count
			totalSteps      = $totalSteps
			failedSteps     = $failedSteps.Count
			success         = if ($failedSteps.Count -eq 0) { "true" } else { "false" }
		}
		Write-Log "ワークフロー完了"
		Write-Log "完了ステップ: $($completedSteps.Count)/$totalSteps"
		Write-Log "今回セッション実行時間: $($durations.Session.ToString())"
		Write-Log "総実行時間（初回開始から）: $($durations.Total.ToString())"

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

		$null = Send-Notification -EventType "onWorkflowError" -Variables @{
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
	}
	# 設定読み込み
	Read-Configuration -ConfigPath $ConfigPath -NotificationConfigPath $NotificationConfigPath

	# ワークフロー実行
	$exitCode = Start-MainWorkflow

	# 実行時間を正確に計算
	$durations = Get-WorkflowDurations

	# 結果の表示とユーザー確認
	Write-Host ""
	Write-Host "========================================" -ForegroundColor Cyan
	Write-Host "Windows Kitting Workflow 実行結果" -ForegroundColor Cyan
	Write-Host "========================================" -ForegroundColor Cyan

	# 結果の概要表示
	if ($exitCode -eq 0) {
		Write-Host "結果: 正常終了" -ForegroundColor Green
		Write-Host "すべてのワークフローが正常に完了しました。" -ForegroundColor Green
	}
	else {
		Write-Host "結果: 異常終了" -ForegroundColor Red
		Write-Host "一部のワークフローでエラーが発生しました。" -ForegroundColor Red
	}

	Write-Host ""
	Write-Host "詳細情報を表示するには何かキーを押してください..." -ForegroundColor Yellow
	$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

	if ($exitCode -eq 0) {
		Write-Host "✓ ワークフローが正常に完了しました" -ForegroundColor Green
		Write-Host "  すべてのセットアップが完了しました。" -ForegroundColor Green
		Write-Host "  ログファイルが自動的に開かれました。" -ForegroundColor Green
		# 成功時の通知送信
		$null = Send-Notification -EventType "onWorkflowSuccess" -Variables @{
			totalDuration   = $durations.Total.ToString()
			sessionDuration = $durations.Session.ToString()
			logPath         = $Global:LogPath
			computerName    = $env:COMPUTERNAME
		}
	}
 elseif ($exitCode -ne 0) {
		# 失敗時の処理
		Write-Host "✗ ワークフローが失敗しました" -ForegroundColor Red
		Write-Host "  詳細はログファイルを確認してください。" -ForegroundColor Yellow

		# 失敗時の通知送信
		$null = Send-Notification -EventType "onWorkflowFailure" -Variables @{
			totalDuration   = $durations.Total.ToString()
			sessionDuration = $durations.Session.ToString()
			logPath         = $Global:LogPath
			errorLogPath    = $Global:ErrorLogPath
			computerName    = $env:COMPUTERNAME
		}

		Write-Host "✗ ワークフローがエラーで終了しました" -ForegroundColor Red
		Write-Host "  詳細はログファイルを確認してください。" -ForegroundColor Yellow

		# 失敗時の通知送信
		$null = Send-Notification -EventType "onWorkflowFailure" -Variables @{
			totalDuration   = $durations.Total.ToString()
			sessionDuration = $durations.Session.ToString()
			logPath         = $Global:LogPath
			errorLogPath    = $Global:ErrorLogPath
			computerName    = $env:COMPUTERNAME
		}
	}

	Write-Host ""
	Write-Host "今回セッション実行時間: $($durations.Session.ToString())" -ForegroundColor White
	Write-Host "総実行時間（初回開始から）: $($durations.Total.ToString())" -ForegroundColor Cyan
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
	try {
		$errorDurations = Get-WorkflowDurations
		$errorTotalDuration = $errorDurations.Total.ToString()
		$errorSessionDuration = $errorDurations.Session.ToString()
	}
	catch {
		# 時間計算でエラーが発生した場合のフォールバック
		$errorTotalDuration = "計測不可"
		$errorSessionDuration = "計測不可"
	}

	$null = Send-Notification -EventType "onWorkflowCriticalError" -Variables @{
		errorMessage    = $_.Exception.Message
		logPath         = $Global:LogPath
		errorLogPath    = $Global:ErrorLogPath
		computerName    = $env:COMPUTERNAME
		totalDuration   = $errorTotalDuration
		sessionDuration = $errorSessionDuration
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
