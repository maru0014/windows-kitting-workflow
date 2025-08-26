# ============================================================================
# ローカルユーザー削除スクリプト
# 指定したユーザーが現在のログインユーザーと異なることを確認し、
# ローカルユーザーおよびそのユーザープロファイルを削除します
# ============================================================================

param(
	[Parameter(Mandatory = $true, Position = 0)]
	[string]$UserName,

	[switch]$Force,
	[switch]$Help
)

if ($Help) {
	Write-Host @"
ローカルユーザー削除スクリプト

使用方法:
    .\remove-user.ps1 -UserName <name> [-Force]

説明:
    - 指定ユーザーが現在のログインユーザーと同一でないことを確認します
    - ローカルユーザーを削除します（存在する場合）
    - 対応するユーザープロファイルも削除します
    - -Force 指定時はログオン中セッションがあっても続行を試みます
"@
	exit 0
}

# 共通ログ関数/ヘルパー読込
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

$ScriptName = "RemoveUser"

function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName $ScriptName -LogFileName "remove-user.log"
}

function Test-IsAdministrator {
	try {
		$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
		$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
		return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	catch {
		return $false
	}
}

function Test-UserLoggedOn {
	param([string]$TargetUser)
	try {
		# quser が利用可能ならセッション一覧から検出
		$quser = (Get-Command quser -ErrorAction SilentlyContinue)
		if ($quser) {
			$result = (& quser 2>$null)
			if ($LASTEXITCODE -eq 0 -and $result) {
				return $null -ne ($result | Select-String -Pattern "^\s*${TargetUser}\b" -CaseSensitive:$false)
			}
		}
	}
	catch { }

	try {
		# フォールバック: WMI でログオンユーザーを確認
		$loggedOn = Get-CimInstance Win32_LoggedOnUser -ErrorAction SilentlyContinue
		if ($loggedOn) {
			foreach ($entry in $loggedOn) {
				$account = $entry.Antecedent.ToString()
				# Antecedent 例: Win32_Account.Domain="MACHINE",Name="User"
				if ($account -match 'Name="([^"]+)"') {
					$name = $Matches[1]
					if ($name -and $name.Equals($TargetUser, 'InvariantCultureIgnoreCase')) {
						return $true
					}
				}
			}
		}
	}
	catch { }

	return $false
}

function Remove-LocalUserIfExists {
	param([string]$Name)
	try {
		$localUser = Get-LocalUser -Name $Name -ErrorAction SilentlyContinue
		if ($null -eq $localUser) {
			Write-Log "ローカルユーザーは存在しません: $Name" -Level "WARN"
			return $false
		}

		Disable-LocalUser -Name $Name -ErrorAction SilentlyContinue | Out-Null
		Remove-LocalUser -Name $Name -ErrorAction Stop
		Write-Log "ローカルユーザーを削除しました: $Name"
		return $true
	}
	catch {
		Write-Log "ローカルユーザー削除に失敗しました: $Name - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

function Remove-UserProfileIfExists {
	param(
		[string]$Name
	)

	try {
		$profileRemoved = $false

		# まずローカルユーザーの SID を試行
		$sid = $null
		try {
			$u = Get-LocalUser -Name $Name -ErrorAction SilentlyContinue
			if ($u) { $sid = $u.SID.Value }
		}
		catch { }

		$profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue
		if ($profiles) {
			$targetProfiles = @()
			if ($sid) {
				$targetProfiles = $profiles | Where-Object { $_.SID -eq $sid }
			}

			if (-not $targetProfiles -or $targetProfiles.Count -eq 0) {
				# SID が取れない場合はパス末尾名で近似（安全のため Users 直下のみ）
				$targetProfiles = $profiles |
				Where-Object {
					$_.LocalPath -and $_.LocalPath -match "^$([regex]::Escape($env:SystemDrive))\\Users\\$([regex]::Escape($Name))$"
				}
			}

			foreach ($p in $targetProfiles) {
				if (-not $p.Special -and -not $p.RoamingConfigured) {
					# ログオン中のプロファイルは削除不可
					if ($p.Loaded) {
						Write-Log "プロファイルが使用中のため削除できません: $($p.LocalPath)" -Level "WARN"
						continue
					}
					$res = Invoke-CimMethod -InputObject $p -MethodName Delete -ErrorAction SilentlyContinue
					if ($res -and $res.ReturnValue -eq 0) {
						Write-Log "ユーザープロファイルを削除しました: $($p.LocalPath)"
						$profileRemoved = $true
					}
					else {
						Write-Log "ユーザープロファイルの削除に失敗しました: $($p.LocalPath) (ReturnValue=$($res.ReturnValue))" -Level "WARN"
					}
				}
			}
		}

		if (-not $profileRemoved) {
			# 追加のフォールバック: 既存ディレクトリの削除（最後の手段）
			$candidate = Join-Path (Join-Path $env:SystemDrive 'Users') $Name
			if (Test-Path $candidate) {
				try {
					Remove-Item -Path $candidate -Recurse -Force -ErrorAction Stop
					Write-Log "ユーザープロファイルフォルダを削除しました: $candidate"
					$profileRemoved = $true
				}
				catch {
					Write-Log "ユーザープロファイルフォルダ削除に失敗しました: $candidate - $($_.Exception.Message)" -Level "WARN"
				}
			}
		}

		return $profileRemoved
	}
	catch {
		Write-Log "ユーザープロファイル削除でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

try {
	Write-Log "ユーザー削除処理を開始します"

	# 権限確認
	if (-not (Test-IsAdministrator)) {
		Write-Log "管理者権限で実行してください" -Level "ERROR"
		exit 1
	}

	# ワークフローのルート解決（ログ出力先などのため）
	$null = Get-WorkflowRoot $PSScriptRoot

	# 現在ユーザーとの重複チェック
	$currentUser = $env:USERNAME
	if ($currentUser.Equals($UserName, 'InvariantCultureIgnoreCase')) {
		Write-Log "現在ログインしているユーザー自身は削除できません: $UserName" -Level "ERROR"
		exit 1
	}

	# 保護対象ユーザーのチェック（Administrator/Guestなど）
	$protectedUsers = @('Administrator', 'Guest', 'DefaultAccount', 'WDAGUtilityAccount')
	if ($protectedUsers -contains $UserName) {
		Write-Log "保護対象の組み込みアカウントは削除できません: $UserName" -Level "ERROR"
		exit 1
	}

	# ログオン中セッションの確認
	$isLoggedOn = Test-UserLoggedOn -TargetUser $UserName
	if ($isLoggedOn -and -not $Force) {
		Write-Log "対象ユーザーが現在ログオン中のため削除できません。-Force で強制実行可能です: $UserName" -Level "ERROR"
		exit 1
	}

	# ローカルユーザー削除
	$userRemoved = Remove-LocalUserIfExists -Name $UserName

	# プロファイル削除（ユーザー削除の成否に関わらず試行）
	$profileRemoved = Remove-UserProfileIfExists -Name $UserName

	if (-not $userRemoved -and -not $profileRemoved) {
		Write-Log "削除対象が見つからないか、削除できませんでした: $UserName" -Level "WARN"
	}

	# 完了マーカー
	Write-Log "ユーザー削除処理の完了（マーカーはMainWorkflowが作成）"

	Write-Log "ユーザー削除処理が完了しました (UserRemoved=$userRemoved, ProfileRemoved=$profileRemoved)"
	if ($userRemoved -or $profileRemoved) { exit 0 } else { exit 1 }
}
catch {
	Write-Log "ユーザー削除処理でエラー: $($_.Exception.Message)" -Level "ERROR"
	exit 1
}
