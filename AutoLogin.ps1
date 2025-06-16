# ============================================================================
# 自動ログイン設定管理スクリプト
# Windows Kitting Workflow用自動ログイン設定の作成と削除
# ============================================================================

param(
	[ValidateSet("Setup", "Remove")]
	[string]$Action = "Setup",

	[string]$Username,

	[string]$Password,

	[string]$Domain = "",

	[switch]$Force
)

# 共通ログ関数の読み込み
. (Join-Path $PSScriptRoot "scripts\Common-LogFunctions.ps1")

# JSONファイルから自動ログイン設定を読み込む
function Get-AutoLoginConfigFromJson {
	try {
		$configPath = Join-Path $PSScriptRoot "config\autologin.json"

		if (-not (Test-Path $configPath)) {
			Write-Log "設定ファイルが見つかりません: $configPath" -Level "WARN"
			return $null
		}

		$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

		if (-not $config.autologin) {
			Write-Log "設定ファイルに autologin セクションが見つかりません" -Level "WARN"
			return $null
		}

		return $config.autologin
	}
	catch {
		Write-Log "設定ファイルの読み込みでエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "AutoLogin" -LogFileName "autologin.log"
}

# 現在のユーザー情報取得
function Get-CurrentUserInfo {
	try {
		$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
		$username = $currentUser.Name

		if ($username -match "(.+)\\(.+)") {
			return @{
				Domain   = $matches[1]
				Username = $matches[2]
				FullName = $username
			}
		}
		else {
			return @{
				Domain   = $env:COMPUTERNAME
				Username = $username
				FullName = $username
			}
		}
	}
 catch {
		Write-Log "ユーザー情報の取得に失敗しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# 自動ログイン設定のセットアップ
function Set-AutoLogin {
	param(
		[string]$Username,
		[string]$Password,
		[string]$Domain
	)
	try {
		Write-Log "自動ログイン設定を開始します"

		# JSONファイルから設定を読み込む
		$config = Get-AutoLoginConfigFromJson

		# パラメータが指定されていない場合、JSONファイルまたは現在のユーザー情報を使用
		if (-not $Username -or -not $Password) {
			$userInfo = Get-CurrentUserInfo

			# JSONファイルからの設定を優先
			if ($config -and $config.credentials) {
				if (-not $Username -and $config.credentials.username) {
					$Username = $config.credentials.username
					Write-Log "JSONファイルからユーザー名を読み込みました: $Username"
				}

				if (-not $Password -and $config.credentials.password) {
					$Password = $config.credentials.password
					Write-Log "JSONファイルからパスワードを読み込みました"
				}

				if (-not $Domain -and $config.credentials.domain) {
					$Domain = $config.credentials.domain
					Write-Log "JSONファイルからドメインを読み込みました: $Domain"
				}
			}

			# まだ設定されていない場合は現在のユーザー情報を使用
			if (-not $Username) {
				$Username = $userInfo.Username
			}

			if (-not $Domain) {
				$Domain = $userInfo.Domain
			}

			# パスワードがまだ設定されていない場合は入力を求める
			if (-not $Password) {
				# forcePasswordPromptが設定されている場合は常に入力を求める
				$forcePrompt = $config -and $config.settings -and $config.settings.forcePasswordPrompt

				if ($forcePrompt) {
					Write-Log "設定により、パスワードの入力を求めます"
				}

				# パスワードの入力を求める（2回入力による確認）
				do {
					$securePassword1 = Read-Host "パスワードを入力してください ($Username)" -AsSecureString
					$securePassword2 = Read-Host "確認のため、パスワードを再度入力してください" -AsSecureString

					$password1 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword1))
					$password2 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword2))

					if ($password1 -eq $password2) {
						$Password = $password1
						Write-Log "パスワードが正常に設定されました"
						break
					}
					else {
						Write-Log "パスワードが一致しません。再度入力してください。" -Level "WARN"
						# セキュリティのため変数をクリア
						$password1 = $null
						$password2 = $null
					}
				} while ($true)

				# セキュリティのため一時変数をクリア
				$password1 = $null
				$password2 = $null
				$securePassword1 = $null
				$securePassword2 = $null
			}
		}

		Write-Log "ユーザー: $Domain\$Username"

		# レジストリキーのパス
		$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

		# 既存の設定をバックアップ
		$backupPath = Join-Path $PSScriptRoot "status\autologin-backup.json"
		$backup = @{}

		try {
			$backup.AutoAdminLogon = Get-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AutoAdminLogon
			$backup.DefaultUserName = Get-ItemProperty -Path $regPath -Name "DefaultUserName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DefaultUserName
			$backup.DefaultDomainName = Get-ItemProperty -Path $regPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DefaultDomainName
			$backup.DefaultPassword = Get-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DefaultPassword
		}
		catch {
			# バックアップできない項目は無視
		}

		$backup | ConvertTo-Json | Out-File -FilePath $backupPath -Encoding UTF8
		Write-Log "既存設定をバックアップしました: $backupPath"

		# 自動ログイン設定
		Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "1" -Type String
		Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $Username -Type String
		Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $Password -Type String

		if ($Domain) {
			Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $Domain -Type String
		}
		# セキュリティ設定：自動ログイン回数を設定
		$autoLogonCount = 999
		if ($config -and $config.settings -and $config.settings.autoLogonCount) {
			$autoLogonCount = $config.settings.autoLogonCount
		}
		Set-ItemProperty -Path $regPath -Name "AutoLogonCount" -Value $autoLogonCount -Type DWord

		Write-Log "自動ログイン設定が完了しました"

		# 完了マーカー作成
		$completionMarker = Join-Path $PSScriptRoot "status\autologin-setup.completed"
		@{
			username  = $Username
			domain    = $Domain
			setupTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

		return $true

	}
 catch {
		Write-Log "自動ログイン設定でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# 自動ログイン設定の削除
function Remove-AutoLogin {
	try {
		Write-Log "自動ログイン設定を削除します"

		$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

		# バックアップファイルの確認
		$backupPath = Join-Path $PSScriptRoot "status\autologin-backup.json"

		if (Test-Path $backupPath) {
			try {
				$backup = Get-Content $backupPath -Raw | ConvertFrom-Json
				Write-Log "バックアップファイルから設定を復元します"

				# バックアップから復元
				if ($backup.AutoAdminLogon) {
					Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value $backup.AutoAdminLogon -Type String
				}
				else {
					Remove-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue
				}

				if ($backup.DefaultUserName) {
					Set-ItemProperty -Path $regPath -Name "DefaultUserName" -Value $backup.DefaultUserName -Type String
				}
				else {
					Remove-ItemProperty -Path $regPath -Name "DefaultUserName" -ErrorAction SilentlyContinue
				}

				if ($backup.DefaultDomainName) {
					Set-ItemProperty -Path $regPath -Name "DefaultDomainName" -Value $backup.DefaultDomainName -Type String
				}
				else {
					Remove-ItemProperty -Path $regPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue
				}

				if ($backup.DefaultPassword) {
					Set-ItemProperty -Path $regPath -Name "DefaultPassword" -Value $backup.DefaultPassword -Type String
				}
				else {
					Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
				}

				# バックアップファイルを削除
				Remove-Item $backupPath -Force
				Write-Log "バックアップから設定を復元しました"

			}
			catch {
				Write-Log "バックアップからの復元に失敗しました。手動で設定を削除します" -Level "WARN"
			}
		}

		# 手動で設定を削除
		try {
			Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "0" -Type String
			Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
			Remove-ItemProperty -Path $regPath -Name "AutoLogonCount" -ErrorAction SilentlyContinue
		}
		catch {
			Write-Log "レジストリ設定の削除で一部エラーが発生しました: $($_.Exception.Message)" -Level "WARN"
		}

		Write-Log "自動ログイン設定を削除しました"

		# 完了マーカー作成
		$completionMarker = Join-Path $PSScriptRoot "status\autologin-cleanup.completed"
		@{
			removedTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

		return $true

	}
 catch {
		Write-Log "自動ログイン設定の削除でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# 現在の自動ログイン設定を表示
function Get-AutoLoginStatus {
	try {
		$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

		$autoLogon = Get-ItemProperty -Path $regPath -Name "AutoAdminLogon" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AutoAdminLogon
		$username = Get-ItemProperty -Path $regPath -Name "DefaultUserName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DefaultUserName
		$domain = Get-ItemProperty -Path $regPath -Name "DefaultDomainName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DefaultDomainName
		$count = Get-ItemProperty -Path $regPath -Name "AutoLogonCount" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AutoLogonCount

		Write-Log "現在の自動ログイン設定:"
		Write-Log "  有効: $autoLogon"
		Write-Log "  ユーザー: $username"
		Write-Log "  ドメイン: $domain"
		Write-Log "  残り回数: $count"

		# JSONファイルの設定も表示
		$config = Get-AutoLoginConfigFromJson
		if ($config) {
			Write-Log "JSONファイルの設定:"
			Write-Log "  有効: $($config.enabled)"
			if ($config.credentials.username) {
				Write-Log "  設定ユーザー: $($config.credentials.username)"
			}
			if ($config.credentials.password) {
				Write-Log "  パスワード: 設定済み"
			}
			else {
				Write-Log "  パスワード: 未設定（実行時入力）"
			}
			if ($config.credentials.domain) {
				Write-Log "  設定ドメイン: $($config.credentials.domain)"
			}
			if ($config.settings) {
				Write-Log "  自動ログイン回数: $($config.settings.autoLogonCount)"
				Write-Log "  強制パスワード入力: $($config.settings.forcePasswordPrompt)"
			}
		}

	}
 catch {
		Write-Log "自動ログイン設定の確認でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	}
}

# 管理者権限チェック
function Test-AdminRights {
	$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 設定ファイルの初期化
function Initialize-AutoLoginConfig {
	try {
		$configPath = Join-Path $PSScriptRoot "config\autologin.json"

		if (-not (Test-Path $configPath)) {
			$configDir = Split-Path $configPath -Parent
			if (-not (Test-Path $configDir)) {
				New-Item -ItemType Directory -Path $configDir -Force | Out-Null
			}

			$defaultConfig = @{
				autologin = @{
					enabled     = $true
					credentials = @{
						username = ""
						password = ""
						domain   = ""
					}
					settings    = @{
						autoLogonCount      = 999
						forcePasswordPrompt = $false
						description         = "自動ログイン設定。username/passwordが空の場合は実行時に入力を求めます。"
					}
				}
			}

			$defaultConfig | ConvertTo-Json -Depth 3 | Out-File -FilePath $configPath -Encoding UTF8
			Write-Log "デフォルトの設定ファイルを作成しました: $configPath"
		}
	}
	catch {
		Write-Log "設定ファイルの初期化でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	}
}

# メイン処理
try {
	Write-Log "自動ログイン管理スクリプトを開始します"
	Write-Log "アクション: $Action"

	# 管理者権限チェック
	if (-not (Test-AdminRights)) {
		Write-Log "このスクリプトは管理者権限で実行する必要があります" -Level "ERROR"
		exit 1
	}    # ログディレクトリ作成
	$logsDir = Join-Path $PSScriptRoot "logs"
	$statusDir = Join-Path $PSScriptRoot "status"

	@($logsDir, $statusDir) | ForEach-Object {
		if (-not (Test-Path $_)) {
			New-Item -ItemType Directory -Path $_ -Force | Out-Null
		}
	}

	# 設定ファイルの初期化
	Initialize-AutoLoginConfig

	# アクションに応じて処理実行
	switch ($Action) {
		"Setup" {
			# JSONファイルからの設定を確認
			$config = Get-AutoLoginConfigFromJson
			if ($config) {
				Write-Log "自動ログイン設定ファイルから設定を読み込みました"
				if ($config.credentials.username) {
					Write-Log "設定ファイルにユーザー名が設定されています: $($config.credentials.username)"
				}
				if ($config.credentials.password) {
					Write-Log "設定ファイルにパスワードが設定されています"
				}
				if ($config.credentials.domain) {
					Write-Log "設定ファイルにドメインが設定されています: $($config.credentials.domain)"
				}
			}
			else {
				Write-Log "設定ファイルが見つからないか、読み込みに失敗しました。パラメータまたは対話入力を使用します"
			}

			# 現在の設定を表示
			Get-AutoLoginStatus

			if (-not $Force) {
				$confirmation = Read-Host "自動ログインを設定しますか？ (y/N)"
				if ($confirmation -ne "y" -and $confirmation -ne "Y") {
					Write-Log "自動ログイン設定をキャンセルしました"
					exit 0
				}
			}

			$success = Set-AutoLogin -Username $Username -Password $Password -Domain $Domain
			if ($success) {
				Write-Log "自動ログイン設定が正常に完了しました"
				exit 0
			}
			else {
				Write-Log "自動ログイン設定に失敗しました" -Level "ERROR"
				exit 1
			}
		}

		"Remove" {
			# 現在の設定を表示
			Get-AutoLoginStatus

			if (-not $Force) {
				$confirmation = Read-Host "自動ログイン設定を削除しますか？ (y/N)"
				if ($confirmation -ne "y" -and $confirmation -ne "Y") {
					Write-Log "自動ログイン設定削除をキャンセルしました"
					exit 0
				}
			}

			$success = Remove-AutoLogin
			if ($success) {
				Write-Log "自動ログイン設定の削除が正常に完了しました"
				exit 0
			}
			else {
				Write-Log "自動ログイン設定の削除に失敗しました" -Level "ERROR"
				exit 1
			}
		}

		default {
			Write-Log "不明なアクション: $Action" -Level "ERROR"
			exit 1
		}
	}

}
catch {
	Write-Log "スクリプト実行中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	exit 1
}
