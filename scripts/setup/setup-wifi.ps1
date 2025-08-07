# ============================================================================
# Wi-Fi設定プロファイル適用スクリプト
# XMLプロファイルファイルからWi-Fi設定を適用し、接続を確立
# ============================================================================

param(
	[string]$ProfilePath = "",
	[string]$ProfileName = "",
	[switch]$Force,
	[switch]$Connect,
	[switch]$ShowProfiles,
	[switch]$Help
)

# ヘルプ表示
if ($Help) {
	Write-Host @"
Wi-Fi設定プロファイル適用スクリプト

使用方法:
    .\setup-wifi.ps1 [オプション]

パラメータ:
    -ProfilePath <path>        Wi-FiプロファイルXMLファイルのパス
                               (デフォルト: config\wi-fi.xml)

    -ProfileName <name>        適用するプロファイル名を指定
                               XMLファイル内のプロファイル名を指定

    -Force                     既存のプロファイルを強制上書き、アダプターがなくてもプロファイルを作成

    -Connect                   プロファイル適用後に自動接続を試行

    -ShowProfiles              現在のWi-Fiプロファイル一覧を表示

    -Help                      このヘルプを表示

使用例:
    # デフォルトプロファイルを適用
    .\setup-wifi.ps1

    # 特定のプロファイルファイルを指定して適用
    .\setup-wifi.ps1 -ProfilePath "config\office-wifi.xml"

    # プロファイル適用後に自動接続
    .\setup-wifi.ps1 -Connect

    # 強制上書きでプロファイルを適用
    .\setup-wifi.ps1 -Force

    # 現在のプロファイル一覧を表示
    .\setup-wifi.ps1 -ShowProfiles

"@ -ForegroundColor Cyan
	exit 0
}

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

# Windows 11 24H2対応: netshコマンドの文字化け対策
# https://jpwinsup.github.io/blog/2025/03/11/Networking/TCPIP/NetshEncodingChange24h2/
$currentEncoding = [System.Console]::OutputEncoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ログ関数
function Write-Log {
	param(
		[string]$Message,
		[ValidateSet("INFO", "WARN", "ERROR")]
		[string]$Level = "INFO"
	)

	Write-ScriptLog -Message $Message -Level $Level -ScriptName "WiFiSetup" -LogFileName "setup-wifi.log"
}

