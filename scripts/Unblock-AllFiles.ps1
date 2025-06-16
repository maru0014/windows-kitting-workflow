# ファイルのセキュリティブロックを一括解除するスクリプト
# 使用方法: .\Unblock-AllFiles.ps1

param(
	[string]$Path = ".",
	[switch]$Recurse,
	[switch]$WhatIf
)

Write-Host "ファイルのセキュリティブロック解除を開始します..." -ForegroundColor Green
Write-Host "対象パス: $(Resolve-Path $Path)" -ForegroundColor Yellow

# 対象ファイルの拡張子
$Extensions = @("*.ps1", "*.bat", "*.cmd", "*.exe", "*.msi", "*.zip", "*.reg")

$TotalUnblocked = 0

foreach ($Extension in $Extensions) {
	Write-Host "`n--- $Extension ファイルを処理中 ---" -ForegroundColor Cyan
	$Files = if (-not $Recurse) {
		Get-ChildItem -Path $Path -Filter $Extension -ErrorAction SilentlyContinue
	} else {
		Get-ChildItem -Path $Path -Filter $Extension -Recurse -ErrorAction SilentlyContinue
	}

	foreach ($File in $Files) {
		try {
			# Zone.Identifierストリームの存在確認
			$ZoneStream = Get-Item -Path $File.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue

			if ($ZoneStream) {
				if ($WhatIf) {
					Write-Host "  [WHATIF] ブロック解除対象: $($File.FullName)" -ForegroundColor Yellow
				}
				else {
					Unblock-File -Path $File.FullName
					Write-Host "  ✓ ブロック解除: $($File.FullName)" -ForegroundColor Green
					$TotalUnblocked++
				}
			}
		}
		catch {
			Write-Warning "  ✗ エラー: $($File.FullName) - $($_.Exception.Message)"
		}
	}
}

if ($WhatIf) {
	Write-Host "`n[WHATIF モード] 実際の処理は実行されていません" -ForegroundColor Yellow
}
else {
	Write-Host "`n処理完了: $TotalUnblocked 個のファイルのブロックを解除しました" -ForegroundColor Green
}

# 実行ポリシーの確認とアドバイス
$ExecutionPolicy = Get-ExecutionPolicy
Write-Host "`n現在の実行ポリシー: $ExecutionPolicy" -ForegroundColor Cyan

if ($ExecutionPolicy -eq "Restricted") {
	Write-Host "実行ポリシーが制限されています。以下のコマンドで変更できます:" -ForegroundColor Yellow
	Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
}
