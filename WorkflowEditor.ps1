#requires -version 5.1

<#
.SYNOPSIS
    workflow.json設定を編集するGUIエディター

.DESCRIPTION
    Windows Formsを使用してworkflow.jsonの設定を視覚的に編集できるGUIツールです。
    ワークフローの基本設定とステップの設定を編集できます。

.EXAMPLE
    .\WorkflowEditor.ps1
#>

param(
	[string]$ConfigPath = "config\workflow.json"
)

# Windows Forms アセンブリを読み込み
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# グローバル変数
$script:Config = $null
$script:Form = $null
$script:ConfigFilePath = $ConfigPath

# JSONファイルを読み込む関数
function Load-WorkflowConfig {
	param([string]$Path)

	try {
		if (Test-Path $Path) {
			$content = Get-Content -Path $Path -Raw -Encoding UTF8
			return $content | ConvertFrom-Json
		}
		else {
			[System.Windows.Forms.MessageBox]::Show(
				"Configuration file not found: $Path",
				"Error",
				[System.Windows.Forms.MessageBoxButtons]::OK,
				[System.Windows.Forms.MessageBoxIcon]::Error
			)
			return $null
		}
	}
 catch {
		[System.Windows.Forms.MessageBox]::Show(
			"Failed to load configuration file: $($_.Exception.Message)",
			"Error",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Error
		)
		return $null
	}
}

# JSONファイルを保存する関数
function Save-WorkflowConfig {
	param([object]$Config, [string]$Path)
	try {
		# JSONを生成（4スペースインデント）
		$json = $Config | ConvertTo-Json -Depth 10

		# 4スペースインデントを2スペースに変換
		$lines = $json -split "`n"
		$convertedLines = @()

		foreach ($line in $lines) {
			# 行頭の空白をカウント
			$leadingSpaces = ($line -replace '^(\s*).*', '$1').Length
			if ($leadingSpaces -gt 0) {
				# 4スペース単位を2スペース単位に変換
				$newIndent = ' ' * ($leadingSpaces / 2)
				$convertedLine = $newIndent + $line.TrimStart()
				$convertedLines += $convertedLine
			} else {
				$convertedLines += $line
			}
		}

		$json = $convertedLines -join "`n"

		# UTF8 BOMなしで保存
		$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
		[System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)

		[System.Windows.Forms.MessageBox]::Show(
			"設定を保存しました。",
			"保存完了",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)
		return $true
	}
 catch {
		[System.Windows.Forms.MessageBox]::Show(
			"設定の保存に失敗しました: $($_.Exception.Message)",
			"エラー",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Error
		)
		return $false
	}
}

# Save-As機能の共通ヘルパー関数
function Invoke-SaveAsDialog {
	if ($script:Config) {
		$saveDialog = New-Object System.Windows.Forms.SaveFileDialog
		$saveDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
		$saveDialog.InitialDirectory = Split-Path $script:ConfigFilePath -Parent
		$saveDialog.FileName = Split-Path $script:ConfigFilePath -Leaf

		if ($saveDialog.ShowDialog() -eq "OK") {
			$script:ConfigFilePath = $saveDialog.FileName
			Save-WorkflowConfig -Config $script:Config -Path $script:ConfigFilePath
		}
	}
}

