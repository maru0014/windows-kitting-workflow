# ============================================================================
# レジストリ設定スクリプト
# .regファイルの一括インポートとシステム設定の最適化
# ============================================================================

param(
	[string]$RegFilesPath = "config\registry",
	[switch]$Force
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

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "Registry" -LogFileName "import-registry.log"
}

# レジストリバックアップの作成
function Backup-Registry {
	param(
		[string]$BackupPath
	)

	try {
		Write-Log "レジストリのバックアップを作成中..."

		$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
		$backupFile = Join-Path $BackupPath "registry_backup_$timestamp.reg"

		# HKEY_CURRENT_USER全体をバックアップ（より安全で確実）
		Write-Log "HKEY_CURRENT_USER のバックアップを実行中..."
		# & reg export "HKEY_CURRENT_USER\" $backupFile /y 2>$null
		& reg export "HKEY_CURRENT_USER" $backupFile

		if ($LASTEXITCODE -eq 0) {
			if (Test-Path $backupFile) {
				$fileSize = [math]::Round((Get-Item $backupFile).Length / 1MB, 2)
				Write-Log "✅ レジストリバックアップが完了しました"
				Write-Log "   ファイル: $backupFile"
				Write-Log "   サイズ: ${fileSize} MB"
				return $true
			}
			else {
				Write-Log "❌ バックアップファイルが作成されませんでした" -Level "ERROR"
				return $false
			}
		}
		else {
			Write-Log "❌ レジストリバックアップコマンドが失敗しました (Exit Code: $LASTEXITCODE)" -Level "ERROR"
			return $false
		}

	}
 catch {
		Write-Log "❌ レジストリバックアップでエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# レジストリバックアップの検証
function Test-RegistryBackup {
	param(
		[string]$BackupFile
	)

	try {
		if (-not (Test-Path $BackupFile)) {
			Write-Log "❌ バックアップファイルが見つかりません: $BackupFile" -Level "ERROR"
			return $false
		}

		# ファイルサイズの確認（空でないことを確認）
		$fileInfo = Get-Item $BackupFile
		if ($fileInfo.Length -lt 1KB) {
			Write-Log "❌ バックアップファイルが小すぎます (サイズ: $($fileInfo.Length) bytes)" -Level "ERROR"
			return $false
		}

		# ファイル内容の基本検証
		$content = Get-Content $BackupFile -TotalCount 5 -ErrorAction SilentlyContinue
		if (-not ($content[0] -match "Windows Registry Editor")) {
			Write-Log "❌ 無効なレジストリバックアップファイル形式" -Level "ERROR"
			return $false
		}

		Write-Log "✅ レジストリバックアップファイルの検証に成功"
		return $true

	}
 catch {
		Write-Log "❌ バックアップファイル検証でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# .regファイルの検証
function Test-RegFile {
	param(
		[string]$FilePath
	)

	try {
		if (-not (Test-Path $FilePath)) {
			Write-Log "ファイルが存在しません: $FilePath" -Level "ERROR"
			return $false
		}

		$content = Get-Content $FilePath -Encoding UTF8

		# レジストリファイルのヘッダーチェック
		$firstLine = $content[0]
		if (-not ($firstLine -match "Windows Registry Editor" -or $firstLine -match "REGEDIT")) {
			Write-Log "無効なレジストリファイル形式: $FilePath" -Level "ERROR"
			return $false
		}

		Write-Log "レジストリファイルの検証に成功: $FilePath"
		return $true

	}
 catch {
		Write-Log "レジストリファイル検証でエラー: $FilePath - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# .regファイルのインポート
function Import-RegFile {
	param(
		[string]$FilePath
	)

	try {
		Write-Log "レジストリファイルをインポート中: $FilePath"

		if (-not (Test-RegFile -FilePath $FilePath)) {
			return $false
		}

		# regコマンドでインポート
		$result = & reg import $FilePath 2>&1

		if ($LASTEXITCODE -eq 0) {
			Write-Log "レジストリファイルのインポートに成功: $(Split-Path $FilePath -Leaf)"
			return $true
		}
		else {
			Write-Log "レジストリファイルのインポートに失敗: $(Split-Path $FilePath -Leaf) - $result" -Level "ERROR"
			return $false
		}

	}
 catch {
		Write-Log "レジストリファイルインポートでエラー: $FilePath - $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# レジストリ設定ファイルの作成（サンプル）
function New-SampleRegFiles {
	param(
		[string]$OutputPath
	)

	try {
		Write-Log "サンプルレジストリファイルを作成中..."

		# エクスプローラー設定
		$explorerReg = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"Hidden"=dword:00000001
"HideFileExt"=dword:00000000
"ShowSuperHidden"=dword:00000001
"LaunchTo"=dword:00000001

[HKEY_CURRENT_USER\Control Panel\Desktop]
"MenuShowDelay"="0"
"AutoEndTasks"="1"
"HungAppTimeout"="1000"
"WaitToKillAppTimeout"="2000"
"LowLevelHooksTimeout"="1000"
"@

		$explorerRegFile = Join-Path $OutputPath "01_explorer_settings.reg"
		$explorerReg | Out-File -FilePath $explorerRegFile -Encoding UTF8
		Write-Log "作成完了: $explorerRegFile"

		# パフォーマンス設定
		$performanceReg = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Control Panel\Desktop]
"UserPreferencesMask"=hex:9e,1e,07,80,12,00,00,00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects]
"VisualFXSetting"=dword:00000002

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management]
"ClearPageFileAtShutdown"=dword:00000000
"@

		$performanceRegFile = Join-Path $OutputPath "02_performance_settings.reg"
		$performanceReg | Out-File -FilePath $performanceRegFile -Encoding UTF8
		Write-Log "作成完了: $performanceRegFile"

		# プライバシー設定
		$privacyReg = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy]
"TailoredExperiencesWithDiagnosticDataEnabled"=dword:00000000

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection]
"AllowTelemetry"=dword:00000000

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager]
"SystemPaneSuggestionsEnabled"=dword:00000000
"@

		$privacyRegFile = Join-Path $OutputPath "03_privacy_settings.reg"
		$privacyReg | Out-File -FilePath $privacyRegFile -Encoding UTF8
		Write-Log "作成完了: $privacyRegFile"

		return $true

	}
 catch {
		Write-Log "サンプルレジストリファイル作成でエラー: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# レジストリバックアップの復元情報表示
function Show-RestoreInstructions {
	param(
		[string]$BackupPath
	)

	$backupFiles = Get-ChildItem -Path $BackupPath -Filter "registry_backup_*.reg" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

	if ($backupFiles.Count -gt 0) {
		Write-Log "📋 レジストリバックアップファイル:"
		foreach ($file in $backupFiles | Select-Object -First 5) {
			$fileSize = [math]::Round($file.Length / 1MB, 2)
			Write-Log "   📄 $($file.Name) (${fileSize} MB) - $($file.LastWriteTime)"
		}

		$latestBackup = $backupFiles[0]
		Write-Log "💡 復元方法："
		Write-Log "   1. PowerShell管理者権限で実行："
		Write-Log "      reg import `"$($latestBackup.FullName)`""
		Write-Log "   2. またはファイルをダブルクリックして実行"
		Write-Log "   3. 復元後、ログオフ・ログオンで設定を反映"
	}
}

# メイン処理
try {
	Write-Log "レジストリ設定処理を開始します"
	# ワークフローのルートディレクトリを動的検出
	$workflowRoot = Get-WorkflowRoot
	Write-Log "ワークフローのルートディレクトリ: $workflowRoot"
	$fullRegPath = Join-Path $workflowRoot $RegFilesPath
	Write-Log "レジストリファイルディレクトリ: $fullRegPath"

	# レジストリファイルディレクトリの作成
	if (-not (Test-Path $fullRegPath)) {
		Write-Log "レジストリファイルディレクトリを作成: $fullRegPath"
		New-Item -ItemType Directory -Path $fullRegPath -Force | Out-Null

		# # サンプルファイルの作成
		# New-SampleRegFiles -OutputPath $fullRegPath
	}

	# バックアップディレクトリの作成
	$backupPath = Get-WorkflowPath -PathType "Backup" -SubPath "registry"
	Write-Log "レジストリバックアップディレクトリ: $backupPath"
	if (-not (Test-Path $backupPath)) {
		New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
	}    # レジストリバックアップの作成
	$backupSuccess = Backup-Registry -BackupPath $backupPath
	if ($backupSuccess) {
		# バックアップファイルの検証
		$latestBackup = Get-ChildItem -Path $backupPath -Filter "registry_backup_*.reg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
		if ($latestBackup) {
			$backupVerified = Test-RegistryBackup -BackupFile $latestBackup.FullName
			if (-not $backupVerified) {
				Write-Log "⚠️  バックアップファイルの検証に失敗しました。処理を続行しますが、注意してください" -Level "WARN"
			}
		}
	}
 else {
		Write-Log "⚠️  レジストリバックアップに失敗しましたが、処理を続行します" -Level "WARN"
	}

	# .regファイルの検索と処理
	$regFiles = Get-ChildItem -Path $fullRegPath -Filter "*.reg" | Sort-Object Name

	if ($regFiles.Count -eq 0) {
		Write-Log "レジストリファイルが見つかりません: $fullRegPath" -Level "WARN"
		Write-Log "サンプルファイルが作成されました。必要に応じて編集してください"
	}
 else {
		Write-Log "発見されたレジストリファイル: $($regFiles.Count) 個"

		$successCount = 0
		$errorCount = 0

		foreach ($regFile in $regFiles) {
			try {
				Write-Log "---------------------------------------------------"
				$success = Import-RegFile -FilePath $regFile.FullName

				if ($success) {
					$successCount++
				}
				else {
					$errorCount++
				}

				# 少し間隔を空ける
				Start-Sleep -Seconds 1

			}
			catch {
				Write-Log "レジストリファイル処理でエラー: $($regFile.Name) - $($_.Exception.Message)" -Level "ERROR"
				$errorCount++
			}
		}

		Write-Log "==================== インポート結果 ===================="
		Write-Log "成功: $successCount / 失敗: $errorCount / 合計: $($regFiles.Count)"
		Write-Log "========================================================="
	}

	# 完了マーカーの作成
	$completionMarker = Get-CompletionMarkerPath -TaskName "registry-import"
	@{
		completedAt    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		regFilesPath   = $RegFilesPath
		processedFiles = $regFiles.Count
		successCount   = $successCount
		errorCount     = $errorCount
	} | ConvertTo-Json | Out-File -FilePath $completionMarker -Encoding UTF8

	Write-Log "==========================================="
	Write-Log "📊 レジストリ設定処理が完了しました"
	Write-Log "==========================================="
	Write-Log "✅ 成功: $successCount 個"
	if ($errorCount -gt 0) {
		Write-Log "❌ 失敗: $errorCount 個"
	}

	# バックアップ復元情報の表示
	Write-Log "-------------------------------------------"
	Show-RestoreInstructions -BackupPath $backupPath

	if ($errorCount -eq 0) {
		Write-Log "🎉 全ての処理が正常に完了しました！"
		exit 0
	}
 else {
		Write-Log "⚠️  一部のレジストリファイルで処理に失敗しました" -Level "WARN"
		exit 1
	}

}
catch {
	Write-Log "レジストリ設定処理でエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	exit 1
}
