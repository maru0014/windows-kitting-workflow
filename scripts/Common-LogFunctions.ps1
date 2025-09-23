# ============================================================================
# 共通ログ関数
# UTF-8 with BOM でのログ出力をサポート
# LogLevel設定を考慮したログフィルタリング機能付き
# ============================================================================

# LogLevelの優先度を定義
$Global:LogLevelPriority = @{
	"DEBUG" = 0
	"INFO"  = 1
	"WARN"  = 2
	"ERROR" = 3
}

# ワークフローヘルパーのインポート
. (Join-Path $PSScriptRoot "Common-WorkflowHelpers.ps1")

# LogLevelをチェックする関数
function Test-ScriptLogLevel {
	param(
		[string]$MessageLevel
	)
	# ワークフローのルートディレクトリを取得
	Get-WorkflowRoot $PSScriptRoot | Out-Null

	# workflow.json設定ファイルのパスを構築
	$configPath = Get-WorkflowPath -PathType "Config" -SubPath "workflow.json"
	$workflowConfigPath = $null
	if (Test-Path $configPath) {
		$workflowConfigPath = $configPath
	}

	# デフォルトのLogLevel
	$currentLogLevel = "INFO"

	# workflow.json設定を読み込んでlogLevelを取得
	if ($workflowConfigPath) {
		try {
			$configContent = Get-Content $workflowConfigPath -Raw -Encoding UTF8
			$config = $configContent | ConvertFrom-Json
			if ($config.workflow.settings.logLevel) {
				$currentLogLevel = $config.workflow.settings.logLevel
			}
		}
		catch {
			# 設定読み込みエラーは無視してデフォルト使用
		}
	}

	$currentPriority = $Global:LogLevelPriority[$currentLogLevel]
	$messagePriority = $Global:LogLevelPriority[$MessageLevel]

	return $messagePriority -ge $currentPriority
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

	# 共有違反発生時のリトライ + フォールバック (*.alt.log)
	$maxAttempts = 3
	$attempt = 0
	$opened = $false
	$fileStream = $null

	while (-not $opened -and $attempt -lt $maxAttempts) {
		try {
			if (Test-Path $Path) {
				$fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
			}
			else {
				$fileStream = [System.IO.File]::Create($Path)
				# 新しいファイルの場合はBOMを最初に書き込む
				$bomBytes = $utf8WithBom.GetPreamble()
				$fileStream.Write($bomBytes, 0, $bomBytes.Length)
			}
			$opened = $true
		}
		catch {
			$attempt++
			if ($attempt -lt $maxAttempts) { Start-Sleep -Milliseconds 200 }
		}
	}

	if (-not $opened) {
		$dir = Split-Path $Path -Parent
		$base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
		$ext = [System.IO.Path]::GetExtension($Path)
		$fallbackPath = Join-Path $dir ("{0}.alt{1}" -f $base, $ext)

		Write-Host ("[WARN] ログファイルにアクセスできません。フォールバックへ出力します: {0}" -f $fallbackPath) -ForegroundColor Yellow

		$attempt = 0
		while (-not $opened -and $attempt -lt $maxAttempts) {
			try {
				if (Test-Path $fallbackPath) {
					$fileStream = [System.IO.File]::Open($fallbackPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
				}
				else {
					$fileStream = [System.IO.File]::Create($fallbackPath)
					$bomBytes2 = $utf8WithBom.GetPreamble()
					$fileStream.Write($bomBytes2, 0, $bomBytes2.Length)
				}
				$opened = $true
			}
			catch {
				$attempt++
				Start-Sleep -Milliseconds 200
			}
		}

		if (-not $opened) {
			Write-Host ("[WARN] ログ書き込みに失敗しました（フォールバックも失敗）。メッセージ: {0}" -f $Message) -ForegroundColor Yellow
			return
		}
	}

	try {
		$bytes = $utf8WithBom.GetBytes($messageWithNewline)
		$fileStream.Write($bytes, 0, $bytes.Length)
	}
	catch {
		Write-Host ("[WARN] ログ書き込み中にエラーが発生しました。メッセージを破棄して継続します: {0} (原因: {1})" -f $Message, $_.Exception.Message) -ForegroundColor Yellow
	}
	finally {
		if ($fileStream) { $fileStream.Close() }
	}
}

# 共通ログ関数（スクリプト用）
function Write-ScriptLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Message,

		[ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
		[string]$Level = "INFO",

		[Parameter(Mandatory = $true)]
		[string]$ScriptName,

		[string]$LogFileName,

		[bool]$NoConsoleOutput = $false
	)

	# LogLevelチェック - 設定レベル未満のログは出力しない
	if (-not (Test-ScriptLogLevel -MessageLevel $Level)) {
		return
	}

	$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	$logMessage = "[$timestamp] [$Level] [$ScriptName] $Message"

	# コンソール出力（NoConsoleOutputがfalseの場合のみ）
	if (-not $NoConsoleOutput) {
		switch ($Level) {
			"ERROR" { Write-Host $logMessage -ForegroundColor Red }
			"WARN" { Write-Host $logMessage -ForegroundColor Yellow }
			"INFO" { Write-Host $logMessage -ForegroundColor Green }
			"DEBUG" { Write-Host $logMessage -ForegroundColor Cyan }
		}
	}	# ログファイル名が指定されていない場合はスクリプト名から生成
	if (-not $LogFileName) {
		$LogFileName = "$ScriptName.log"
	}
	# ワークフローのルートディレクトリを取得
	Get-WorkflowRoot $PSScriptRoot | Out-Null

	# ログファイルパスの作成（ルートディレクトリのログ）
	$logPath = Get-WorkflowPath -PathType "Logs" -SubPath "scripts\$LogFileName"

	# UTF-8 with BOM でファイル出力
	Write-LogToFile -Path $logPath -Message $logMessage

	# メインワークフローログにも出力
	$mainLogPath = Get-WorkflowPath -PathType "Logs" -SubPath "workflow.log"
	Write-LogToFile -Path $mainLogPath -Message $logMessage
}