# メインフォームを作成する関数
function Create-MainForm {
	$form = New-Object System.Windows.Forms.Form
	$form.Text = "Workflow Configuration Editor"
	$form.Size = New-Object System.Drawing.Size(1280, 720)
	$form.StartPosition = "CenterScreen"# タブコントロール
	$tabControl = New-Object System.Windows.Forms.TabControl
	$tabControl.Dock = "Fill"
	$null = $form.Controls.Add($tabControl)

	# 基本設定タブ
	$basicTab = New-Object System.Windows.Forms.TabPage
	$basicTab.Text = "基本設定"
	$null = $tabControl.TabPages.Add($basicTab)

	# ステップ設定タブ
	$stepsTab = New-Object System.Windows.Forms.TabPage
	$stepsTab.Text = "ステップ設定"
	$null = $tabControl.TabPages.Add($stepsTab)

	# メニューバー
	$menuStrip = New-Object System.Windows.Forms.MenuStrip
	$form.MainMenuStrip = $menuStrip
	$null = $form.Controls.Add($menuStrip)

	# ファイルメニュー
	$fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
	$fileMenu.Text = "ファイル(&F)"
	$null = $menuStrip.Items.Add($fileMenu)

	# 開く
	$openMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
	$openMenuItem.Text = "開く(&O)"
	$openMenuItem.ShortcutKeys = "Control, O"
	$openMenuItem.Add_Click({
			$openDialog = New-Object System.Windows.Forms.OpenFileDialog
			$openDialog.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
			$openDialog.InitialDirectory = Split-Path $script:ConfigFilePath -Parent

			if ($openDialog.ShowDialog() -eq "OK") {
				$script:ConfigFilePath = $openDialog.FileName
				$script:Config = Load-WorkflowConfig -Path $script:ConfigFilePath
				if ($script:Config) {
					Update-BasicSettings
					Update-StepsView
				}
			}		})
	$null = $fileMenu.DropDownItems.Add($openMenuItem)

	# 保存
	$saveMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
	$saveMenuItem.Text = "保存(&S)"
	$saveMenuItem.ShortcutKeys = "Control, S"
	$saveMenuItem.Add_Click({
			if ($script:Config) {
				Save-WorkflowConfig -Config $script:Config -Path $script:ConfigFilePath
			}
		})
	$null = $fileMenu.DropDownItems.Add($saveMenuItem)
	# 名前を付けて保存
	$saveAsMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
	$saveAsMenuItem.Text = "名前を付けて保存(&A)"
	$saveAsMenuItem.Add_Click({
			Invoke-SaveAsDialog
		})
	$null = $fileMenu.DropDownItems.Add($saveAsMenuItem)

	# 基本設定タブの内容を作成
	$null = Create-BasicSettingsTab -TabPage $basicTab
	# ステップ設定タブの内容を作成
	$null = Create-StepsTab -TabPage $stepsTab	# フォーム表示後にSplitterDistanceを調整
	$form.Add_Load({
		# タブコントロールとSplitterContainerのサイズが確定した後に比率を設定
		if ($script:splitContainer -and $script:splitContainer.Height -gt 200) {
			$newDistance = [int]($script:splitContainer.Height * 0.4)
			# Panel1MinSizeとPanel2MinSizeの制約をチェック
			if ($newDistance -ge $script:splitContainer.Panel1MinSize -and
				($script:splitContainer.Height - $newDistance) -ge $script:splitContainer.Panel2MinSize) {
				$script:splitContainer.SplitterDistance = $newDistance
			}
		}

			# ListViewの初期サイズを設定
			if ($script:lstSteps -and $script:splitContainer.Panel1.Width -gt 0) {
				$availableWidth = $script:splitContainer.Panel1.Width - 25  # Padding + 余白
				$availableHeight = $script:splitContainer.Panel1.Height - 70  # ボタンパネル + タイトル + 余白
				if ($availableWidth -gt 0 -and $availableHeight -gt 0) {
					$script:lstSteps.Size = New-Object System.Drawing.Size($availableWidth, $availableHeight)
				}
			}
		})

	return $form
}

