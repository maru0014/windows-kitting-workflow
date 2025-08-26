# ============================================================================
# デスクトップファイル配置スクリプト
# ユーザーデスクトップとパブリックデスクトップにファイルを配置
# ============================================================================

param(
	[switch]$Force,
	[switch]$DryRun,
	[switch]$Quiet,
	[switch]$Help
)

# ヘルプ表示
if ($Help) {
	Write-Host @"
デスクトップファイル配置スクリプト

使用方法:
    .\deploy-desktop-files.ps1 [オプション]

パラメータ:
    -Force                     既存ファイルを上書き

    -DryRun                    実際のコピーは行わず、実行予定を表示

    -Quiet                     コンソール出力を抑制（ログファイルには出力）

    -Help                      このヘルプを表示

説明:
    config\desktop\user フォルダのファイルを現在のユーザーのデスクトップにコピー
    config\desktop\public フォルダのファイルをパブリックデスクトップにコピー

"@
	exit 0
}

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

$ScriptName = "deploy-desktop-files"

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName $ScriptName -LogFileName "deploy-desktop-files.log" -NoConsoleOutput:$Quiet
}

# 開始ログ
Write-Log "デスクトップファイル配置処理を開始します"

try {
	# ワークフローのルートディレクトリを動的検出
	$workflowRoot = Get-WorkflowRoot

	# ワークフロールートの検証
	if (-not $workflowRoot -or -not (Test-Path $workflowRoot)) {
		throw "ワークフローのルートディレクトリが見つかりません。PSScriptRoot: $PSScriptRoot"
	}

	# デスクトップパスの取得
	$userDesktop = [System.Environment]::GetFolderPath('Desktop')
	$publicDesktop = [System.Environment]::GetFolderPath('CommonDesktopDirectory')

	# デスクトップパスの検証
	if (-not $userDesktop) {
		throw "ユーザーデスクトップパスの取得に失敗しました"
	}
	if (-not $publicDesktop) {
		throw "パブリックデスクトップパスの取得に失敗しました"
	}

	Write-Log "ユーザーデスクトップパス: $userDesktop"
	Write-Log "パブリックデスクトップパス: $publicDesktop"	# ソースフォルダのパス
	$userSourcePath = Get-WorkflowPath -PathType "Config" -SubPath "desktop\user"
	$publicSourcePath = Get-WorkflowPath -PathType "Config" -SubPath "desktop\public"
	Write-Log "ユーザーファイルソースパス: $userSourcePath"
	Write-Log "パブリックファイルソースパス: $publicSourcePath"
	# ユーザーデスクトップへのファイル配置
	if (Test-Path $userSourcePath) {
		Write-Log "ユーザーデスクトップファイルの配置を開始"
		$userFiles = Get-ChildItem -Path $userSourcePath -File | Select-Object Name, FullName
		foreach ($file in $userFiles) {
			# ファイル名の検証
			if (-not $file.Name) {
				Write-Log "ファイル名が取得できませんでした。ファイルをスキップします: $($file.FullName)" -Level "WARN"
				continue
			}

			$destinationPath = Join-Path $userDesktop $file.Name

			Write-Log "処理中: $($file.Name) -> $destinationPath"

			if ($DryRun) {
				Write-Log "[DryRun] コピー予定: $($file.FullName) -> $destinationPath"
				continue
			}

			try {
				# パスの検証
				if (-not $file.FullName -or -not (Test-Path $file.FullName)) {
					throw "ソースファイルが存在しません: $($file.FullName)"
				}
				if (-not $destinationPath) {
					throw "出力先パスが無効です"
				}				Copy-Item -Path $file.FullName -Destination $destinationPath -Force:$Force
				Write-Log "ファイルをコピーしました: $($file.Name)"
			}
			catch {
				Write-Log "ファイルのコピーに失敗しました: $($file.Name) - $($_.Exception.Message)" -Level "ERROR"
			}
		}
	}
	else {
		Write-Log "ユーザーファイルソースフォルダが見つかりません: $userSourcePath" -Level "WARN"
	}
	# パブリックデスクトップへのファイル配置
	if (Test-Path $publicSourcePath) {
		Write-Log "パブリックデスクトップファイルの配置を開始"
		$publicFiles = Get-ChildItem -Path $publicSourcePath -File | Select-Object Name, FullName

		foreach ($file in $publicFiles) {
			# ファイル名の検証
			if (-not $file.Name) {
				Write-Log "ファイル名が取得できませんでした。ファイルをスキップします: $($file.FullName)" -Level "WARN"
				continue
			}

			$destinationPath = Join-Path $publicDesktop $file.Name

			Write-Log "処理中: $($file.Name) -> $destinationPath"

			if ($DryRun) {
				Write-Log "[DryRun] コピー予定: $($file.FullName) -> $destinationPath"
				continue
			}try {
				# パスの検証
				if (-not $file.FullName -or -not (Test-Path $file.FullName)) {
					throw "ソースファイルが存在しません: $($file.FullName)"
				}
				if (-not $destinationPath) {
					throw "出力先パスが無効です"
				}				Copy-Item -Path $file.FullName -Destination $destinationPath -Force:$Force
				Write-Log "ファイルをコピーしました: $($file.Name)"
			}
			catch {
				Write-Log "ファイルのコピーに失敗しました: $($file.Name) - $($_.Exception.Message)" -Level "ERROR"
			}
		}
	}
	else {
		Write-Log "パブリックファイルソースフォルダが見つかりません: $publicSourcePath" -Level "WARN"
	}

	# 完了マーカーは MainWorkflow 側で作成されます
	Write-Log "配置処理の完了（マーカーはMainWorkflowが作成）"

	Write-Log "デスクトップファイル配置処理が完了しました"

}
catch {
	Write-Log "デスクトップファイル配置処理中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	Write-Log "エラー詳細: $($_.ScriptStackTrace)" -Level "ERROR"
	exit 1
}
