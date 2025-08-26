@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Windows Kitting Workflow メインエントリーポイント
REM Windows 11 PC フルオートセットアップ
REM ============================================================================

echo.
echo ========================================
echo  Windows Kitting Workflow v1.0
echo  Windows 11 Auto Setup System
echo ========================================
echo.

REM 管理者権限チェック
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] このスクリプトは管理者権限で実行する必要があります。
    echo 管理者としてコマンドプロンプトを開いて再実行してください。
    pause
    exit /b 1
)

REM カレントディレクトリをスクリプトの場所に設定
cd /d "%~dp0"

REM ログディレクトリの作成
if not exist "logs" mkdir logs
if not exist "status" mkdir status

REM 開始時刻の記録（UTF-8 BOMで追記。新規作成時のみBOM付与）
powershell -Command "$utf8 = New-Object System.Text.UTF8Encoding($true); [System.IO.File]::AppendAllText('logs\\workflow.log', \"`[$([DateTime]::Now.ToString('yyyy/MM/dd HH:mm:ss'))] [INFO] Windows Kitting Workflow開始`r`n\", $utf8)"

echo [INFO] 管理者権限を確認しました
echo [INFO] ワークフローディレクトリ: %CD%

REM PowerShell実行ポリシーの確認と設定
echo [INFO] PowerShell実行ポリシーを確認中...
powershell -Command "Get-ExecutionPolicy" | findstr /i "restricted allsigned" >nul
if %errorLevel% equ 0 (
    echo [INFO] PowerShell実行ポリシーを変更中...
    powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
    if !errorLevel! neq 0 (
        echo [ERROR] PowerShell実行ポリシーの変更に失敗しました
        pause
        exit /b 1
    )
)

REM 設定ファイルの存在確認
if not exist "config\workflow.json" (
    echo [ERROR] ワークフロー設定ファイルが見つかりません: config\workflow.json
    pause
    exit /b 1
)

if not exist "config\notifications.json" (
    echo [ERROR] 通知設定ファイルが見つかりません: config\notifications.json
    pause
    exit /b 1
)

if not exist "MainWorkflow.ps1" (
    echo [ERROR] メインワークフローファイルが見つかりません: MainWorkflow.ps1
    pause
    exit /b 1
)

echo [INFO] 設定ファイルを確認しました
echo [INFO] メインワークフローを開始します...
echo.

REM メインPowerShellワークフローの実行
powershell -ExecutionPolicy Bypass -File "MainWorkflow.ps1" -ConfigPath "config\workflow.json" -NotificationConfigPath "config\notifications.json"

set exitCode=%errorLevel%

if %exitCode% equ 0 (
    echo.
    echo ========================================
    echo  ワークフローが正常に完了しました！
    echo ========================================
    echo [INFO] 終了時刻: %date% %time%
    echo [INFO] ログファイル: %CD%\logs\workflow.log
) else (
    echo.
    echo ========================================
    echo  ワークフローでエラーが発生しました
    echo ========================================
    echo [ERROR] 終了コード: %exitCode%
    echo [ERROR] 詳細はログファイルを確認してください: %CD%\logs\error.log
)

echo.
echo ログファイルの場所:
echo - メインログ: %CD%\logs\workflow.log
echo - エラーログ: %CD%\logs\error.log
echo - スクリプトログ: %CD%\logs\scripts\
echo.

if "%1" neq "/silent" (
    pause
)

exit /b %exitCode%