# 基本設定タブを作成する関数
function Create-BasicSettingsTab {
	param([System.Windows.Forms.TabPage]$TabPage)

	$panel = New-Object System.Windows.Forms.Panel
	$panel.Dock = "Fill"
	$panel.AutoScroll = $true
	$TabPage.Controls.Add($panel)

	$y = 20

	# ワークフロー名
	$lblName = New-Object System.Windows.Forms.Label
	$lblName.Text = "ワークフロー名:"
	$lblName.Location = New-Object System.Drawing.Point(20, $y)
	$lblName.Size = New-Object System.Drawing.Size(150, 23)
	$panel.Controls.Add($lblName)

	$script:txtName = New-Object System.Windows.Forms.TextBox
	$script:txtName.Location = New-Object System.Drawing.Point(180, $y)
	$script:txtName.Size = New-Object System.Drawing.Size(300, 23)
	$panel.Controls.Add($script:txtName)

	$y += 40

	# バージョン
	$lblVersion = New-Object System.Windows.Forms.Label
	$lblVersion.Text = "バージョン:"
	$lblVersion.Location = New-Object System.Drawing.Point(20, $y)
	$lblVersion.Size = New-Object System.Drawing.Size(150, 23)
	$panel.Controls.Add($lblVersion)

	$script:txtVersion = New-Object System.Windows.Forms.TextBox
	$script:txtVersion.Location = New-Object System.Drawing.Point(180, $y)
	$script:txtVersion.Size = New-Object System.Drawing.Size(100, 23)
	$panel.Controls.Add($script:txtVersion)

	$y += 40

	# 説明
	$lblDescription = New-Object System.Windows.Forms.Label
	$lblDescription.Text = "説明:"
	$lblDescription.Location = New-Object System.Drawing.Point(20, $y)
	$lblDescription.Size = New-Object System.Drawing.Size(150, 23)
	$panel.Controls.Add($lblDescription)

	$script:txtDescription = New-Object System.Windows.Forms.TextBox
	$script:txtDescription.Location = New-Object System.Drawing.Point(180, $y)
	$script:txtDescription.Size = New-Object System.Drawing.Size(500, 23)
	$panel.Controls.Add($script:txtDescription)

	$y += 60

	# 設定グループボックス
	$grpSettings = New-Object System.Windows.Forms.GroupBox
	$grpSettings.Text = "設定"
	$grpSettings.Location = New-Object System.Drawing.Point(20, $y)
	$grpSettings.Size = New-Object System.Drawing.Size(700, 200)
	$panel.Controls.Add($grpSettings)

	$settingY = 30

	# 最大リトライ回数
	$lblMaxRetries = New-Object System.Windows.Forms.Label
	$lblMaxRetries.Text = "最大リトライ回数:"
	$lblMaxRetries.Location = New-Object System.Drawing.Point(20, $settingY)
	$lblMaxRetries.Size = New-Object System.Drawing.Size(150, 23)
	$grpSettings.Controls.Add($lblMaxRetries)

	$script:numMaxRetries = New-Object System.Windows.Forms.NumericUpDown
	$script:numMaxRetries.Location = New-Object System.Drawing.Point(180, $settingY)
	$script:numMaxRetries.Size = New-Object System.Drawing.Size(80, 23)
	$script:numMaxRetries.Minimum = 0
	$script:numMaxRetries.Maximum = 10
	$grpSettings.Controls.Add($script:numMaxRetries)

	$settingY += 35

	# リトライ遅延
	$lblRetryDelay = New-Object System.Windows.Forms.Label
	$lblRetryDelay.Text = "リトライ遅延(秒):"
	$lblRetryDelay.Location = New-Object System.Drawing.Point(20, $settingY)
	$lblRetryDelay.Size = New-Object System.Drawing.Size(150, 23)
	$grpSettings.Controls.Add($lblRetryDelay)

	$script:numRetryDelay = New-Object System.Windows.Forms.NumericUpDown
	$script:numRetryDelay.Location = New-Object System.Drawing.Point(180, $settingY)
	$script:numRetryDelay.Size = New-Object System.Drawing.Size(80, 23)
	$script:numRetryDelay.Minimum = 0
	$script:numRetryDelay.Maximum = 300
	$grpSettings.Controls.Add($script:numRetryDelay)

	$settingY += 35

	# ログレベル
	$lblLogLevel = New-Object System.Windows.Forms.Label
	$lblLogLevel.Text = "ログレベル:"
	$lblLogLevel.Location = New-Object System.Drawing.Point(20, $settingY)
	$lblLogLevel.Size = New-Object System.Drawing.Size(150, 23)
	$grpSettings.Controls.Add($lblLogLevel)

	$script:cmbLogLevel = New-Object System.Windows.Forms.ComboBox
	$script:cmbLogLevel.Location = New-Object System.Drawing.Point(180, $settingY)
	$script:cmbLogLevel.Size = New-Object System.Drawing.Size(120, 23)
	$script:cmbLogLevel.DropDownStyle = "DropDownList"
	$script:cmbLogLevel.Items.AddRange(@("DEBUG", "INFO", "WARN", "ERROR"))
	$grpSettings.Controls.Add($script:cmbLogLevel)

	# 再起動有効化
	$script:chkEnableReboot = New-Object System.Windows.Forms.CheckBox
	$script:chkEnableReboot.Text = "再起動を有効にする"
	$script:chkEnableReboot.Location = New-Object System.Drawing.Point(320, $settingY)
	$script:chkEnableReboot.Size = New-Object System.Drawing.Size(200, 23)
	$grpSettings.Controls.Add($script:chkEnableReboot)

	$settingY += 35

	# 完了時クリーンアップ
	$script:chkCleanupOnComplete = New-Object System.Windows.Forms.CheckBox
	$script:chkCleanupOnComplete.Text = "完了時にクリーンアップする"
	$script:chkCleanupOnComplete.Location = New-Object System.Drawing.Point(20, $settingY)
	$script:chkCleanupOnComplete.Size = New-Object System.Drawing.Size(200, 23)
	$grpSettings.Controls.Add($script:chkCleanupOnComplete)
	# 設定を適用ボタン
	$y += 220
	$btnApplyBasic = New-Object System.Windows.Forms.Button
	$btnApplyBasic.Text = "基本設定を適用"
	$btnApplyBasic.Location = New-Object System.Drawing.Point(20, $y)
	$btnApplyBasic.Size = New-Object System.Drawing.Size(150, 30)
	$btnApplyBasic.Add_Click({
			Apply-BasicSettings
		})
	$panel.Controls.Add($btnApplyBasic)

	# 保存ボタン
	$btnSaveBasic = New-Object System.Windows.Forms.Button
	$btnSaveBasic.Text = "保存"
	$btnSaveBasic.Location = New-Object System.Drawing.Point(180, $y)
	$btnSaveBasic.Size = New-Object System.Drawing.Size(80, 30)
	$btnSaveBasic.Add_Click({
			if ($script:Config) {
				Save-WorkflowConfig -Config $script:Config -Path $script:ConfigFilePath
			}
		})
	$panel.Controls.Add($btnSaveBasic)

	# 名前を付けて保存ボタン
	$btnSaveAsBasic = New-Object System.Windows.Forms.Button
	$btnSaveAsBasic.Text = "名前を付けて保存"
	$btnSaveAsBasic.Location = New-Object System.Drawing.Point(270, $y)
	$btnSaveAsBasic.Size = New-Object System.Drawing.Size(140, 30)
	$btnSaveAsBasic.Add_Click({
			Invoke-SaveAsDialog
		})
	$panel.Controls.Add($btnSaveAsBasic)
}