# Wi-Fiアダプターの状態確認と有効化
function Enable-WiFiAdapter {
	try {
		Write-Log "Wi-Fiアダプターの状態を確認中..."

		# Wi-Fiアダプターを取得
		$wifiAdapters = Get-NetAdapter | Where-Object {
			$_.InterfaceDescription -match "wireless|wi-fi|wlan" -or
			$_.Name -match "wi-fi|wireless|wlan"
		}

		if (-not $wifiAdapters) {
			Write-Log "Wi-Fiアダプターが見つかりません" -Level "ERROR"
			return $false
		}

		# 無効なアダプターがあれば有効化
		$disabledAdapters = $wifiAdapters | Where-Object { $_.Status -eq "Disabled" }

		if ($disabledAdapters) {
			Write-Log "無効なWi-Fiアダプターを有効化中..."
			foreach ($adapter in $disabledAdapters) {
				try {
					Enable-NetAdapter -Name $adapter.Name -Confirm:$false
					Write-Log "Wi-Fiアダプター '$($adapter.Name)' を有効化しました"
				}
				catch {
					Write-Log "Wi-Fiアダプター '$($adapter.Name)' の有効化に失敗: $($_.Exception.Message)" -Level "WARN"
				}
			}

			# 少し待機してアダプターの状態安定化を待つ
			Start-Sleep -Seconds 3
		}

		# 有効なアダプターの確認
		$enabledAdapters = Get-NetAdapter | Where-Object {
            ($_.InterfaceDescription -match "wireless|wi-fi|wlan" -or $_.Name -match "wi-fi|wireless|wlan") -and
			$_.Status -eq "Up"
		}

		if ($enabledAdapters) {
			Write-Log "Wi-Fiアダプターが正常に動作しています"
			foreach ($adapter in $enabledAdapters) {
				Write-Log "  - $($adapter.Name): $($adapter.Status)"
			}
			return $true
		}
		elseif ($Force) {
			Write-Log "Wi-Fiアダプターが有効化されていませんが、Forceモードのため続行します" -Level "WARN"
			return $true
		}
		else {
			Write-Log "Wi-Fiアダプターが有効化されていません" -Level "ERROR"
			return $false
		}
	}
	catch {
		Write-Log "Wi-Fiアダプターの確認中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# XMLプロファイルからプロファイル名を取得
function Get-ProfileNameFromXML {
	param([string]$XmlPath)

	try {
		[xml]$xmlContent = Get-Content $XmlPath -Encoding UTF8
		$profileName = $xmlContent.WLANProfile.name
		if (-not $profileName) {
			# nameがない場合はSSIDConfigのnameを取得
			$profileName = $xmlContent.WLANProfile.SSIDConfig.SSID.name
		}
		return $profileName
	}
	catch {
		Write-Log "XMLファイルからプロファイル名を取得できませんでした: $($_.Exception.Message)" -Level "WARN"
		return $null
	}
}

# Wi-Fiプロファイルの適用
function Add-WiFiProfile {
	param(
		[string]$ProfilePath,
		[bool]$ForceOverwrite = $false,
		[bool]$ForceMode = $false
	)

	try {
		Write-Log "Wi-Fiプロファイルを適用中: $ProfilePath"

		# XMLファイルの存在確認
		if (-not (Test-Path $ProfilePath)) {
			Write-Log "Wi-Fiプロファイルファイルが見つかりません: $ProfilePath" -Level "ERROR"
			return $false
		}

		# XMLファイルからプロファイル名を取得
		$xmlProfileName = Get-ProfileNameFromXML -XmlPath $ProfilePath
		if ($xmlProfileName) {
			Write-Log "プロファイル名: $xmlProfileName"

			# 既存プロファイルの確認
			$existingProfile = netsh wlan show profiles | Select-String $xmlProfileName
			if ($existingProfile -and -not $ForceOverwrite) {
				Write-Log "プロファイル '$xmlProfileName' は既に存在します。-Force オプションで上書きできます" -Level "WARN"
				return $false
			}
		}

		# netshコマンドでプロファイルを追加
		$result = & netsh wlan add profile filename="$ProfilePath" 2>&1
		$exitCode = $LASTEXITCODE

		if ($exitCode -eq 0) {
			Write-Log "✅ Wi-Fiプロファイルが正常に適用されました"
			if ($xmlProfileName) {
				Write-Log "適用されたプロファイル: $xmlProfileName"
			}

			# ステータスファイルの作成
			$statusDir = Get-WorkflowPath -PathType "Status"
			if (-not (Test-Path $statusDir)) {
				New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
			}

			$timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
			Set-Content -Path (Join-Path $statusDir "setup-wifi.completed") -Value $timestamp -Encoding UTF8

			return $true
		}
		else {
			if ($ForceMode) {
				Write-Log "Wi-Fiプロファイルの適用に失敗しましたが、Forceモードのため続行します" -Level "WARN"
				Write-Log "netsh エラー出力: $result" -Level "WARN"

				# Forceモードの場合は、プロファイルが作成されていなくても成功として扱う
				Write-Log "Forceモード: プロファイルの作成をスキップしました"

				# ステータスファイルの作成
				$statusDir = Get-WorkflowPath -PathType "Status"
				if (-not (Test-Path $statusDir)) {
					New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
				}

				$timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
				Set-Content -Path (Join-Path $statusDir "setup-wifi.completed") -Value $timestamp -Encoding UTF8

				return $true
			} else {
				Write-Log "Wi-Fiプロファイルの適用に失敗しました" -Level "ERROR"
				Write-Log "netsh エラー出力: $result" -Level "ERROR"
				return $false
			}
		}
	}
	catch {
		Write-Log "Wi-Fiプロファイルの適用中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# Wi-Fi接続の実行
function Connect-WiFiNetwork {
	param([string]$ProfileName)

	try {
		Write-Log "Wi-Fiネットワークに接続中: $ProfileName"

		$result = & netsh wlan connect name="$ProfileName" 2>&1
		$exitCode = $LASTEXITCODE

		if ($exitCode -eq 0) {
			Write-Log "✅ Wi-Fiネットワークに接続しました: $ProfileName"

			# 接続状態の確認（少し待ってから）
			Start-Sleep -Seconds 5
			$connectionStatus = & netsh wlan show interfaces 2>&1
			if ($connectionStatus -match "接続|Connected") {
				Write-Log "Wi-Fi接続が確立されました"
			}
			return $true
		}
		else {
			Write-Log "Wi-Fiネットワークへの接続に失敗しました: $result" -Level "WARN"
			return $false
		}
	}
	catch {
		Write-Log "Wi-Fi接続中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
		return $false
	}
}

# Wi-Fiプロファイル一覧の表示
function Show-WiFiProfiles {
	try {
		Write-Log "現在のWi-Fiプロファイル一覧:"
		$profiles = & netsh wlan show profiles 2>&1
		Write-Host $profiles -ForegroundColor Cyan

		Write-Log "Wi-Fiアダプターの状態:"
		$interfaces = & netsh wlan show interfaces 2>&1
		Write-Host $interfaces -ForegroundColor Yellow
	}
	catch {
		Write-Log "Wi-Fiプロファイル一覧の取得に失敗しました: $($_.Exception.Message)" -Level "ERROR"
	}
}

# メイン処理
try {
	Write-Log "=== Wi-Fi設定プロファイル適用開始 ==="

	# プロファイル一覧表示のみの場合
	if ($ShowProfiles) {
		Show-WiFiProfiles
		return
	}

	# Wi-Fiアダプターの確認と有効化
	$wifiAdapterAvailable = Enable-WiFiAdapter
	if (-not $wifiAdapterAvailable) {
		if ($Force) {
			Write-Log "Forceオプションが指定されているため、Wi-Fiアダプターがなくてもプロファイルを作成します" -Level "WARN"
		} else {
			Write-Log "Wi-Fiアダプターの準備に失敗しました" -Level "ERROR"
			Write-Log "Forceオプションを指定すると、アダプターがなくてもプロファイルを作成できます" -Level "INFO"
			[System.Console]::OutputEncoding = $currentEncoding
			exit 1
		}
	}

	# プロファイルパスの設定
	if (-not $ProfilePath) {
		$ProfilePath = Get-WorkflowPath -PathType "Config" -SubPath "wi-fi.xml"
	}

	# プロファイルの適用
	$success = Add-WiFiProfile -ProfilePath $ProfilePath -ForceOverwrite $Force -ForceMode $Force

	if (-not $success) {
		Write-Log "Wi-Fiプロファイルの適用に失敗しました" -Level "ERROR"
		[System.Console]::OutputEncoding = $currentEncoding
		exit 1
	}

	# 自動接続の実行
	if ($Connect) {
		if ($Force -and -not $wifiAdapterAvailable) {
			Write-Log "ForceモードでWi-Fiアダプターが利用できないため、自動接続をスキップします" -Level "WARN"
		} else {
			$xmlProfileName = Get-ProfileNameFromXML -XmlPath $ProfilePath
			if ($xmlProfileName) {
				Connect-WiFiNetwork -ProfileName $xmlProfileName
			}
			elseif ($ProfileName) {
				Connect-WiFiNetwork -ProfileName $ProfileName
			}
			else {
				Write-Log "接続するプロファイル名が特定できませんでした" -Level "WARN"
			}
		}
	}

	# 最終状態の表示
	if ($Force -and -not $wifiAdapterAvailable) {
		Write-Log "ForceモードでWi-Fiアダプターが利用できないため、状態表示をスキップします" -Level "WARN"
	} else {
		Write-Log "現在のWi-Fi状態:"
		Show-WiFiProfiles
	}

	Write-Log "=== Wi-Fi設定プロファイル適用完了 ==="
}
catch {
	Write-Log "予期しないエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
	[System.Console]::OutputEncoding = $currentEncoding
	exit 1
}
