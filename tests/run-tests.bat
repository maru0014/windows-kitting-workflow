@echo off

setlocal enabledelayedexpansion

echo ====================================
echo  Windows Kitting Workflow テストスイート
echo ====================================
echo.

:: PowerShell実行ポリシーの確認・設定
echo PowerShell実行ポリシーを確認中...
powershell -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted') { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'PowerShell実行ポリシーをRemoteSignedに設定しました' -ForegroundColor Green } else { Write-Host '実行ポリシーは既に適切に設定されています' -ForegroundColor Green }"

echo.
echo テストを開始します...
echo.

:: Run-AllTests.ps1を実行
powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" %*

:: 終了コードを保持
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% equ 0 (
    echo ? すべてのテストが正常に完了しました
) else (
    echo ? テストでエラーが発生しました（終了コード: %EXITCODE%）
    echo   詳細は上記の出力を確認してください
)

echo.
echo 何かキーを押すと終了します...
pause > nul

exit /b %EXITCODE%
