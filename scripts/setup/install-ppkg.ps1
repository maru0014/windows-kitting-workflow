# =============================================================================
# PPKG インストールスクリプト
# Provisioning Package (.ppkg) の検出・インストール・（任意）削除を行う
# =============================================================================

param(
	[string]$PackagePath = "",
	[switch]$Force,
	[switch]$RemoveExisting,
	[switch]$RemoveAfterInstall,
	[switch]$Help
)

# ヘルプ表示
if ($Help) {
	Write-Host @"
PPKG インストールスクリプト

使用方法:
    .\install-ppkg.ps1 [オプション]

パラメータ:
    -PackagePath <path>        インストールする PPKG ファイルのパス（相対/絶対いずれも可）
                               未指定時は config 配下から *.ppkg を探索（単一発見時に使用）

    -Force                     既存確認や一部の確認をスキップして強制実行（Add-ProvisioningPackage の ForceInstall）

    -RemoveExisting            同一 PackageId の既存インストールがある場合、事前に削除

    -RemoveAfterInstall        インストール直後に当該 PPKG を削除（サンプルの動作を再現したい場合）

    -Help                      このヘルプを表示

例:
    # config 配下に単一の .ppkg がある場合、そのファイルでインストール
    .\install-ppkg.ps1

    # 明示的なファイルを指定してインストール
    .\install-ppkg.ps1 -PackagePath "config\provisioning\device.ppkg"

    # 同一 PackageId が既にインストール済みなら削除してから再インストール
    .\install-ppkg.ps1 -PackagePath "D:\\packages\\corp.ppkg" -RemoveExisting

    # インストール後に削除（検証用途）
    .\install-ppkg.ps1 -PackagePath ".\\corp.ppkg" -RemoveAfterInstall
"@ -ForegroundColor Cyan
	exit 0
}

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

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "PPKG" -LogFileName "install-ppkg.log"
}

