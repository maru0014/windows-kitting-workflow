@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Workflow Editor �N���X�N���v�g
REM Windows Kitting Workflow �ݒ�GUI
REM ============================================================================

echo.
echo ========================================
echo  Workflow Editor v1.0
echo  Windows Kitting Workflow �ݒ�GUI
echo ========================================
echo.

REM �J�����g�f�B���N�g�����X�N���v�g�̏ꏊ�ɐݒ�
cd /d "%~dp0"

REM ���O�f�B���N�g���̍쐬
if not exist "logs" mkdir logs

echo [INFO] ���[�N�t���[�G�f�B�^�[�f�B���N�g��: %CD%

REM PowerShell���s�|���V�[�̊m�F�Ɛݒ�
echo [INFO] PowerShell���s�|���V�[���m�F��...
powershell -Command "Get-ExecutionPolicy" | findstr /i "restricted allsigned" >nul
if %errorLevel% equ 0 (
    echo [INFO] PowerShell���s�|���V�[��ύX��...
    powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
    if !errorLevel! neq 0 (
        echo [ERROR] PowerShell���s�|���V�[�̕ύX�Ɏ��s���܂���
        pause
        exit /b 1
    )
)

REM ����̐ݒ�t�@�C���̑��݊m�F
if not exist "config\workflow.json" (
    echo [WARN] ����̐ݒ�t�@�C����������܂���: config\workflow.json
    echo [INFO] �J�X�^���ݒ�t�@�C�����w�肷��ꍇ�́A�N����Ɂu�t�@�C���v���u�J���v���g�p���Ă�������
    echo.
)

REM ���C���X�N���v�g�̑��݊m�F
if not exist "WorkflowEditor.ps1" (
    echo [ERROR] WorkflowEditor�t�@�C����������܂���: WorkflowEditor.ps1
    pause
    exit /b 1
)

echo [INFO] �ݒ�t�@�C�����m�F���܂���
echo [INFO] Workflow Editor���N�����܂�...
echo.

REM �R�}���h���C�����������邩�`�F�b�N
if "%1" neq "" (
    echo [INFO] �J�X�^���ݒ�t�@�C�����w��: %1
    powershell -ExecutionPolicy Bypass -File "WorkflowEditor.ps1" -ConfigPath "%1"
) else (
    echo [INFO] ����̐ݒ�t�@�C���ŋN��
    powershell -ExecutionPolicy Bypass -File "WorkflowEditor.ps1"
)

set exitCode=%errorLevel%

if %exitCode% equ 0 (
    echo.
    echo ========================================
    echo  Workflow Editor������ɏI�����܂���
    echo ========================================
) else (
    echo.
    echo ========================================
    echo  Workflow Editor�ŃG���[���������܂���
    echo ========================================
    echo [ERROR] �I���R�[�h: %exitCode%
    echo [ERROR] �ڍׂ̓R���\�[���o�͂��m�F���Ă�������
)

echo.
echo �g�p���@:
echo - ����̐ݒ�t�@�C��: workflow-editor.bat
echo - �J�X�^���ݒ�t�@�C��: workflow-editor.bat "path\to\workflow.json"
echo.

if "%2" neq "/silent" (
    pause
)

exit /b %exitCode%
