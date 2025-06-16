# ============================================================================
# Windows Update実行スクリプト
# 利用可能なWindowsアップデートをすべてインストール
# ============================================================================

param(
	[switch]$Force,
	[switch]$RebootIfRequired,
	[switch]$MicrosoftUpdate,
	[string[]]$KBArticleID,
	[string[]]$NotKBArticleID
)

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "WindowsUpdate" -LogFileName "windows-update.log"
}

# PSWindowsUpdateモジュールのインストールと確認
function Install-WindowsUpdateModule {
	try {
		Write-Log "PSWindowsUpdateモジュールを確認中..."

		$module = Get-Module -Name PSWindowsUpdate -ListAvailable
		if (-not $module) {
			Write-Log "PSWindowsUpdateモジュールをインストール中..."

			# NuGetプロバイダーのインストール
			if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue -Force)) {
				Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
			}

			# PSGalleryを信頼済みリポジトリに設定
			Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

			# PSWindowsUpdateモジュールのインストール
			Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser

			Write-Log "PSWindowsUpdateモジュールをインストールしました"
		}
		else {
			Write-Log "PSWindowsUpdateモジュールは既にインストールされています"
		}

		# モジュールのインポート
		Import-Module PSWindowsUpdate -Force
		Write-Log "PSWindowsUpdateモジュールをインポートしました"

		return $true

	}
 catch {
		Write-Log "PSWindowsUpdateモジュールの設定でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# Windows Updateサービスの状態確認と開始
function Start-WindowsUpdateServices {
	try {
		Write-Log "Windows Updateサービスを確認中..."

		$services = @(
			@{ Name = "wuauserv"; DisplayName = "Windows Update" },
			@{ Name = "bits"; DisplayName = "Background Intelligent Transfer Service" },
			@{ Name = "cryptsvc"; DisplayName = "Cryptographic Services" },
			@{ Name = "msiserver"; DisplayName = "Windows Installer" }
		)

		foreach ($svc in $services) {
			try {
				$service = Get-Service -Name $svc.Name
				Write-Log "$($svc.DisplayName) サービス状態: $($service.Status)"

				if ($service.Status -ne "Running") {
					Write-Log "$($svc.DisplayName) サービスを開始中..."
					Start-Service -Name $svc.Name
					Start-Sleep -Seconds 2

					$service = Get-Service -Name $svc.Name
					if ($service.Status -eq "Running") {
						Write-Log "$($svc.DisplayName) サービスを開始しました"
					}
					else {
						Write-Log "$($svc.DisplayName) サービスの開始に失敗しました" -Level "WARN"
					}
				}
			}
			catch {
				Write-Log "$($svc.DisplayName) サービスの操作でエラー: $($_.Exception.Message)" -Level "WARN"
			}
		}

		return $true

	}
 catch {
		Write-Log "Windows Updateサービスの確認でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# 利用可能なアップデートの確認
function Get-AvailableUpdates {
	try {
		Write-Log "利用可能なアップデートを確認中..."

		$getWUParams = @{}

		if ($MicrosoftUpdate) {
			$getWUParams['MicrosoftUpdate'] = $true
			Write-Log "Microsoft Updateサービスを含めて検索します"
		}

		if ($KBArticleID -and $KBArticleID.Count -gt 0) {
			$getWUParams['KBArticleID'] = $KBArticleID
			Write-Log "指定されたKB番号で検索します: $($KBArticleID -join ', ')"
		}

		if ($NotKBArticleID -and $NotKBArticleID.Count -gt 0) {
			$getWUParams['NotKBArticleID'] = $NotKBArticleID
			Write-Log "除外するKB番号: $($NotKBArticleID -join ', ')"
		}

		$updates = Get-WUList @getWUParams

		if ($updates) {
			Write-Log "利用可能なアップデート数: $($updates.Count)"

			foreach ($update in $updates) {
				$sizeInfo = if ($update.Size) {
					$sizeMB = [math]::Round($update.Size / 1MB, 2)
					" (${sizeMB}MB)"
				}
				else {
					""
				}

				$kbInfo = if ($update.KBArticleIDs) {
					" [KB: $($update.KBArticleIDs -join ', ')]"
				}
				else {
					""
				}

				Write-Log "  - $($update.Title)$sizeInfo$kbInfo"
			}
		}
		else {
			Write-Log "利用可能なアップデートはありません"
		}

		return $updates

	}
 catch {
		Write-Log "アップデート確認でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

# アップデートのインストール
function Install-WindowsUpdates {
	try {
		Write-Log "Windows Updateのインストールを開始します"

		$installParams = @{
			'AcceptAll'  = $true
			'AutoReboot' = $false
			'Verbose'    = $true
		}

		if ($MicrosoftUpdate) {
			$installParams['MicrosoftUpdate'] = $true
		}

		if ($KBArticleID -and $KBArticleID.Count -gt 0) {
			$installParams['KBArticleID'] = $KBArticleID
		}

		if ($NotKBArticleID -and $NotKBArticleID.Count -gt 0) {
			$installParams['NotKBArticleID'] = $NotKBArticleID
		}

		# アップデートのダウンロードとインストール
		$result = Get-WUInstall @installParams

		if ($result) {
			Write-Log "インストールされたアップデート:"
			foreach ($update in $result) {
				Write-Log "  - $($update.Title): $($update.Result)"
			}

			# 再起動が必要かチェック
			$rebootRequired = Get-WURebootStatus -Silent
			if ($rebootRequired) {
				Write-Log "再起動が必要です" -Level "WARN"
				return @{ Success = $true; RebootRequired = $true; Updates = $result }
			}
			else {
				Write-Log "再起動は不要です"
				return @{ Success = $true; RebootRequired = $false; Updates = $result }
			}
		}
		else {
			Write-Log "インストールするアップデートがありませんでした"
			return @{ Success = $true; RebootRequired = $false; Updates = @() }
		}

	}
 catch {
		Write-Log "アップデートインストールでエラー: $($_.Exception.Message)" -Level "ERROR"
		return @{ Success = $false; RebootRequired = $false; Updates = @() }
	}
}

# Windows Update履歴の取得
function Get-UpdateHistory {
	try {
		Write-Log "最近のWindows Update履歴を確認中..."

		$history = Get-WUHistory -MaxDate (Get-Date).AddDays(-30) | Select-Object -First 10

		if ($history) {
			Write-Log "最近のアップデート履歴 (30日以内):"
			foreach ($item in $history) {
				Write-Log "  - $($item.Date): $($item.Title) ($($item.Result))"
			}
		}
		else {
			Write-Log "最近のアップデート履歴がありません"
		}

	}
 catch {
		Write-Log "アップデート履歴の確認でエラー: $($_.Exception.Message)" -Level "WARN"
	}
}

try {
	Write-Log "Windows Update処理を開始します"

	# Windows Updateサービスの開始
	if (-not (Start-WindowsUpdateServices)) {
		throw "Windows Updateサービスの開始に失敗しました"
	}

	# PSWindowsUpdateモジュールのインストール
	if (-not (Install-WindowsUpdateModule)) {
		throw "PSWindowsUpdateモジュールのインストールに失敗しました"
	}

	# アップデート履歴の確認
	Get-UpdateHistory

	# 利用可能なアップデートの確認
	$availableUpdates = Get-AvailableUpdates

	if (-not $availableUpdates -or $availableUpdates.Count -eq 0) {
		Write-Log "利用可能なアップデートがありません。処理を完了します"

		# 完了マーカーの作成
		$completionMarker = Get-CompletionMarkerPath -TaskName "windows-update"
		@{
			completedAt      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
			updatesInstalled = 0
			rebootRequired   = $false
			message          = "利用可能なアップデートなし"
		} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

		exit 0
	}

	# アップデートのインストール実行
	Write-Log "アップデートのインストールを実行します..."
	$installResult = Install-WindowsUpdates

	if ($installResult.Success) {
		Write-Log "Windows Updateが正常に完了しました"
		Write-Log "インストールされたアップデート数: $($installResult.Updates.Count)"

		# 再起動が必要な場合
		if ($installResult.RebootRequired) {
			Write-Log "システムの再起動が必要です" -Level "WARN"

			if ($RebootIfRequired) {
				Write-Log "30秒後にシステムを再起動します..."
				Start-Sleep -Seconds 30
				Restart-Computer -Force
			}
			else {
				Write-Log "再起動は手動で実行してください" -Level "WARN"
			}
		}

		exit 0

	}
 else {
		Write-Log "Windows Updateでエラーが発生しました" -Level "ERROR"
		exit 1
	}

}
catch {
	Write-Log "Windows Update処理でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	exit 1
}