# ステップ設定タブを作成する関数
function Create-StepsTab {
	param([System.Windows.Forms.TabPage]$TabPage)	$script:splitContainer = New-Object System.Windows.Forms.SplitContainer
	$script:splitContainer.Dock = "Fill"
	$script:splitContainer.Orientation = "Horizontal"
	$script:splitContainer.FixedPanel = "None"  # 比率ベースにする
	$script:splitContainer.IsSplitterFixed = $false
	$script:splitContainer.Panel1MinSize = 100
	$script:splitContainer.Panel2MinSize = 100
	# SplitterDistanceは後で設定
	$TabPage.Controls.Add($script:splitContainer)
	# 上部パネル：ステップ一覧
	$grpSteps = New-Object System.Windows.Forms.GroupBox
	$grpSteps.Text = "ステップ一覧"
	$grpSteps.Dock = "Fill"
	$grpSteps.Padding = New-Object System.Windows.Forms.Padding(5)
	$script:splitContainer.Panel1.Controls.Add($grpSteps)

	# 下部パネル：ステップ詳細
	$grpStepDetails = New-Object System.Windows.Forms.GroupBox
	$grpStepDetails.Text = "ステップ詳細"
	$grpStepDetails.Dock = "Fill"
	$grpStepDetails.Padding = New-Object System.Windows.Forms.Padding(5)
	$script:splitContainer.Panel2.Controls.Add($grpStepDetails)
	# ボタンパネル
	$buttonPanel = New-Object System.Windows.Forms.Panel
	$buttonPanel.Height = 40
	$buttonPanel.Dock = "Top"
	$grpSteps.Controls.Add($buttonPanel)

	# 上へ移動ボタン
	$btnMoveUp = New-Object System.Windows.Forms.Button
	$btnMoveUp.Text = "上へ移動"
	$btnMoveUp.Location = New-Object System.Drawing.Point(10, 8)
	$btnMoveUp.Size = New-Object System.Drawing.Size(80, 25)
	$btnMoveUp.Add_Click({
			Move-StepUp
		})
	$buttonPanel.Controls.Add($btnMoveUp)

	# 下へ移動ボタン
	$btnMoveDown = New-Object System.Windows.Forms.Button
	$btnMoveDown.Text = "下へ移動"
	$btnMoveDown.Location = New-Object System.Drawing.Point(100, 8)
	$btnMoveDown.Size = New-Object System.Drawing.Size(80, 25)
	$btnMoveDown.Add_Click({
			Move-StepDown
		})
	$buttonPanel.Controls.Add($btnMoveDown)

	# 保存ボタン
	$btnSave = New-Object System.Windows.Forms.Button
	$btnSave.Text = "保存"
	$btnSave.Location = New-Object System.Drawing.Point(200, 8)
	$btnSave.Size = New-Object System.Drawing.Size(60, 25)
	$btnSave.Add_Click({
			if ($script:Config) {
				Save-WorkflowConfig -Config $script:Config -Path $script:ConfigFilePath
			}
		})
	$buttonPanel.Controls.Add($btnSave)
	# 名前を付けて保存ボタン
	$btnSaveAs = New-Object System.Windows.Forms.Button
	$btnSaveAs.Text = "名前を付けて保存"
	$btnSaveAs.Location = New-Object System.Drawing.Point(270, 8)
	$btnSaveAs.Size = New-Object System.Drawing.Size(120, 25)
	$btnSaveAs.Add_Click({
			Invoke-SaveAsDialog
		})
	$buttonPanel.Controls.Add($btnSaveAs)# ListView：ステップ一覧を表示
	$script:lstSteps = New-Object System.Windows.Forms.ListView
	$script:lstSteps.View = "Details"
	$script:lstSteps.FullRowSelect = $true
	$script:lstSteps.GridLines = $true
	$script:lstSteps.Dock = "None"
	$script:lstSteps.Location = New-Object System.Drawing.Point(10, 60)  # ボタンパネル(40px) + 余白(10px)
	$script:lstSteps.Anchor = "Top,Left,Right,Bottom"  # リサイズ時に追従
	# 初期サイズを設定（後で動的に調整）
	$script:lstSteps.Size = New-Object System.Drawing.Size(400, 110)
	$script:lstSteps.Columns.Add("No", 50)
	$script:lstSteps.Columns.Add("ID", 150)
	$script:lstSteps.Columns.Add("名前", 200)
	$script:lstSteps.Columns.Add("説明", 300)
	$script:lstSteps.Columns.Add("スクリプト", 200)
	$script:lstSteps.Columns.Add("タイプ", 100)
	$script:lstSteps.Columns.Add("管理者権限", 80)
	$script:lstSteps.Columns.Add("再起動必須", 80)

	# ListViewをGroupBoxに追加（ボタンパネルの下に配置される）
	$grpSteps.Controls.Add($script:lstSteps)
	# ステップ選択時のイベント
	$script:lstSteps.Add_SelectedIndexChanged({
			if ($script:lstSteps.SelectedItems.Count -gt 0) {
				$selectedStepId = $script:lstSteps.SelectedItems[0].SubItems[1].Text  # ID列（2番目の列）を取得
				Show-StepDetails -StepId $selectedStepId
			}
		})

	# 詳細編集用のパネル
	$script:pnlStepDetails = New-Object System.Windows.Forms.Panel
	$script:pnlStepDetails.Dock = "Fill"
	$script:pnlStepDetails.AutoScroll = $true
	$grpStepDetails.Controls.Add($script:pnlStepDetails)
	Create-StepDetailsPanel | Out-Null	# SplitterDistanceを比率で設定するため、フォーム表示後に調整
	$script:splitContainer.Add_SizeChanged({
			if ($script:splitContainer.Height -gt 200) {
				# 十分な高さがある場合のみ設定
				$newDistance = [int]($script:splitContainer.Height * 0.4)
				# Panel1MinSizeとPanel2MinSizeの制約をチェック
				if ($newDistance -ge $script:splitContainer.Panel1MinSize -and
				($script:splitContainer.Height - $newDistance) -ge $script:splitContainer.Panel2MinSize) {
					$script:splitContainer.SplitterDistance = $newDistance
				}
			}

			# ListViewのサイズを動的に調整
			if ($script:lstSteps -and $grpSteps.Width -gt 0 -and $grpSteps.Height -gt 0) {
				$availableWidth = $grpSteps.Width - 25  # Padding(5x2) + 余白(15)
				$availableHeight = $grpSteps.Height - 70  # ボタンパネル(40) + タイトル(20) + 余白(10)
				if ($availableWidth -gt 0 -and $availableHeight -gt 0) {
					$script:lstSteps.Size = New-Object System.Drawing.Size($availableWidth, $availableHeight)
				}
			}
	})
}