# 管理者権限チェック
function Test-IsAdministrator {
	try {
		$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
		$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
		return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	catch {
		Write-Log "管理者権限の確認でエラー: $($_.Exception.Message)" -Level "WARN"
		return $false
	}
}

# パス解決（相対→絶対、ディレクトリ指定時の自動検出、未指定時の config 配下探索）
function Resolve-PPKGPath {
	param([string]$InputPath)

	$workflowRoot = Get-WorkflowRoot

	# パス未指定 → config 配下から探索
	if (-not $InputPath) {
		$configRoot = Get-WorkflowPath -PathType "Config"
		$found = Get-ChildItem -Path $configRoot -Filter "*.ppkg" -Recurse -ErrorAction SilentlyContinue
		if (-not $found) {
			Write-Log "config 配下に .ppkg が見つかりません。-PackagePath で明示的に指定してください" -Level "ERROR"
			return $null
		}
		if ($found.Count -gt 1) {
			Write-Log "複数の .ppkg が見つかりました。-PackagePath でファイルを指定してください:" -Level "WARN"
			$found | Sort-Object FullName | ForEach-Object { Write-Log "  $_" }
			return $null
		}
		return $found[0].FullName
	}

	# 環境変数の展開
	$expanded = [Environment]::ExpandEnvironmentVariables($InputPath)

	# 相対パスならワークフルート基準に
	if (-not [System.IO.Path]::IsPathRooted($expanded)) {
		$expanded = Join-Path $workflowRoot $expanded
	}

	# ディレクトリが指定された場合は中から *.ppkg を探索
	if (Test-Path $expanded -PathType Container) {
		$ppkgs = Get-ChildItem -Path $expanded -Filter "*.ppkg" -ErrorAction SilentlyContinue
		if (-not $ppkgs) {
			Write-Log "指定ディレクトリに .ppkg が見つかりません: $expanded" -Level "ERROR"
			return $null
		}
		if ($ppkgs.Count -gt 1) {
			Write-Log "指定ディレクトリに複数の .ppkg が存在します。-PackagePath でファイルを特定してください: $expanded" -Level "WARN"
			$ppkgs | Sort-Object FullName | ForEach-Object { Write-Log "  $_" }
			return $null
		}
		return $ppkgs[0].FullName
	}

	# ファイル
	if (-not (Test-Path $expanded -PathType Leaf)) {
		Write-Log "PPKG ファイルが見つかりません: $expanded" -Level "ERROR"
		return $null
	}
	return $expanded
}

# PPKG 情報の取得
function Get-PPKGInfo {
	param([string]$PpkgPath)

	try {
		Write-Log "PPKG 情報を取得中: $PpkgPath"
		$info = Get-ProvisioningPackage -PackagePath $PpkgPath -ErrorAction Stop
		if ($info) {
			Write-Log "PackageName: $($info.PackageName)"
			Write-Log "PackageId  : $($info.PackageId)"
			Write-Log "Version    : $($info.Version)"
		}
		return $info
	}
	catch {
		Write-Log "PPKG 情報の取得に失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $null
	}
}

# 既存インストールの削除（PackageId 指定）
function Remove-PPKGById {
	param([string]$PackageId)

	try {
		if (-not $PackageId) { return $true }
		Write-Log "既存の PPKG を削除中: PackageId=$PackageId"
		Remove-ProvisioningPackage -PackageId $PackageId -ErrorAction Stop
		Write-Log "PPKG の削除に成功しました"
		return $true
	}
	catch {
		Write-Log "PPKG の削除に失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# PPKG のインストール
function Install-PPKG {
    param(
        [string]$PpkgPath,
        [switch]$ForceInstall
    )

	try {
		$logsDir = Get-WorkflowPath -PathType "Logs" -SubPath "ppkg"
		if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }

		Write-Log "PPKG をインストールします: $PpkgPath"
        $commonParams = @{
            Path         = $PpkgPath
            QuietInstall = $true
            ErrorAction  = 'Stop'
        }
        if ($logsDir) { $commonParams["LogsDirectoryPath"] = $logsDir }
        if ($ForceInstall.IsPresent) { $commonParams["ForceInstall"] = $true }

		$result = Add-ProvisioningPackage @commonParams

		# 結果の要約（可能であれば）
		if ($result) {
			# プロパティ名は環境により異なる可能性があるため、存在するものを出力
			$props = @("PackageId","Result","Status","RestartNeeded","Applied")
			foreach ($p in $props) { if ($result.PSObject.Properties[$p]) { Write-Log ("$($p): " + ($result.$p)) } }
		}

		Write-Log "PPKG のインストールが完了しました"
		return $true
	}
	catch {
		Write-Log "PPKG のインストールに失敗しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# メイン処理
try {
	Write-Log "PPKG インストール処理を開始します"

	# 管理者権限の警告（必要に応じて）
	if (-not (Test-IsAdministrator)) {
		Write-Log "管理者権限での実行を推奨します（権限不足で失敗する場合があります）" -Level "WARN"
	}

	# PPKG パス解決
	$resolvedPath = Resolve-PPKGPath -InputPath $PackagePath
	if (-not $resolvedPath) { exit 1 }

	# 情報取得
	$ppkgInfo = Get-PPKGInfo -PpkgPath $resolvedPath
	if (-not $ppkgInfo) { exit 1 }

	# 既存同一 PackageId の削除
	if ($RemoveExisting) {
		# インストール済みパッケージに該当があれば削除
		try {
			$installed = Get-ProvisioningPackage -AllInstalledPackages -ErrorAction SilentlyContinue
			$matched = $installed | Where-Object { $_.PackageId -eq $ppkgInfo.PackageId }
			if ($matched) {
				Write-Log "同一 PackageId が既にインストールされています。削除を実行します: $($ppkgInfo.PackageId)" -Level "WARN"
				if (-not (Remove-PPKGById -PackageId $ppkgInfo.PackageId)) { exit 1 }
			}
			else {
				Write-Log "同一 PackageId の既存インストールは見つかりませんでした"
			}
		}
		catch {
			Write-Log "既存パッケージ確認でエラーが発生しましたが続行します: $($_.Exception.Message)" -Level "WARN"
		}
	}

	# インストール
    $installedOk = if ($Force) { Install-PPKG -PpkgPath $resolvedPath -ForceInstall } else { Install-PPKG -PpkgPath $resolvedPath }
	if (-not $installedOk) { exit 1 }

	# インストール直後の削除（任意、サンプル動作）
	if ($RemoveAfterInstall) {
		Write-Log "RemoveAfterInstall が指定されたため、インストール直後に削除を実行します" -Level "WARN"
		if (-not (Remove-PPKGById -PackageId $ppkgInfo.PackageId)) { exit 1 }
	}

	# 完了マーカーは MainWorkflow 側で作成されます（ここでは詳細ログのみ）
	Write-Log "PPKG 処理の完了を記録（集中管理のためマーカーは作成しません）"
	Write-Log "PackageId=$($ppkgInfo.PackageId), PackageName=$($ppkgInfo.PackageName), Version=$($ppkgInfo.Version)"

	Write-Log "🎉 PPKG インストール処理が正常に完了しました"
	exit 0
}
catch {
	Write-Log "PPKG インストール処理でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	exit 1
}
