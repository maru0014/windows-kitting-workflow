# 不要アプリケーションのアンインストール
# 参考URL： https://ygkb.jp/471
# その他は Get-AppxPackage | select name  で確認可能

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

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "uninstall-apps" -LogFileName "uninstall-apps.log"
}

# アプリケーションアンインストール用共通関数
function Uninstall-AppxPackages {
	param(
		[Parameter(Mandatory = $true)]
		[string[]]$PackageNames,
		[Parameter(Mandatory = $true)]
		[string]$DisplayName
	)

	Write-Log "$DisplayName をアンインストールしています..."

	$uninstalledCount = 0
	$failedCount = 0

	foreach ($packageName in $PackageNames) {
		try {
			$packages = Get-AppxPackage $packageName -ErrorAction SilentlyContinue
			if ($packages) {
				# 各パッケージを個別に処理してエラーの影響を最小化
				foreach ($package in $packages) {
					try {
						Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
						Write-Log "  ✓ $($package.Name) ($($package.PackageFullName)) を正常にアンインストールしました"
					}
					catch {
						# 「インデックスが配列の境界外です」エラーなど、個別パッケージのエラーをキャッチ
						Write-Log "  ⚠ $($package.Name) のアンインストール中にエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
						Write-Log "    詳細: パッケージ名=$($package.PackageFullName)" -Level "WARN"
						continue  # このパッケージをスキップして次のパッケージを処理
					}
				}
				$uninstalledCount++
				Write-Log "  ✓ $packageName の処理が完了しました"
			}
			else {
				Write-Log "  ℹ $packageName は既にインストールされていません"
			}
		}
		catch {
			$failedCount++
			Write-Log "  ✗ $packageName の処理中に予期しないエラーが発生しました: $($_.Exception.Message)" -Level "WARN"
			Write-Log "    エラータイプ: $($_.Exception.GetType().FullName)" -Level "WARN"
		}
	}

	if ($failedCount -eq 0) {
		Write-Log "$DisplayName のアンインストールが完了しました ($uninstalledCount 個処理)"
	}
	else {
		Write-Log "$DisplayName のアンインストールが完了しました ($uninstalledCount 個成功, $failedCount 個失敗)" -Level "WARN"
	}
}

# アンインストール対象アプリリスト
$appsToUninstall = @(
	@{
		DisplayName  = "3Dビューアー"
		PackageNames = @("Microsoft.Microsoft3DViewer")
	},
	@{
		DisplayName  = "Candy Crush Friends"
		PackageNames = @("king.com.CandyCrushFriends")
	},
	@{
		DisplayName  = "Farm Heroes Saga"
		PackageNames = @("king.com.FarmHeroesSaga")
	},
	@{
		DisplayName  = "Microsoft Solitaire Collection"
		PackageNames = @("Microsoft.MicrosoftSolitaireCollection")
	},
	@{
		DisplayName  = "Mixed Realityポータル"
		PackageNames = @("Microsoft.MixedReality.Portal")
	},
	@{
		DisplayName  = "People"
		PackageNames = @("Microsoft.People")
	},
	@{
		DisplayName  = "Print3D"
		PackageNames = @("Microsoft.Print3D")
	},
	@{
		DisplayName  = "Skype"
		PackageNames = @("Microsoft.SkypeApp")
	},
	@{
		DisplayName  = "Spotify"
		PackageNames = @("SpotifyAB.SpotifyMusic")
	},
	@{
		DisplayName  = "Xbox関連アプリ"
		PackageNames = @(
			"Microsoft.XboxGamingOverlay",
			"Microsoft.Xbox.TCUI",
			"Microsoft.XboxApp",
			"Microsoft.XboxGameOverlay",
			"Microsoft.XboxIdentityProvider",
			"Microsoft.XboxSpeechToTextOverlay"
		)
	},
	@{
		DisplayName  = "映画 & テレビ"
		PackageNames = @("Microsoft.ZuneVideo")
	}
)

# メイン処理開始
Write-Log "=== 不要なアプリケーションのアンインストール開始 ==="

$totalApps = $appsToUninstall.Count
$successfulApps = 0
$failedApps = 0

foreach ($app in $appsToUninstall) {
	try {
		Uninstall-AppxPackages -PackageNames $app.PackageNames -DisplayName $app.DisplayName
		$successfulApps++
	}
	catch {
		$failedApps++
		Write-Log "$($app.DisplayName) の処理中に予期しないエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	}
}

Write-Log "アンインストール処理結果: $successfulApps/$totalApps 個のアプリケーションが正常に処理されました"
if ($failedApps -gt 0) {
	Write-Log "$failedApps 個のアプリケーションの処理が失敗しました" -Level "WARN"
}

# コメントアウトされているオプションアプリ（参考用）
<#
今後必要に応じてアンインストール対象に追加できるアプリ:
- Microsoft.ZuneMusic                        # Groove ミュージック
- Microsoft.MicrosoftOfficeHub               # Office
- Microsoft.Office.OneNote                   # OneNote
- Microsoft.WindowsAlarms                    # アラーム＆クロック
- Microsoft.WindowsCamera                    # カメラ
- Microsoft.ScreenSketch                     # 切り取り & スケッチ(1809以降)
- Microsoft.YourPhone                        # スマホ同期
- Microsoft.BingWeather                      # 天気
- Microsoft.GetHelp                          # 問い合わせ
- Microsoft.Getstarted                       # ヒント
- Microsoft.WindowsFeedbackHub               # フィードバックHub
- Microsoft.Windows.Photos                   # フォト
- Microsoft.MicrosoftStickyNotes             # 付箋
- Microsoft.MSPaint                          # ペイント3D
- Microsoft.WindowsSoundRecorder             # ボイスレコーダー
- Microsoft.WindowsMaps                      # マップ
- microsoft.windowscommunicationsapps       # メール、カレンダー
- Microsoft.Messaging                        # メッセージング
- Microsoft.OneConnect                       # モバイル通信プラン
#>

Write-Log "不要アプリケーションのアンインストールが完了しました"

# エラーが発生した場合でも、他の処理は継続され完了します
if ($failedApps -eq 0) {
	Write-Log "すべてのアプリケーションが正常に処理されました"
}
else {
	Write-Log "一部のアプリケーションの処理でエラーが発生しましたが、他の処理は正常に完了しました" -Level "WARN"
}

# 完了マーカーは MainWorkflow 側で作成されます
Write-Log "アンインストール処理の完了（マーカーはMainWorkflowが作成）"

# 一部失敗があっても全体としては成功扱いとする（部分的成功）
if ($failedApps -eq $totalApps) {
	# すべてのアプリで失敗した場合のみエラー終了
	Write-Log "すべてのアプリケーションの処理が失敗しました" -Level "ERROR"
	exit 1
}
else {
	# 一部でも成功していれば正常終了
	exit 0
}