# ステップ詳細パネルを作成する関数
function Create-StepDetailsPanel {
	$panel = $script:pnlStepDetails
	$panel.Controls.Clear()

	$y = 20

	# ステップID（読み取り専用）
	$lblStepId = New-Object System.Windows.Forms.Label
	$lblStepId.Text = "ステップID:"
	$lblStepId.Location = New-Object System.Drawing.Point(20, $y)
	$lblStepId.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblStepId)

	$script:txtStepId = New-Object System.Windows.Forms.TextBox
	$script:txtStepId.Location = New-Object System.Drawing.Point(150, $y)
	$script:txtStepId.Size = New-Object System.Drawing.Size(200, 23)
	$script:txtStepId.ReadOnly = $true
	$panel.Controls.Add($script:txtStepId)

	$y += 35

	# ステップ名
	$lblStepName = New-Object System.Windows.Forms.Label
	$lblStepName.Text = "ステップ名:"
	$lblStepName.Location = New-Object System.Drawing.Point(20, $y)
	$lblStepName.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblStepName)

	$script:txtStepName = New-Object System.Windows.Forms.TextBox
	$script:txtStepName.Location = New-Object System.Drawing.Point(150, $y)
	$script:txtStepName.Size = New-Object System.Drawing.Size(300, 23)
	$panel.Controls.Add($script:txtStepName)

	$y += 35

	# 説明
	$lblStepDescription = New-Object System.Windows.Forms.Label
	$lblStepDescription.Text = "説明:"
	$lblStepDescription.Location = New-Object System.Drawing.Point(20, $y)
	$lblStepDescription.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblStepDescription)

	$script:txtStepDescription = New-Object System.Windows.Forms.TextBox
	$script:txtStepDescription.Location = New-Object System.Drawing.Point(150, $y)
	$script:txtStepDescription.Size = New-Object System.Drawing.Size(500, 60)
	$script:txtStepDescription.Multiline = $true
	$script:txtStepDescription.ScrollBars = "Vertical"
	$panel.Controls.Add($script:txtStepDescription)

	$y += 75

	# スクリプトパス
	$lblScript = New-Object System.Windows.Forms.Label
	$lblScript.Text = "スクリプト:"
	$lblScript.Location = New-Object System.Drawing.Point(20, $y)
	$lblScript.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblScript)

	$script:txtScript = New-Object System.Windows.Forms.TextBox
	$script:txtScript.Location = New-Object System.Drawing.Point(150, $y)
	$script:txtScript.Size = New-Object System.Drawing.Size(400, 23)
	$panel.Controls.Add($script:txtScript)

	$y += 35

	# タイプ
	$lblType = New-Object System.Windows.Forms.Label
	$lblType.Text = "タイプ:"
	$lblType.Location = New-Object System.Drawing.Point(20, $y)
	$lblType.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblType)

	$script:cmbStepType = New-Object System.Windows.Forms.ComboBox
	$script:cmbStepType.Location = New-Object System.Drawing.Point(150, $y)
	$script:cmbStepType.Size = New-Object System.Drawing.Size(150, 23)
	$script:cmbStepType.DropDownStyle = "DropDownList"
	$script:cmbStepType.Items.AddRange(@("powershell", "batch", "internal"))
	$panel.Controls.Add($script:cmbStepType)

	# 管理者権限
	$script:chkRunAsAdmin = New-Object System.Windows.Forms.CheckBox
	$script:chkRunAsAdmin.Text = "管理者権限で実行"
	$script:chkRunAsAdmin.Location = New-Object System.Drawing.Point(320, $y)
	$script:chkRunAsAdmin.Size = New-Object System.Drawing.Size(150, 23)
	$panel.Controls.Add($script:chkRunAsAdmin)

	# 再起動必須
	$script:chkRebootRequired = New-Object System.Windows.Forms.CheckBox
	$script:chkRebootRequired.Text = "再起動必須"
	$script:chkRebootRequired.Location = New-Object System.Drawing.Point(480, $y)
	$script:chkRebootRequired.Size = New-Object System.Drawing.Size(100, 23)
	$panel.Controls.Add($script:chkRebootRequired)

	$y += 35

	# タイムアウト
	$lblTimeout = New-Object System.Windows.Forms.Label
	$lblTimeout.Text = "タイムアウト(秒):"
	$lblTimeout.Location = New-Object System.Drawing.Point(20, $y)
	$lblTimeout.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblTimeout)

	$script:numTimeout = New-Object System.Windows.Forms.NumericUpDown
	$script:numTimeout.Location = New-Object System.Drawing.Point(150, $y)
	$script:numTimeout.Size = New-Object System.Drawing.Size(100, 23)
	$script:numTimeout.Minimum = 0
	$script:numTimeout.Maximum = 7200
	$panel.Controls.Add($script:numTimeout)

	# リトライ回数
	$lblRetryCount = New-Object System.Windows.Forms.Label
	$lblRetryCount.Text = "リトライ回数:"
	$lblRetryCount.Location = New-Object System.Drawing.Point(270, $y)
	$lblRetryCount.Size = New-Object System.Drawing.Size(100, 23)
	$panel.Controls.Add($lblRetryCount)

	$script:numRetryCount = New-Object System.Windows.Forms.NumericUpDown
	$script:numRetryCount.Location = New-Object System.Drawing.Point(380, $y)
	$script:numRetryCount.Size = New-Object System.Drawing.Size(80, 23)
	$script:numRetryCount.Minimum = 0
	$script:numRetryCount.Maximum = 10
	$panel.Controls.Add($script:numRetryCount)

	$y += 35

	# エラー時の動作
	$lblOnError = New-Object System.Windows.Forms.Label
	$lblOnError.Text = "エラー時の動作:"
	$lblOnError.Location = New-Object System.Drawing.Point(20, $y)
	$lblOnError.Size = New-Object System.Drawing.Size(120, 23)
	$panel.Controls.Add($lblOnError)

	$script:cmbOnError = New-Object System.Windows.Forms.ComboBox
	$script:cmbOnError.Location = New-Object System.Drawing.Point(150, $y)
	$script:cmbOnError.Size = New-Object System.Drawing.Size(120, 23)
	$script:cmbOnError.DropDownStyle = "DropDownList"
	$script:cmbOnError.Items.AddRange(@("stop", "continue", "retry"))
	$panel.Controls.Add($script:cmbOnError)

	$y += 50

	# ステップ設定を適用ボタン
	$btnApplyStep = New-Object System.Windows.Forms.Button
	$btnApplyStep.Text = "ステップ設定を適用"
	$btnApplyStep.Location = New-Object System.Drawing.Point(20, $y)
	$btnApplyStep.Size = New-Object System.Drawing.Size(150, 30)
	$btnApplyStep.Add_Click({
			Apply-StepSettings		})
	$panel.Controls.Add($btnApplyStep) | Out-Null
}

