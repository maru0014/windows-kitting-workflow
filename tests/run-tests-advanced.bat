@echo off

setlocal enabledelayedexpansion

echo ====================================
echo  Windows Kitting Workflow テストスイート
echo  （詳細オプション付き）
echo ====================================
echo.

if "%1"=="/?" goto :help
if "%1"=="--help" goto :help
if "%1"=="-h" goto :help

:: PowerShell実行ポリシーの確認・設定
echo PowerShell実行ポリシーを確認中...
powershell -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted') { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'PowerShell実行ポリシーをRemoteSignedに設定しました' -ForegroundColor Green } else { Write-Host '実行ポリシーは既に適切に設定されています' -ForegroundColor Green }"

echo.

:: パラメータの解析と実行
if "%1"=="fix" (
    echo 自動修復付きでテストを実行します...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -Fix -Verbose
) else if "%1"=="json" (
    echo JSON設定ファイルのテストのみを実行します...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Test-JsonConfiguration.ps1" -Verbose
) else if "%1"=="structure" (
    echo プロジェクト構造のテストのみを実行します...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Test-ProjectStructure.ps1" -Verbose
) else if "%1"=="report" (
    echo 詳細レポート生成付きでテストを実行します...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -GenerateReport -OutputJson -Verbose
) else if "%1"=="quick" (
    echo クイックテスト（エラー時停止なし）を実行します...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -ContinueOnFailure
) else (
    echo 標準テスト（レポート生成付き）を実行します...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -GenerateReport -OutputJson -Verbose
)

:: 終了コードを保持
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% equ 0 (
    echo ? テストが正常に完了しました
) else (
    echo ? テストでエラーが発生しました（終了コード: %EXITCODE%）
)

echo.
echo 何かキーを押すと終了します...
pause > nul

exit /b %EXITCODE%

:help
echo.
echo 使用方法:
echo   run-tests-advanced.bat [オプション]
echo.
echo オプション:
echo   （なし）      標準テスト（レポート生成付き）
echo   fix          自動修復付きテスト
echo   json         JSON設定ファイルのテストのみ
echo   structure    プロジェクト構造のテストのみ
echo   report       詳細レポート生成付きテスト
echo   quick        クイックテスト（エラー時継続）
echo   /?, -h, --help  このヘルプを表示
echo.
echo 例:
echo   run-tests-advanced.bat          標準テスト（レポート生成付き）
echo   run-tests-advanced.bat fix      問題の自動修復を試行
echo   run-tests-advanced.bat json     JSONファイルのみテスト
echo   run-tests-advanced.bat report   詳細レポート生成
echo.
pause
exit /b 0
