@echo off
rem ファイルのセキュリティブロックを一括解除するバッチファイル
echo ファイルのセキュリティブロック解除を開始します...

rem PowerShellスクリプトを実行
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Unblock-AllFiles.ps1" -Recurse

echo.
echo 処理が完了しました。
pause