# ステップを上に移動する関数
function Move-StepUp {
	if ($script:lstSteps.SelectedItems.Count -eq 0) {
		[System.Windows.Forms.MessageBox]::Show(
			"移動するステップを選択してください。",
			"情報",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)
		return
	}

	$selectedIndex = $script:lstSteps.SelectedItems[0].Index
	if ($selectedIndex -eq 0) {
		[System.Windows.Forms.MessageBox]::Show(
			"最初のステップは上に移動できません。",
			"情報",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)
		return
	}

	# 配列内でステップを入れ替え
	$steps = $script:Config.workflow.steps
	$temp = $steps[$selectedIndex]
	$steps[$selectedIndex] = $steps[$selectedIndex - 1]
	$steps[$selectedIndex - 1] = $temp
	# ビューを更新
	Update-StepsView
	# 選択を維持（移動後の新しい位置）
	$newIndex = $selectedIndex - 1
	$script:lstSteps.Items[$newIndex].Selected = $true
	$script:lstSteps.Items[$newIndex].Focused = $true
	$script:lstSteps.Focus()  # ListViewにフォーカスを戻す
	$script:lstSteps.EnsureVisible($newIndex)  # 表示領域内に確実に表示
}

# ステップを下に移動する関数
function Move-StepDown {
	if ($script:lstSteps.SelectedItems.Count -eq 0) {
		[System.Windows.Forms.MessageBox]::Show(
			"移動するステップを選択してください。",
			"情報",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)
		return
	}

	$selectedIndex = $script:lstSteps.SelectedItems[0].Index
	$maxIndex = $script:Config.workflow.steps.Count - 1

	if ($selectedIndex -eq $maxIndex) {
		[System.Windows.Forms.MessageBox]::Show(
			"最後のステップは下に移動できません。",
			"情報",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)
		return
	}

	# 配列内でステップを入れ替え
	$steps = $script:Config.workflow.steps
	$temp = $steps[$selectedIndex]
	$steps[$selectedIndex] = $steps[$selectedIndex + 1]
	$steps[$selectedIndex + 1] = $temp
	# ビューを更新
	Update-StepsView
	# 選択を維持（移動後の新しい位置）
	$newIndex = $selectedIndex + 1
	$script:lstSteps.Items[$newIndex].Selected = $true
	$script:lstSteps.Items[$newIndex].Focused = $true
	$script:lstSteps.Focus()  # ListViewにフォーカスを戻す
	$script:lstSteps.EnsureVisible($newIndex)  # 表示領域内に確実に表示
}

