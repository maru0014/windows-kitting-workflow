# =============================================================================
# 共通: 実行中のスリープ/画面オフ/ロック抑止ユーティリティ
#   - SetThreadExecutionState を使用
#   - Start-KeepAwake / Stop-KeepAwake を提供
#   - 例外時も finally で Stop を呼べる構造に
# =============================================================================

# Win32 API 宣言（重複 Add-Type を避けるため型存在チェック）
if (-not ([System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetTypes() -as [type] } | Where-Object { $_.FullName -eq 'SleepUtil' })) {
	$code = @"
using System;
using System.Runtime.InteropServices;
public static class SleepUtil {
  [Flags]
  public enum EXECUTION_STATE : uint {
    ES_SYSTEM_REQUIRED  = 0x00000001,
    ES_DISPLAY_REQUIRED = 0x00000002,
    ES_CONTINUOUS       = 0x80000000
  }
  [DllImport("kernel32.dll")]
  public static extern EXECUTION_STATE SetThreadExecutionState(EXECUTION_STATE esFlags);
}
"@
	try { Add-Type -TypeDefinition $code -ErrorAction Stop | Out-Null } catch { }
}

function Start-KeepAwake {
	[CmdletBinding()]
	param(
		[switch]$DisplayRequired
	)

	$flags = [SleepUtil+EXECUTION_STATE]::ES_CONTINUOUS -bor [SleepUtil+EXECUTION_STATE]::ES_SYSTEM_REQUIRED
	if ($DisplayRequired) {
		$flags = $flags -bor [SleepUtil+EXECUTION_STATE]::ES_DISPLAY_REQUIRED
	}

	[void][SleepUtil]::SetThreadExecutionState($flags)
}

function Stop-KeepAwake {
	[CmdletBinding()]
	param()

	# ES_CONTINUOUS のみでフラグを解除
	[void][SleepUtil]::SetThreadExecutionState([SleepUtil+EXECUTION_STATE]::ES_CONTINUOUS)
}
