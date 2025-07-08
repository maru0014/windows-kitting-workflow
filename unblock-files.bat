@echo off
rem ファイルのセキュリティブロックを一括解除するバッチファイル
echo ファイルのセキュリティブロック解除を開始します...

rem バッチファイルがあるディレクトリに移動
cd /d "%~dp0"

rem PowerShellスクリプトを実行
powershell -ExecutionPolicy Bypass -File "scripts\Unblock-AllFiles.ps1" -Recurse

echo.
echo 処理が完了しました。
pause
