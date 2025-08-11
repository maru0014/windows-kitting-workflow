function Disable-StartupAppByName {
	<#
    .SYNOPSIS
      タスク マネージャーの「スタートアップ アプリ」で指定名に一致する項目を無効化します。
    .EXAMPLE
      Disable-StartupAppByName -Name "OneDrive"
      Disable-StartupAppByName -Name "Teams" -AllUsers
    #>
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory)][string]$Name,
		[switch]$AllUsers
	)

	$paths = [System.Collections.Generic.List[string]]::new()
	$paths.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run')
	$paths.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32')
	$paths.Add('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder')
	$runPaths = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')

	if ($AllUsers) {
		$paths.Add('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run')
		$paths.Add('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32')
		$runPaths += 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
	}

	$changed = @()

	foreach ($p in $paths) {
		if (-not (Test-Path $p)) { continue }
		$key = Get-Item $p
		foreach ($val in $key.GetValueNames()) {
			if ($val -like "*$Name*") {
				$data = [byte[]]($key.GetValue($val, $null, 'DoNotExpandEnvironmentNames'))
				if (-not $data) { continue }
				if ($PSCmdlet.ShouldProcess("$p\$val", "Disable (set first byte 0x03)")) {
					if ($data[0] -ne 0x03) {
						$data[0] = 0x03
						Set-ItemProperty -Path $p -Name $val -Value $data | Out-Null
						$changed += [pscustomobject]@{ Path = $p; Name = $val; Action = "Disabled" }
					}
					else {
						$changed += [pscustomobject]@{ Path = $p; Name = $val; Action = "AlreadyDisabled" }
					}
				}
			}
		}
	}

	# StartupApproved に項目が無いが Run 側にあるケース → 無効レコードを新規作成
	foreach ($rp in $runPaths) {
		if (-not (Test-Path $rp)) { continue }
		$runKey = Get-Item $rp
		foreach ($val in $runKey.GetValueNames()) {
			if ($val -like "*$Name*") {
				# どの Approved キーに置くか：Run/Run32 は 64/32bit に合わせて両方作って問題ありません
				$approvedTargets = @(
					$rp.Replace('\CurrentVersion\Run', '\CurrentVersion\Explorer\StartupApproved\Run'),
					$rp.Replace('\CurrentVersion\Run', '\CurrentVersion\Explorer\StartupApproved\Run32')
				)
				foreach ($ap in $approvedTargets) {
					if (-not (Test-Path $ap)) { New-Item -Path $ap -Force | Out-Null }
					if ($PSCmdlet.ShouldProcess("$ap\$val", "Create disabled entry")) {
						# 先頭0x03（無効）、残りゼロのシンプルなレコード
						$disabled = [byte[]](0x03, 0, 0, 0, 0, 0, 0, 0)
						New-ItemProperty -Path $ap -Name $val -PropertyType Binary -Value $disabled -Force | Out-Null
						$changed += [pscustomobject]@{ Path = $ap; Name = $val; Action = "CreatedDisabledEntry" }
					}
				}
			}
		}
	}

	if ($changed.Count -eq 0) {
		Write-Host "『$Name』に一致するスタートアップ項目は見つかりませんでした。" -ForegroundColor Yellow
	}
 else {
		$changed | Format-Table -AutoSize
		Write-Host "完了。必要に応じてサインアウト/再起動してください。" -ForegroundColor Green
	}
}

# 使い方例
# OneDrive だけ無効化（現在のユーザー）
# Disable-StartupAppByName -Name "OneDrive"

# Teams に一致するものを全ユーザー領域も含めて無効化（管理者で実行）
# Disable-StartupAppByName -Name "Teams" -AllUsers
