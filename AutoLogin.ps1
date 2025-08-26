# ============================================================================
# 自動ログイン設定管理スクリプト
# Windows Kitting Workflow用自動ログイン設定の作成と削除
# workflow.jsonのパラメータまたは対話入力で設定を管理
# ============================================================================

param(
	[ValidateSet("Setup", "Remove")]
	[string]$Action = "Setup",

	[string]$Username,

	[string]$Password,

	[string]$Domain = "",

	[string]$ConfigPath = "",

	[switch]$Force
)

# 共通ログ関数の読み込み
. (Join-Path $PSScriptRoot "scripts\Common-LogFunctions.ps1")

# 自動ログイン設定のデフォルト値を取得
function Get-AutoLoginDefaults {
	return @{
		autoLogonCount      = 999
		forcePasswordPrompt = $false
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

		$passwordSpecified = $PSBoundParameters.ContainsKey('Password')

		if (-not $Username -or -not $passwordSpecified) {
			$userInfo = Get-CurrentUserInfo

			if (-not $Username) {
				$Username = $userInfo.Username
				Write-Log "現在のユーザー名を使用します: $Username"
			}

			if (-not $Domain) {
				$Domain = $userInfo.Domain
				Write-Log "現在のドメインを使用します: $Domain"
			}

			if (-not $passwordSpecified) {
				Write-Log "パスワードが指定されていないため、対話入力で設定します"

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
						$password1 = $null
						$password2 = $null
					}
				} while ($true)

				$password1 = $null
				$password2 = $null
				$securePassword1 = $null
				$securePassword2 = $null
			}
		}

		if ($passwordSpecified -and $Password -eq "") {
			Write-Log "パスワードが空白として指定されました。パスワードなしで設定します" -Level "WARN"
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
		$defaults = Get-AutoLoginDefaults
		$autoLogonCount = $defaults.autoLogonCount
		Set-ItemProperty -Path $regPath -Name "AutoLogonCount" -Value $autoLogonCount -Type DWord

		Write-Log "自動ログイン設定が完了しました"
		# 完了マーカーは MainWorkflow 側で作成されます
		Write-Log "自動ログイン設定完了（マーカーはMainWorkflowが作成）"

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
		# 完了マーカーは MainWorkflow 側で作成されます
		Write-Log "自動ログイン解除完了（マーカーはMainWorkflowが作成）"

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

		# デフォルト設定を表示
		$defaults = Get-AutoLoginDefaults
		Write-Log "デフォルト設定:"
		Write-Log "  自動ログイン回数: $($defaults.autoLogonCount)"
		Write-Log "  強制パスワード入力: $($defaults.forcePasswordPrompt)"

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

	# 設定ディレクトリの作成
	$statusDir = Join-Path $PSScriptRoot "status"
	if (-not (Test-Path $statusDir)) {
		New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
	}

	# アクションに応じて処理実行
	switch ($Action) {
		"Setup" {
			# パラメータの確認
			Write-Log "自動ログイン設定のパラメータを確認します"
			# ConfigPath が指定されている場合、JSON から未指定項目を補完
			if ($ConfigPath) {
				try {
					$workflowRoot = $PSScriptRoot
					$fullConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $workflowRoot $ConfigPath }
					if (Test-Path $fullConfigPath) {
						$json = Get-Content -Path $fullConfigPath -Raw | ConvertFrom-Json
						if (-not $Username -and $json.UserName) {
							$Username = [string]$json.UserName
							Write-Log "ユーザー名をConfigPathから取得: $Username"
						}
						if (-not $PSBoundParameters.ContainsKey('Password') -and $null -ne $json.Password) {
							$Password = [string]$json.Password
							$PSBoundParameters['Password'] = $Password
							Write-Log "パスワードをConfigPathから取得"
						}
					}
					else {
						Write-Log "指定されたConfigPathが見つかりません: $fullConfigPath" -Level "WARN"
					}
				}
				catch {
					Write-Log "ConfigPath の読み込みに失敗しました: $($_.Exception.Message)" -Level "WARN"
				}
			}
			if ($Username) {
				Write-Log "ユーザー名が指定されています: $Username"
			}
			if ($PSBoundParameters.ContainsKey('Password')) { Write-Log "パスワードが指定されています" }
			if ($Domain) {
				Write-Log "ドメインが指定されています: $Domain"
			}
			if (-not $PSBoundParameters.ContainsKey('Password')) { Write-Log "パスワードが指定されていないため、対話入力で設定します" }

			# 現在の設定を表示
			Get-AutoLoginStatus

			if (-not $Force) {
				$confirmation = Read-Host "自動ログインを設定しますか？ (y/N)"
				if ($confirmation -ne "y" -and $confirmation -ne "Y") {
					Write-Log "自動ログイン設定をキャンセルしました"
					exit 0
				}
			}

			# 呼び出しパラメーターを準備（-Password は指定時のみ、未指定なら対話入力で取得）
			$setParams = @{}
			if ($Username) { $setParams.Username = $Username }
			if ($Domain) { $setParams.Domain = $Domain }

			if ($PSBoundParameters.ContainsKey('Password')) {
				# 明示的に指定された場合（空文字はパスワードなしとしてそのまま渡す）
				$setParams.Password = $Password
			}
			else {
				# 未指定の場合はプロンプトで入力
				do {
					$securePassword1 = Read-Host "パスワードを入力してください (${Username})" -AsSecureString
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
						$password1 = $null
						$password2 = $null
					}
				} while ($true)

				$password1 = $null
				$password2 = $null
				$securePassword1 = $null
				$securePassword2 = $null

				$setParams.Password = $Password
			}

			$success = Set-AutoLogin @setParams
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
