@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Workflow Editor 起動スクリプト
REM Windows Kitting Workflow 設定GUI
REM ============================================================================

echo.
echo ========================================
echo  Workflow Editor v1.0
echo  Windows Kitting Workflow 設定GUI
echo ========================================
echo.

REM カレントディレクトリをスクリプトの場所に設定
cd /d "%~dp0"

REM ログディレクトリの作成
if not exist "logs" mkdir logs

echo [INFO] ワークフローエディターディレクトリ: %CD%

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

REM 既定の設定ファイルの存在確認
if not exist "config\workflow.json" (
    echo [WARN] 既定の設定ファイルが見つかりません: config\workflow.json
    echo [INFO] カスタム設定ファイルを指定する場合は、起動後に「ファイル」→「開く」を使用してください
    echo.
)

REM メインスクリプトの存在確認
if not exist "WorkflowEditor.ps1" (
    echo [ERROR] WorkflowEditorファイルが見つかりません: WorkflowEditor.ps1
    pause
    exit /b 1
)

echo [INFO] 設定ファイルを確認しました
echo [INFO] Workflow Editorを起動します...
echo.

REM コマンドライン引数があるかチェック
if "%1" neq "" (
    echo [INFO] カスタム設定ファイルを指定: %1
    powershell -ExecutionPolicy Bypass -File "WorkflowEditor.ps1" -ConfigPath "%1"
) else (
    echo [INFO] 既定の設定ファイルで起動
    powershell -ExecutionPolicy Bypass -File "WorkflowEditor.ps1"
)

set exitCode=%errorLevel%

if %exitCode% equ 0 (
    echo.
    echo ========================================
    echo  Workflow Editorが正常に終了しました
    echo ========================================
) else (
    echo.
    echo ========================================
    echo  Workflow Editorでエラーが発生しました
    echo ========================================
    echo [ERROR] 終了コード: %exitCode%
    echo [ERROR] 詳細はコンソール出力を確認してください
)

echo.
echo 使用方法:
echo - 既定の設定ファイル: workflow-editor.bat
echo - カスタム設定ファイル: workflow-editor.bat "path\to\workflow.json"
echo.

if "%2" neq "/silent" (
    pause
)

exit /b %exitCode%