# 基本設定を更新する関数
function Update-BasicSettings {
	if ($script:Config -and $script:Config.workflow) {
		$workflow = $script:Config.workflow
		$script:txtName.Text = $workflow.name
		$script:txtVersion.Text = $workflow.version
		$script:txtDescription.Text = $workflow.description

		if ($workflow.settings) {
			$settings = $workflow.settings
			$script:numMaxRetries.Value = [int]$settings.maxRetries
			$script:numRetryDelay.Value = [int]$settings.retryDelay
			$script:cmbLogLevel.SelectedItem = $settings.logLevel
			$script:chkEnableReboot.Checked = [bool]$settings.enableReboot
			$script:chkCleanupOnComplete.Checked = [bool]$settings.cleanupOnComplete
		}
	}
	# 戻り値を抑制
	$null
}

# ステップビューを更新する関数
function Update-StepsView {
	$script:lstSteps.Items.Clear()

	if ($script:Config -and $script:Config.workflow -and $script:Config.workflow.steps) {
		$stepNumber = 1
		foreach ($step in $script:Config.workflow.steps) {
			$item = New-Object System.Windows.Forms.ListViewItem($stepNumber.ToString())
			$item.SubItems.Add($step.id) | Out-Null
			$item.SubItems.Add($step.name) | Out-Null
			$item.SubItems.Add($step.description) | Out-Null
			$item.SubItems.Add($step.script) | Out-Null
			$item.SubItems.Add($step.type) | Out-Null
			$item.SubItems.Add($step.runAsAdmin.ToString()) | Out-Null
			$item.SubItems.Add($step.rebootRequired.ToString()) | Out-Null
			$script:lstSteps.Items.Add($item) | Out-Null
			$stepNumber++
		}
	}
	# 戻り値を抑制
	$null
}

# ステップ詳細を表示する関数
function Show-StepDetails {
	param([string]$StepId)

	if ($script:Config -and $script:Config.workflow -and $script:Config.workflow.steps) {
		$step = $script:Config.workflow.steps | Where-Object { $_.id -eq $StepId }
		if ($step) {
			$script:txtStepId.Text = $step.id
			$script:txtStepName.Text = $step.name
			$script:txtStepDescription.Text = $step.description
			$script:txtScript.Text = $step.script
			$script:cmbStepType.SelectedItem = $step.type
			$script:chkRunAsAdmin.Checked = [bool]$step.runAsAdmin
			$script:chkRebootRequired.Checked = [bool]$step.rebootRequired
			$script:numTimeout.Value = [int]$step.timeout
			$script:numRetryCount.Value = [int]$step.retryCount
			$script:cmbOnError.SelectedItem = $step.onError
		}
	}
}

