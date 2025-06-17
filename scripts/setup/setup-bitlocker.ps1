# ============================================================================
# BitLocker設定スクリプト
# システムドライブのBitLocker暗号化を設定
# ============================================================================

param(
	[switch]$EnablePIN,
	[string]$PINCode,
	[switch]$Force,
	[switch]$DryRun,
	[switch]$NotifyRecoveryPassword
)

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")
# 共通通知関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-NotificationFunctions.ps1")

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
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

# BitLockerポリシー設定（PIN使用時）
function Set-BitLockerPolicy {
	param(
		[bool]$EnablePIN = $false
	)

	try {
		Write-Log "BitLockerポリシーを設定中..."

		# レジストリパスの作成
		$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
		if (-not (Test-Path -LiteralPath $registryPath)) {
			New-Item $registryPath -Force | Out-Null
			Write-Log "BitLockerポリシーレジストリキーを作成しました"
		}

		if ($EnablePIN) {
			# 基本ポリシー設定
			New-ItemProperty -LiteralPath $registryPath -Name "EnableBDEWithNoTPM" -PropertyType "DWord" -Value "1" -Force | Out-Null
			New-ItemProperty -LiteralPath $registryPath -Name "UseAdvancedStartup" -PropertyType "DWord" -Value "1" -Force | Out-Null
			New-ItemProperty -LiteralPath $registryPath -Name "UseTPM" -PropertyType "DWord" -Value "2" -Force | Out-Null
			New-ItemProperty -LiteralPath $registryPath -Name "UseTPMKey" -PropertyType "DWord" -Value "0" -Force | Out-Null
			New-ItemProperty -LiteralPath $registryPath -Name "UseTPMKeyPIN" -PropertyType "DWord" -Value "0" -Force | Out-Null
			# PIN使用を許可
			New-ItemProperty -LiteralPath $registryPath -Name "UseTPMPIN" -PropertyType "DWord" -Value "2" -Force | Out-Null
			# スタートアップの拡張 PIN を許可する
			New-ItemProperty -LiteralPath $registryPath -Name "UseEnhancedPin" -PropertyType "DWord" -Value "1" -Force | Out-Null
			Write-Log "✅ BitLocker PIN使用ポリシーを設定しました"
		}

		return $true
	}
	catch {
		Write-Log "BitLockerポリシー設定中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# BitLocker通知送信（共通ライブラリ使用）
function Send-BitLockerNotification {
	param(
		[string]$Message,
		[bool]$RequiresUserAction = $false
	)

	try {
		# 通知設定を初期化
		$notificationConfigPath = Get-WorkflowPath -PathType "Config" -SubPath "notifications.json"
		if (-not (Import-NotificationConfig -ConfigPath $notificationConfigPath)) {
			Write-Log "通知設定の読み込みに失敗しました" -Level "WARN"
			return $false
		}

		$title = if ($RequiresUserAction) {
			"🔐 BitLocker設定 - ユーザー対応が必要"
		}
		else {
			"🔐 BitLocker設定完了"
		}

		$fullMessage = "$title`n$Message"

		# 共通通知関数を使用してSlackとTeams両方に送信
		$result = Send-Notification -EventType "onBitLockerComplete" -CustomMessage $fullMessage

		if ($result) {
			Write-Log "BitLocker通知を送信しました" -Level "DEBUG"
		}
		else {
			Write-Log "BitLocker通知の送信に失敗しました" -Level "WARN"
		}

		return $result
	}
	catch {
		Write-Log "BitLocker通知送信中にエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
		return $false
	}
}

# BitLocker有効化
function Enable-BitLockerEncryption {
	param(
		[string]$Drive = "C:",
		[bool]$UsePIN = $false,
		[string]$PIN = ""
	)
	try {
		Write-Log "BitLocker暗号化を設定中 (ドライブ: $Drive)..."

		if ($DryRun) {
			Write-Log "[DRY RUN] BitLocker設定をシミュレーション中..."
			Write-Log "[DRY RUN] ドライブ: $Drive"
			Write-Log "[DRY RUN] PIN使用: $UsePIN"
			Write-Log "[DRY RUN] PINコード長: $($PIN.Length)文字"
			return $true
		}
		# 現在のBitLocker状態を確認
		$currentBLV = Get-BitLockerVolume -MountPoint $Drive -ErrorAction SilentlyContinue

		Write-Log "現在の状態:"
		if ($currentBLV) {
			Write-Log "  保護状態: $($currentBLV.ProtectionStatus)"
			Write-Log "  暗号化率: $($currentBLV.EncryptionPercentage)%"
		}
		else {
			Write-Log "  BitLockerが設定されていません"
		}

		# 回復キーの保存先を設定
		$recoveryKeyPath = Get-WorkflowPath -PathType "Backup" -SubPath "bitlocker-recovery-keys"
		if (-not (Test-Path $recoveryKeyPath)) {
			New-Item -ItemType Directory -Path $recoveryKeyPath -Force | Out-Null
		}

		$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
		$recoveryKeyFile = Join-Path $recoveryKeyPath "bitlocker-recovery-key-$timestamp.txt"

		# BitLockerポリシー設定
		if (-not (Set-BitLockerPolicy -EnablePIN $UsePIN)) {
			Write-Log "BitLockerポリシー設定に失敗しました" -Level "ERROR"
			return $false
		}

		# 既存の回復パスワードキープロテクターを削除（参考コードより）
		if ($currentBLV -and $currentBLV.KeyProtector) {
			Write-Log "既存の回復パスワードキープロテクターを確認中..."
			foreach ($kp in $currentBLV.KeyProtector) {
				if ($kp.KeyProtectorType -eq "RecoveryPassword") {
					Write-Log "既存の回復パスワードキープロテクターを削除: $($kp.KeyProtectorId)"
					Remove-BitLockerKeyProtector -MountPoint $Drive -KeyProtectorId $kp.KeyProtectorId -Confirm:$false
				}
			}
		}

		# 回復パスワードを設定（参考コードより）
		Write-Log "新しい回復パスワードキープロテクターを追加中..."
		Add-BitLockerKeyProtector -MountPoint $Drive -RecoveryPasswordProtector | Out-Null

		# TPMキープロテクターの確認と追加（参考コードより）
		$updatedBLV = Get-BitLockerVolume -MountPoint $Drive
		$tpmKP = $updatedBLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
		if (-not $tpmKP) {
			Write-Log "TPMキープロテクターを追加中..."
			Add-BitLockerKeyProtector -MountPoint $Drive -TpmProtector | Out-Null
		}
		else {
			Write-Log "TPMキープロテクターは既に存在します"
		}
		if ($UsePIN) {
			# PIN使用の場合（参考コードより）
			Write-Log "PIN付きBitLockerを有効化中..."

			if ([string]::IsNullOrEmpty($PIN)) {
				Write-Log "PINコードが指定されていません。デフォルトPINを使用します" -Level "WARN"
				$PIN = "123456"  # デフォルトPIN
			}

			# PINコードを安全な文字列に変換
			$securePin = ConvertTo-SecureString -String $PIN -AsPlainText -Force

			# TPMの存在確認（参考コードより）
			$tpm = Get-Tpm
			if ($tpm.TpmPresent) {
				# TPM + PIN保護でBitLockerを有効化
				Enable-BitLocker -MountPoint $Drive -TpmAndPinProtector $securePin -UsedSpaceOnly -SkipHardwareTest
				Write-Log "✅ TPM + PIN保護でBitLockerを有効化しました"
			}
			else {
				# TPMがない場合はPasswordProtectorで有効化（参考コードより）
				Write-Log "TPMが利用できないため、パスワード保護で有効化中..."
				Enable-BitLocker -MountPoint $Drive -PasswordProtector $securePin -UsedSpaceOnly -SkipHardwareTest
				Write-Log "✅ パスワード保護でBitLockerを有効化しました"
			}
			Write-Log "PINコード: $('*' * $PIN.Length) (マスク表示)"

		}
		else {
			# PIN使用なしの場合（参考コードより manage-bde を使用）
			Write-Log "PIN入力なしでBitLockerを有効化中..."
			# manage-bdeコマンドを使用（参考コードより）
			& manage-bde -on $Drive -skiphardwaretest | Out-Null
			if ($LASTEXITCODE -eq 0) {
				Write-Log "✅ manage-bdeでBitLockerを有効化しました"
			}
			else {
				Write-Log "manage-bdeでの有効化に失敗しました。PowerShellコマンドレットで再試行..." -Level "WARN"
				Enable-BitLocker -MountPoint $Drive -TpmProtector -UsedSpaceOnly -SkipHardwareTest
				Write-Log "✅ TPM保護でBitLockerを有効化しました"
			}
  }

		# 回復キーをファイルに保存と通知準備（参考コードを基に改良）
		$finalBLV = Get-BitLockerVolume -MountPoint $Drive
		$recoveryKeys = $finalBLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

		if ($recoveryKeys) {
			# プロテクタIDと回復パスワードを取得（参考コードより）
			$kpid = ($finalBLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId | Out-String
			$rp = ($finalBLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword | Out-String

			$recoveryInfo = @"
BitLocker Recovery Key Information
==================================
Computer Name: $env:COMPUTERNAME
Drive: $Drive
Date: $(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')
Recovery Keys:

"@
			foreach ($key in $recoveryKeys) {
				$recoveryInfo += "Recovery Key ID: $($key.KeyProtectorId)`n"
				$recoveryInfo += "Recovery Password: $($key.RecoveryPassword)`n`n"
			}

			$recoveryInfo += @"
Important: Store this recovery key in a safe location!
==================================
"@
			$recoveryInfo | Out-File -FilePath $recoveryKeyFile -Encoding UTF8
			Write-Log "回復キーを保存しました: $recoveryKeyFile"

			# 全キープロテクター情報もファイルに保存
			$allKeysFile = Join-Path $recoveryKeyPath "bitlocker-all-keys-$timestamp.txt"
			$finalBLV.KeyProtector | Out-File -FilePath $allKeysFile -Encoding UTF8
			Write-Log "全キープロテクター情報を保存しました: $allKeysFile"

			# 通知メッセージを作成
			if ($NotifyRecoveryPassword) {
				# 回復パスワードを含む詳細通知
				$notificationMessage = "[$env:COMPUTERNAME] BitLocker設定完了`r`nプロテクタID: $kpid`r`n回復パスワード: $rp`r`nバックアップファイル: $recoveryKeyFile"
			}
			else {
				# バックアップファイルパスのみ通知
				$notificationMessage = "[$env:COMPUTERNAME] BitLocker設定完了`r`n回復パスワードはファイルに保存されました`r`nバックアップファイル: $recoveryKeyFile"
			}

			# 通知送信
			if ($UsePIN) {
				Send-BitLockerNotification -Message $notificationMessage -RequiresUserAction $false
			}
			else {
				Send-BitLockerNotification -Message $notificationMessage -RequiresUserAction $false
			}
		}
		# 暗号化状況を確認
		$bitlockerStatus = Get-BitLockerVolume -MountPoint $Drive
		Write-Log "暗号化状況: $($bitlockerStatus.EncryptionPercentage)% 完了"
		Write-Log "保護状態: $($bitlockerStatus.ProtectionStatus)"
		Write-Log "暗号化方法: $($bitlockerStatus.EncryptionMethod)"

		# 保護状態の確認
		if ($bitlockerStatus.ProtectionStatus -eq "On") {
			Write-Log "✅ BitLocker保護が正常に有効です"
		}
		elseif ($bitlockerStatus.ProtectionStatus -eq "Suspended") {
			Write-Log "⚠️ BitLocker保護が一時停止されています。再開を試行中..." -Level "WARN"
			Resume-BitLocker -MountPoint $Drive
			Start-Sleep -Seconds 3
			$finalStatus = Get-BitLockerVolume -MountPoint $Drive
			Write-Log "保護状態を更新: $($finalStatus.ProtectionStatus)"
		}

		Write-Log "✅ BitLocker設定が完了しました"
		return $true

	}
	catch {
		Write-Log "BitLocker有効化中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		Write-Log "エラー詳細: $($_.Exception.ToString())" -Level "ERROR"
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
		Write-Log "回復パスワード通知: $NotifyRecoveryPassword"

		# パラメータバリデーション
		if ($EnablePIN -and [string]::IsNullOrWhiteSpace($PINCode)) {
			Write-Log "EnablePINが有効ですが、PINCodeが設定されていません" -Level "ERROR"
			Write-Log "PINコードを設定するか、EnablePINを無効にしてください" -Level "ERROR"
			Send-WorkflowNotification -Message "BitLocker設定エラー: PINコードが未設定" -Title "設定エラー" -Level "Error"
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
		$result = Enable-BitLockerEncryption -Drive $systemDrive -UsePIN $EnablePIN.IsPresent -PIN $PINCode

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
