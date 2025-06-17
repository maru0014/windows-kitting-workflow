# ============================================================================
# BitLocker設定スクリプト
# システムドライブのBitLocker暗号化を設定
# ============================================================================

param(
	[switch]$EnablePIN,
	[switch]$Force,
	[switch]$DryRun
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

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "BitLocker" -LogFileName "setup-bitlocker.log"
}

# TPMステータス確認
function Test-TPMStatus {
	try {
		Write-Log "TPMステータスを確認中..."

		$tpm = Get-Tpm
		if (-not $tpm) {
			Write-Log "TPMが検出されませんでした" -Level "ERROR"
			return $false
		}

		Write-Log "TPM情報:"
		Write-Log "  有効状態: $($tpm.TpmEnabled)"
		Write-Log "  アクティブ状態: $($tpm.TpmActivated)"
		Write-Log "  所有状態: $($tpm.TpmOwned)"
		Write-Log "  準備完了: $($tpm.TpmReady)"

		if (-not $tpm.TpmEnabled) {
			Write-Log "TPMが有効になっていません。BIOSでTPMを有効にしてください" -Level "ERROR"
			return $false
		}

		if (-not $tpm.TpmActivated) {
			Write-Log "TPMがアクティブになっていません" -Level "WARN"
		}

		return $true
	}
	catch {
		Write-Log "TPMステータス確認中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# BitLockerステータス確認
function Get-BitLockerStatus {
	param(
		[string]$Drive = "C:"
	)

	try {
		Write-Log "BitLockerステータスを確認中 (ドライブ: $Drive)..."

		$bitlockerVolume = Get-BitLockerVolume -MountPoint $Drive -ErrorAction SilentlyContinue

		if ($bitlockerVolume) {
			Write-Log "BitLocker情報:"
			Write-Log "  暗号化状態: $($bitlockerVolume.EncryptionPercentage)%"
			Write-Log "  保護状態: $($bitlockerVolume.ProtectionStatus)"
			Write-Log "  暗号化方法: $($bitlockerVolume.EncryptionMethod)"
			Write-Log "  キー保護子: $($bitlockerVolume.KeyProtector.Count)個"

			return $bitlockerVolume
		}
		else {
			Write-Log "BitLockerが設定されていません" -Level "INFO"
			return $null
		}
	}
	catch {
		Write-Log "BitLockerステータス確認中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

# 通知送信（PINコード設定時の手動対応が必要な場合）
function Send-BitLockerNotification {
	param(
		[string]$Message,
		[bool]$RequiresUserAction = $false
	)

	try {
		# 通知設定を読み込み
		$notificationConfig = Get-WorkflowConfig -ConfigType "notifications"

		if (-not $notificationConfig) {
			Write-Log "通知設定が見つかりません" -Level "WARN"
			return
		}

		$title = if ($RequiresUserAction) {
			"🔐 BitLocker設定 - ユーザー対応が必要"
		}
		else {
			"🔐 BitLocker設定完了"
		}

		$notificationMessage = if ($RequiresUserAction) {
			"⚠️ **重要**: $Message`n次回再起動時にPINコードの設定が求められます。ユーザーが手動で設定する必要があります。"
		}
		else {
			$Message
		}

		# Slack webhook通知（シンプル版）
		if ($notificationConfig.notifications.providers.slack.webhookUrl) {
			try {
				$slackPayload = @{
					text       = "$title`n$notificationMessage"
					username   = "Windows Kitting Bot"
					icon_emoji = ":lock:"
				}

				$jsonPayload = $slackPayload | ConvertTo-Json
				Invoke-RestMethod -Uri $notificationConfig.notifications.providers.slack.webhookUrl -Method POST -Body $jsonPayload -ContentType "application/json"
				Write-Log "Slack通知を送信しました" -Level "DEBUG"
			}
			catch {
				Write-Log "Slack通知送信に失敗しました: $($_.Exception.Message)" -Level "WARN"
			}
		}

		# Teams webhook通知（シンプル版）
		if ($notificationConfig.notifications.providers.teams.webhookUrl) {
			try {
				$teamsPayload = @{
					text = "$title`n$notificationMessage"
				}

				$jsonPayload = $teamsPayload | ConvertTo-Json
				Invoke-RestMethod -Uri $notificationConfig.notifications.providers.teams.webhookUrl -Method POST -Body $jsonPayload -ContentType "application/json"
				Write-Log "Teams通知を送信しました" -Level "DEBUG"
			}
			catch {
				Write-Log "Teams通知送信に失敗しました: $($_.Exception.Message)" -Level "WARN"
			}
		}

	}
 catch {
		Write-Log "通知送信中にエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
	}
}

# BitLocker有効化
function Enable-BitLockerEncryption {
	param(
		[string]$Drive = "C:",
		[bool]$UsePIN = $false
	)

	try {
		Write-Log "BitLocker暗号化を設定中 (ドライブ: $Drive)..."

		if ($DryRun) {
			Write-Log "[DRY RUN] BitLocker設定をシミュレーション中..."
			Write-Log "[DRY RUN] ドライブ: $Drive"
			Write-Log "[DRY RUN] PIN使用: $UsePIN"
			return $true
		}

		# 回復キーの保存先を設定
		$recoveryKeyPath = Get-WorkflowPath -PathType "Backup" -SubPath "bitlocker-recovery-keys"
		if (-not (Test-Path $recoveryKeyPath)) {
			New-Item -ItemType Directory -Path $recoveryKeyPath -Force | Out-Null
		}

		$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
		$recoveryKeyFile = Join-Path $recoveryKeyPath "bitlocker-recovery-key-$timestamp.txt"

		# BitLocker有効化（TPMプロテクターのみ）
		Write-Log "BitLockerを有効化中..."
		Enable-BitLocker -MountPoint $Drive -EncryptionMethod XtsAes256 -TpmProtector
		# 回復キーの追加
		Write-Log "回復キーを生成中..."
		Add-BitLockerKeyProtector -MountPoint $Drive -RecoveryPasswordProtector | Out-Null

		# 回復キーをファイルに保存
		$recoveryKey = (Get-BitLockerVolume -MountPoint $Drive).KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } | Select-Object -First 1
		if ($recoveryKey) {
			$recoveryInfo = @"
BitLocker Recovery Key Information
==================================
Computer Name: $env:COMPUTERNAME
Drive: $Drive
Date: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')
Recovery Key ID: $($recoveryKey.KeyProtectorId)
Recovery Password: $($recoveryKey.RecoveryPassword)

Important: Store this recovery key in a safe location!
==================================
"@
			$recoveryInfo | Out-File -FilePath $recoveryKeyFile -Encoding UTF8
			Write-Log "回復キーを保存しました: $recoveryKeyFile"
		}

		# PIN設定（オプション）
		if ($UsePIN) {
			Write-Log "PINプロテクターを追加中..."

			# PINプロテクターの追加（次回起動時に設定）
			Add-BitLockerKeyProtector -MountPoint $Drive -TpmAndPinProtector

			Write-Log "⚠️ PINコード設定が有効になりました"
			Write-Log "⚠️ 次回再起動時にPINコードの設定が求められます"

			# 通知送信
			Send-BitLockerNotification -Message "BitLocker暗号化が有効になりました。次回再起動時にPINコードの設定が必要です。" -RequiresUserAction $true
		}
		else {
			Send-BitLockerNotification -Message "BitLocker暗号化が正常に有効になりました。"
		}
		# 暗号化は Enable-BitLocker で自動的に開始されます
		Write-Log "ディスク暗号化が開始されました（バックグラウンドで進行中）"

		# 暗号化状況を確認
		$bitlockerStatus = Get-BitLockerVolume -MountPoint $Drive
		Write-Log "暗号化状況: $($bitlockerStatus.EncryptionPercentage)% 完了"
		Write-Log "保護状態: $($bitlockerStatus.ProtectionStatus)"

		Write-Log "✅ BitLocker設定が完了しました"
		return $true

	}
 catch {
		Write-Log "BitLocker有効化中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# BitLockerモジュールの確認とロード
function Import-BitLockerModule {
	try {
		Write-Log "BitLockerモジュールを確認中..."

		# BitLockerモジュールが利用可能か確認
		$bitlockerModule = Get-Module -Name BitLocker -ListAvailable
		if (-not $bitlockerModule) {
			Write-Log "BitLockerモジュールが見つかりません。Windows Proまたは企業版が必要です" -Level "ERROR"
			return $false
		}

		# BitLockerモジュールをインポート
		Import-Module BitLocker -Force
		Write-Log "BitLockerモジュールをロードしました"

		# 利用可能なコマンドレットを確認
		$commands = Get-Command -Module BitLocker | Select-Object -First 5
		Write-Log "利用可能なBitLockerコマンド例: $($commands.Name -join ', ')..."

		return $true
	}
	catch {
		Write-Log "BitLockerモジュールの読み込み中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# メイン処理
function Main {
	try {
		Write-Log "==================== BitLocker設定開始 ===================="
		Write-Log "実行ユーザー: $env:USERNAME"
		Write-Log "コンピュータ名: $env:COMPUTERNAME"
		Write-Log "PINコード有効: $EnablePIN"
		Write-Log "強制実行: $Force"
		Write-Log "ドライラン: $DryRun"
		# 管理者権限チェック
		$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
		if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
			Write-Log "このスクリプトは管理者権限で実行する必要があります" -Level "ERROR"
			exit 1
		}

		# BitLockerモジュール確認
		if (-not (Import-BitLockerModule)) {
			Write-Log "BitLockerモジュールが利用できません" -Level "ERROR"
			exit 1
		}

		# システムドライブを確認
		$systemDrive = $env:SystemDrive
		Write-Log "システムドライブ: $systemDrive"

		# TPMステータス確認
		if (-not (Test-TPMStatus)) {
			Write-Log "TPM要件を満たしていません" -Level "ERROR"
			exit 1
		}

		# 既存のBitLockerステータス確認
		$existingStatus = Get-BitLockerStatus -Drive $systemDrive

		if ($existingStatus -and $existingStatus.ProtectionStatus -eq "On" -and -not $Force) {
			Write-Log "BitLockerは既に有効になっています (暗号化率: $($existingStatus.EncryptionPercentage)%)"
			Write-Log "強制実行する場合は -Force パラメータを使用してください"

			# 完了フラグファイル作成
			$statusPath = Get-WorkflowPath -PathType "Status"
			if (-not (Test-Path $statusPath)) {
				New-Item -ItemType Directory -Path $statusPath -Force | Out-Null
			}
			New-Item -ItemType File -Path (Join-Path $statusPath "setup-bitlocker.completed") -Force | Out-Null

			exit 0
		}

		# BitLocker有効化実行
		$result = Enable-BitLockerEncryption -Drive $systemDrive -UsePIN $EnablePIN.IsPresent

		if ($result) {
			Write-Log "BitLocker設定が正常に完了しました"

			# 完了フラグファイル作成
			$statusPath = Get-WorkflowPath -PathType "Status"
			if (-not (Test-Path $statusPath)) {
				New-Item -ItemType Directory -Path $statusPath -Force | Out-Null
			}
			New-Item -ItemType File -Path (Join-Path $statusPath "setup-bitlocker.completed") -Force | Out-Null

			Write-Log "==================== BitLocker設定完了 ===================="
			exit 0
		}
		else {
			Write-Log "BitLocker設定に失敗しました" -Level "ERROR"
			exit 1
		}

	}
 catch {
		Write-Log "予期しないエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		Write-Log "スタックトレース: $($_.ScriptStackTrace)" -Level "ERROR"
		exit 1
	}
}

# スクリプト実行
Main