# 基本設定を適用する関数
function Apply-BasicSettings {
	if ($script:Config -and $script:Config.workflow) {
		$script:Config.workflow.name = $script:txtName.Text
		$script:Config.workflow.version = $script:txtVersion.Text
		$script:Config.workflow.description = $script:txtDescription.Text

		if (-not $script:Config.workflow.settings) {
			$script:Config.workflow.settings = @{}
		}

		$script:Config.workflow.settings.maxRetries = [int]$script:numMaxRetries.Value
		$script:Config.workflow.settings.retryDelay = [int]$script:numRetryDelay.Value
		$script:Config.workflow.settings.logLevel = $script:cmbLogLevel.SelectedItem
		$script:Config.workflow.settings.enableReboot = $script:chkEnableReboot.Checked
		$script:Config.workflow.settings.cleanupOnComplete = $script:chkCleanupOnComplete.Checked

		[System.Windows.Forms.MessageBox]::Show(
			"基本設定を適用しました。",
			"適用完了",
			[System.Windows.Forms.MessageBoxButtons]::OK,
			[System.Windows.Forms.MessageBoxIcon]::Information
		)
	}
}

# ステップ設定を適用する関数
function Apply-StepSettings {
	if ($script:Config -and $script:Config.workflow -and $script:Config.workflow.steps -and $script:txtStepId.Text) {
		$stepId = $script:txtStepId.Text
		$step = $script:Config.workflow.steps | Where-Object { $_.id -eq $stepId }

		if ($step) {
			$step.name = $script:txtStepName.Text
			$step.description = $script:txtStepDescription.Text
			$step.script = $script:txtScript.Text
			$step.type = $script:cmbStepType.SelectedItem
			$step.runAsAdmin = $script:chkRunAsAdmin.Checked
			$step.rebootRequired = $script:chkRebootRequired.Checked
			$step.timeout = [int]$script:numTimeout.Value
			$step.retryCount = [int]$script:numRetryCount.Value
			$step.onError = $script:cmbOnError.SelectedItem

			# ステップ一覧を更新
			Update-StepsView

			[System.Windows.Forms.MessageBox]::Show(
				"ステップ設定を適用しました。",
				"適用完了",
				[System.Windows.Forms.MessageBoxButtons]::OK,
				[System.Windows.Forms.MessageBoxIcon]::Information
			)
		}
	}
}

# メイン処理
try {	# 設定ファイルのパスを確認
	if (-not (Test-Path $ConfigPath)) {
		if (-not (Test-Path "config\workflow.json")) {
			Write-Host "エラー: 設定ファイルが見つかりません。" -ForegroundColor Red
			Write-host "現在のディレクトリ: $(Get-Location)" -ForegroundColor Yellow
			Write-host "指定されたパス: $ConfigPath" -ForegroundColor Yellow
			exit 1
		}
		else {
			$ConfigPath = "config\workflow.json"
		}
	}

	$script:ConfigFilePath = Resolve-Path $ConfigPath
	# 設定を読み込み
	$script:Config = Load-WorkflowConfig -Path $script:ConfigFilePath
	if ($script:Config) {
		Write-Host "設定ファイルの読み込みに成功しました。" -ForegroundColor Green		# フォームを作成して表示
		Write-Host "フォーム作成中..." -ForegroundColor Yellow
		$form = Create-MainForm
		Write-Host "フォーム作成完了。型: $($form.GetType().FullName)" -ForegroundColor Yellow

		# フォームが正しく作成されたかチェック
		if ($form -is [System.Windows.Forms.Form]) {
			Write-Host "フォームの型確認OK" -ForegroundColor Green			# 初期データを読み込み
			Write-Host "初期データ読み込み中..." -ForegroundColor Yellow
			Update-BasicSettings
			Update-StepsView
			Write-Host "初期データ読み込み完了" -ForegroundColor Green			# フォームを表示
			Write-Host "Workflow Configuration Editorを起動しています..." -ForegroundColor Cyan
			[System.Windows.Forms.Application]::EnableVisualStyles()			# フォームをアクティブ化
			$form.BringToFront()   # 前面に移動
			$form.Activate()       # アクティブ化
			Write-Host "ShowDialog()を呼び出します..." -ForegroundColor Yellow
			$null = $form.ShowDialog()
			Write-Host "アプリケーションが終了しました。" -ForegroundColor Green
		} else {
			Write-host "エラー: フォームの作成に失敗しました。フォーム型: $($form.GetType())" -ForegroundColor Red
		}
	} else {
		Write-Host "エラー: 設定ファイルの読み込みに失敗しました。" -ForegroundColor Red
	}
}
catch {
	Write-Host "エラーが発生しました: $($_.Exception.Message)" -ForegroundColor Red
	Write-Host "スタックトレース: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}
