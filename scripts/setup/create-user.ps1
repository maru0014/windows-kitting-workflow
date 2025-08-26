# ユーザー作成スクリプト
param(
	[string]$UserName = "",
	[string]$Password = "",
	[string[]]$Groups = @("Administrators"),
	[string]$ConfigPath = "config\local_user.json",
	[switch]$Help
)

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "CreateUser" -LogFileName "create-user.log"
}

# ヘルプ表示
if ($Help) {
	Write-Host @"
ローカルユーザー作成スクリプト

使用方法:
    .\create-user.ps1 [-UserName <name>] [-Password <password>] [-Groups <g1,g2,...>] [-ConfigPath <path>]

挙動:
    - 引数で UserName / Password / Groups が指定された場合は最優先
    - それ以外の場合は local_user.json（ConfigPath）を参照
    - いずれも無い場合はエラーで終了

例:
    # JSON に従って作成
    .\create-user.ps1

    # 直接指定して作成
    .\create-user.ps1 -UserName user001 -Password User1234 -Groups "Administrators","Users"

"@ -ForegroundColor Cyan
	exit 0
}

function Test-IsAdministrator {
	try {
		$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
		$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
		return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	catch {
		Write-Log "権限確認に失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

function Get-SerialNumber {
	try {
		$serial = (Get-WmiObject -Class Win32_SystemEnclosure -ErrorAction SilentlyContinue).SerialNumber
		if ([string]::IsNullOrWhiteSpace($serial)) {
			$serial = (Get-WmiObject -Class Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber
		}
		return $serial.Trim()
	}
	catch {
		Write-Log "シリアル番号の取得に失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

function Import-MachineList {
	param([string]$CsvPath)

	try {
		if (-not (Test-Path $CsvPath)) {
			Write-Log "機器リストファイルが見つかりません: $CsvPath" -Level "ERROR"
			return $null
		}

		$machines = Import-Csv $CsvPath
		Write-Log "機器リスト読み込み完了: $($machines.Count)台"
		return $machines
	}
	catch {
		Write-Log "機器リストの読み込みに失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

function Find-MachineBySerial {
	param(
		[array]$MachineList,
		[string]$SerialNumber
	)

	foreach ($m in $MachineList) {
		if ($m."Serial Number" -eq $SerialNumber) {
			return $m
		}
	}
	return $null
}

function Resolve-UserCredential {
	param(
		[string]$ParamUserName,
		[string]$ParamPassword,
		[string]$JsonPath
	)

	if (-not [string]::IsNullOrWhiteSpace($ParamUserName) -and -not [string]::IsNullOrWhiteSpace($ParamPassword)) {
		return [PSCustomObject]@{ UserName = $ParamUserName; Password = $ParamPassword; Source = "Parameter" }
	}

	try {
		if (-not (Test-Path $JsonPath)) {
			Write-Log "ユーザー設定ファイルが見つかりません: $JsonPath" -Level "WARN"
			return $null
		}

		$json = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
		$jsonUser = $json.UserName
		$jsonPass = $json.Password

		if ([string]::IsNullOrWhiteSpace($jsonUser) -or [string]::IsNullOrWhiteSpace($jsonPass)) {
			Write-Log "local_user.json にユーザー名またはパスワードが定義されていません" -Level "WARN"
			return $null
		}

		return [PSCustomObject]@{ UserName = $jsonUser; Password = $jsonPass; Source = "JSON" }
	}
	catch {
		Write-Log "local_user.json の読み込み/解析に失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

function Set-LocalUserAccount {
	param(
		[string]$Name,
		[securestring]$Password
	)

	try {
		$existing = Get-LocalUser -Name $Name -ErrorAction SilentlyContinue

		if ($null -ne $existing) {
			Write-Log "既存ユーザーを更新します: $Name"
			try {
				$existing | Enable-LocalUser -ErrorAction SilentlyContinue | Out-Null
			}
			catch {}
			Set-LocalUser -Name $Name -Password $Password -ErrorAction Stop
			return $true
		}
		else {
			Write-Log "新規ローカルユーザーを作成します: $Name"
			New-LocalUser -Name $Name -Password $Password -FullName $Name -Description "Windows Kitting Workflow user" -ErrorAction Stop | Out-Null
			return $true
		}
	}
	catch {
		Write-Log "ユーザー作成/更新に失敗しました: $Name - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

function Get-NormalizedGroupName {
	param([string]$Group)

	if ($Group -ieq "Administrator") { return "Administrators" }
	return $Group
}

function Add-UserToGroups {
	param(
		[string]$UserName,
		[string[]]$TargetGroups
	)

	$ok = $true
	foreach ($g in $TargetGroups) {
		$groupName = Get-NormalizedGroupName -Group $g
		try {
			$exists = Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue
			if (-not $exists) {
				Write-Log "ローカルグループが見つかりません: $groupName" -Level "ERROR"
				$ok = $false; continue
			}

			# 既にメンバーか確認
			$member = Get-LocalGroupMember -Group $groupName -Member $UserName -ErrorAction SilentlyContinue
			if ($member) {
				Write-Log "既にグループ所属済み: $UserName -> $groupName"
				continue
			}

			Write-Log "グループに追加: $UserName -> $groupName"
			Add-LocalGroupMember -Group $groupName -Member $UserName -ErrorAction Stop
		}
		catch {
			Write-Log "グループ追加に失敗しました: $UserName -> $groupName - $($_.Exception.Message)" -Level "ERROR"
			$ok = $false
		}
	}
	return $ok
}

function Write-CompletionMarker {
	param(
		[string]$UserName,
		[string[]]$Groups,
		[string]$Source,
		[bool]$Skipped = $false
	)
	# 完了マーカーは MainWorkflow 側で集中管理されます（ここでは何もしません）
}

# メイン処理
try {
	Write-Log "=== ユーザー作成処理開始 ==="

	if (-not (Test-IsAdministrator)) {
		Write-Log "管理者として実行されていません。管理者権限で再実行してください。" -Level "ERROR"
		exit 1
	}

	# ワークフローのルートから設定パスを解決
	$workflowRoot = Get-WorkflowRoot
	$fullConfigPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $workflowRoot $ConfigPath }

	# 資格情報の決定（引数優先 → local_user.json）
	$cred = Resolve-UserCredential -ParamUserName $UserName -ParamPassword $Password -JsonPath $fullConfigPath
	if (-not $cred) {
		Write-Log "ユーザー情報が見つからないためエラーで終了します（引数または local_user.json を指定してください）" -Level "ERROR"
		exit 1
	}
	Write-Log "資格情報ソース: $($cred.Source)"
	Write-Log "対象ユーザー: $($cred.UserName)"

	if ([string]::IsNullOrWhiteSpace($cred.Password)) {
		Write-Log "パスワードが空のためスキップします" -Level "WARN"
		# 完了マーカーはMainWorkflow側で作成されます（詳細はログ/通知をご確認ください）
		exit 0
	}

	# ユーザー作成/更新
	$secure = ConvertTo-SecureString $cred.Password -AsPlainText -Force
	$userOk = Set-LocalUserAccount -Name $cred.UserName -Password $secure
	if (-not $userOk) { Write-Log "ユーザーの作成/更新に失敗しました" -Level "ERROR"; exit 1 }

	# グループ決定（引数優先 → local_user.json、無ければエラー）
	$jsonForGroups = $null
	try {
		if (-not $PSBoundParameters.ContainsKey("Groups") -and (Test-Path $fullConfigPath)) {
			$jsonForGroups = Get-Content -Path $fullConfigPath -Raw | ConvertFrom-Json
		}
	}
	catch { Write-Log "local_user.json の読み込み/解析に失敗しました（Groups判定）: $($_.Exception.Message)" -Level "WARN" }

	$targetGroups = @()
	if ($PSBoundParameters.ContainsKey("Groups") -and $Groups -and $Groups.Count -gt 0) {
		$targetGroups = $Groups | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
		Write-Log "グループソース: Parameter"
	}
	elseif ($jsonForGroups -and $jsonForGroups.Groups -and $jsonForGroups.Groups.Count -gt 0) {
		$targetGroups = @($jsonForGroups.Groups) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
		Write-Log "グループソース: JSON"
	}
	else {
		Write-Log "グループが指定されていません（引数または local_user.json の Groups を指定してください）" -Level "ERROR"
		exit 1
	}

	$groupOk = Add-UserToGroups -UserName $cred.UserName -TargetGroups $targetGroups
	if (-not $groupOk) { Write-Log "一部グループへの追加に失敗しました" -Level "WARN" }

	# 完了マーカーはMainWorkflow側で作成されます（詳細はログ/通知をご確認ください）

	Write-Log "=== ユーザー作成処理完了 ==="
	exit 0
}
catch {
	Write-Log "致命的なエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	Write-Log "スタックトレース: $($_.ScriptStackTrace)" -Level "ERROR"
	exit 1
}
