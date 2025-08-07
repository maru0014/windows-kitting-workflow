# ============================================================================
# タスクスケジューラ管理スクリプト
# Windows Kitting Workflow用タスクスケジューラの登録と削除
# ============================================================================

param(
	[ValidateSet("Register", "Unregister", "Status")]
	[string]$Action = "Register",

	[string]$TaskName = "WindowsKittingWorkflow_AutoSetup",

	[string]$Username,

	[string]$Password,

	[switch]$Force
)

# 共通ログ関数の読み込み
. (Join-Path $PSScriptRoot "scripts\Common-LogFunctions.ps1")

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "TaskScheduler" -LogFileName "taskscheduler.log"
}

# タスクスケジューラにタスクを登録
function Register-WorkflowTask {
	param(
		[string]$TaskName,
		[string]$Username,
		[string]$Password
	)

	try {
		Write-Log "タスクスケジューラにタスクを登録します: $TaskName"

		# 現在のユーザー情報を取得
		if (-not $Username) {
			$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
			$Username = $currentUser.Name
		}

		# スクリプトのパス
		$scriptPath = Join-Path $PSScriptRoot "main.bat"
		$workingDirectory = $PSScriptRoot

		if (-not (Test-Path $scriptPath)) {
			throw "メインスクリプトが見つかりません: $scriptPath"
		}

		Write-Log "スクリプトパス: $scriptPath"
		Write-Log "作業ディレクトリ: $workingDirectory"
		Write-Log "実行ユーザー: $Username"

		# 既存のタスクがあるかチェック
		$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
		if ($existingTask -and -not $Force) {
			Write-Log "同名のタスクが既に存在します: $TaskName" -Level "WARN"
			$confirmation = Read-Host "既存のタスクを上書きしますか？ (y/N)"
			if ($confirmation -ne "y" -and $confirmation -ne "Y") {
				Write-Log "タスクの登録をキャンセルしました"
				return $false
			}
		}

		# 既存のタスクを削除
		if ($existingTask) {
			Write-Log "既存のタスクを削除します: $TaskName"
			Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
		}

		# タスクアクションの作成
		$action = New-ScheduledTaskAction -Execute $scriptPath -WorkingDirectory $workingDirectory -Argument "/silent"

		# タスクトリガーの作成（ログオン時とシステム起動時）
		$triggerLogon = New-ScheduledTaskTrigger -AtLogOn -User $Username
		$triggerStartup = New-ScheduledTaskTrigger -AtStartup

		# タスクの詳細設定
		$settings = New-ScheduledTaskSettingsSet `
			-AllowStartIfOnBatteries `
			-DontStopIfGoingOnBatteries `
			-StartWhenAvailable `
			-RestartCount 3 `
			-RestartInterval (New-TimeSpan -Minutes 5) `
			-ExecutionTimeLimit (New-TimeSpan -Hours 4) `
			-Priority 4

		# プリンシパル設定（管理者権限で実行）
		if ($Password) {
			$principal = New-ScheduledTaskPrincipal -UserId $Username -LogonType Password -RunLevel Highest
		}
		else {
			$principal = New-ScheduledTaskPrincipal -UserId $Username -LogonType Interactive -RunLevel Highest
		}

		# タスクの説明
		$description = @"
Windows Kitting Workflow - Windows 11自動セットアップシステム

このタスクは、PC起動時およびユーザーログオン時に自動実行され、
事前定義されたスクリプトを順次実行してWindows 11 PCを
自動的にセットアップします。

作成日時: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
作業ディレクトリ: $workingDirectory
"@

		# タスクの登録
		if ($Password) {
			Register-ScheduledTask `
				-TaskName $TaskName `
				-Action $action `
				-Trigger @($triggerLogon, $triggerStartup) `
				-Settings $settings `
				-Description $description `
				-User $Username `
				-Password $Password `
				-Force
		}
		else {
			Register-ScheduledTask `
				-TaskName $TaskName `
				-Action $action `
				-Trigger @($triggerLogon, $triggerStartup) `
				-Settings $settings `
				-Principal $principal `
				-Description $description `
				-Force
		}

		Write-Log "タスクが正常に登録されました: $TaskName"

		# タスクの状態を確認
		$registeredTask = Get-ScheduledTask -TaskName $TaskName
		Write-Log "タスク状態: $($registeredTask.State)"

		# 完了マーカー作成
		$completionMarker = Join-Path $PSScriptRoot "status\task-scheduler-setup.completed"
		@{
			taskName       = $TaskName
			username       = $Username
			scriptPath     = $scriptPath
			registeredTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
			taskState      = $registeredTask.State
		} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

		return $true

	}
 catch {
		Write-Log "タスクの登録でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# タスクスケジューラからタスクを削除
function Unregister-WorkflowTask {
	param(
		[string]$TaskName
	)

	try {
		Write-Log "タスクスケジューラからタスクを削除します: $TaskName"

		# タスクの存在確認
		$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

		if (-not $task) {
			Write-Log "指定されたタスクが見つかりません: $TaskName" -Level "WARN"
			return $true
		}

		Write-Log "タスクが見つかりました。状態: $($task.State)"		# タスクが実行中の場合は警告のみ表示
		if ($task.State -eq "Running") {
			Write-Log "警告: タスクは現在実行中ですが、タスク定義を削除します"
		}

		# タスクの削除（実行中でもタスク定義は削除可能）
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

		Write-Log "タスクが正常に削除されました: $TaskName"

		# 完了マーカー作成
		$completionMarker = Join-Path $PSScriptRoot "status\task-scheduler-cleanup.completed"
		@{
			taskName         = $TaskName
			unregisteredTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

		return $true

	}
 catch {
		Write-Log "タスクの削除でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		throw
	}
}

# タスクの状態を表示
function Get-WorkflowTaskStatus {
	param(
		[string]$TaskName
	)

	try {
		Write-Log "タスクの状態を確認します: $TaskName"

		$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

		if (-not $task) {
			Write-Log "タスクが見つかりません: $TaskName"
			return
		}

		$taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName

		Write-Log "タスク情報:"
		Write-Log "  名前: $($task.TaskName)"
		Write-Log "  状態: $($task.State)"
		Write-Log "  説明: $($task.Description)"
		Write-Log "  最終実行時刻: $($taskInfo.LastRunTime)"
		Write-Log "  次回実行時刻: $($taskInfo.NextRunTime)"
		Write-Log "  最終実行結果: $($taskInfo.LastTaskResult)"

		# トリガー情報
		Write-Log "  トリガー:"
		foreach ($trigger in $task.Triggers) {
			Write-Log "    タイプ: $($trigger.CimClass.CimClassName)"
			if ($trigger.CimClass.CimClassName -eq "MSFT_TaskLogonTrigger") {
				Write-Log "    ユーザー: $($trigger.UserId)"
			}
		}

		# アクション情報
		Write-Log "  アクション:"
		foreach ($action in $task.Actions) {
			Write-Log "    実行ファイル: $($action.Execute)"
			Write-Log "    引数: $($action.Arguments)"
			Write-Log "    作業ディレクトリ: $($action.WorkingDirectory)"
		}

	}
 catch {
		Write-Log "タスク状態の確認でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
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
	Write-Log "タスクスケジューラ管理スクリプトを開始します"
	Write-Log "アクション: $Action"
	Write-Log "タスク名: $TaskName"

	# 管理者権限チェック
	if (-not (Test-AdminRights)) {
		Write-Log "このスクリプトは管理者権限で実行する必要があります" -Level "ERROR"
		exit 1
	}

	# ログディレクトリ作成
	$logsDir = Join-Path $PSScriptRoot "logs"
	$statusDir = Join-Path $PSScriptRoot "status"

	@($logsDir, $statusDir) | ForEach-Object {
		if (-not (Test-Path $_)) {
			New-Item -ItemType Directory -Path $_ -Force | Out-Null
		}
	}

	# アクションに応じて処理実行
	switch ($Action) {
		"Register" {
			if (-not $Force) {
				Write-Log "タスクスケジューラにタスクを登録します"
				$confirmation = Read-Host "続行しますか？ (y/N)"
				if ($confirmation -ne "y" -and $confirmation -ne "Y") {
					Write-Log "タスクの登録をキャンセルしました"
					exit 0
				}
			}

			$success = Register-WorkflowTask -TaskName $TaskName -Username $Username -Password $Password
			if ($success) {
				Write-Log "タスクの登録が正常に完了しました"
				exit 0
			}
			else {
				Write-Log "タスクの登録に失敗しました" -Level "ERROR"
				exit 1
			}
		}

		"Unregister" {
			if (-not $Force) {
				Write-Log "タスクスケジューラからタスクを削除します"
				$confirmation = Read-Host "続行しますか？ (y/N)"
				if ($confirmation -ne "y" -and $confirmation -ne "Y") {
					Write-Log "タスクの削除をキャンセルしました"
					exit 0
				}
			}

			$success = Unregister-WorkflowTask -TaskName $TaskName
			if ($success) {
				Write-Log "タスクの削除が正常に完了しました"
				exit 0
			}
			else {
				Write-Log "タスクの削除に失敗しました" -Level "ERROR"
				exit 1
			}
		}

		"Status" {
			Get-WorkflowTaskStatus -TaskName $TaskName
			exit 0
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
