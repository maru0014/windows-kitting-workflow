@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM Windows Kitting Workflow ���C���G���g���[�|�C���g
REM Windows 11 PC �t���I�[�g�Z�b�g�A�b�v
REM ============================================================================

echo.
echo ========================================
echo  Windows Kitting Workflow v1.0
echo  Windows 11 Auto Setup System
echo ========================================
echo.

REM �Ǘ��Ҍ����`�F�b�N
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] ���̃X�N���v�g�͊Ǘ��Ҍ����Ŏ��s����K�v������܂��B
    echo �Ǘ��҂Ƃ��ăR�}���h�v�����v�g���J���čĎ��s���Ă��������B
    pause
    exit /b 1
)

REM �J�����g�f�B���N�g�����X�N���v�g�̏ꏊ�ɐݒ�
cd /d "%~dp0"

REM ���O�f�B���N�g���̍쐬
if not exist "logs" mkdir logs
if not exist "status" mkdir status

REM �J�n�����̋L�^�iUTF-8 BOM�Ń��O�t�@�C�����������j
powershell -Command "[System.IO.File]::WriteAllText('logs\\workflow.log', \"`[$([DateTime]::Now.ToString('yyyy/MM/dd HH:mm:ss'))] [INFO] Windows Kitting Workflow�J�n`r`n\", [System.Text.Encoding]::UTF8)"

echo [INFO] �Ǘ��Ҍ������m�F���܂���
echo [INFO] ���[�N�t���[�f�B���N�g��: %CD%

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

REM �ݒ�t�@�C���̑��݊m�F
if not exist "config\workflow.json" (
    echo [ERROR] ���[�N�t���[�ݒ�t�@�C����������܂���: config\workflow.json
    pause
    exit /b 1
)

if not exist "config\notifications.json" (
    echo [ERROR] �ʒm�ݒ�t�@�C����������܂���: config\notifications.json
    pause
    exit /b 1
)

if not exist "MainWorkflow.ps1" (
    echo [ERROR] ���C�����[�N�t���[�t�@�C����������܂���: MainWorkflow.ps1
    pause
    exit /b 1
)

echo [INFO] �ݒ�t�@�C�����m�F���܂���
echo [INFO] ���C�����[�N�t���[���J�n���܂�...
echo.

REM ���C��PowerShell���[�N�t���[�̎��s
powershell -ExecutionPolicy Bypass -File "MainWorkflow.ps1" -ConfigPath "config\workflow.json" -NotificationConfigPath "config\notifications.json"

set exitCode=%errorLevel%

if %exitCode% equ 0 (
    echo.
    echo ========================================
    echo  ���[�N�t���[������Ɋ������܂����I
    echo ========================================
    echo [INFO] �I������: %date% %time%
    echo [INFO] ���O�t�@�C��: %CD%\logs\workflow.log
) else (
    echo.
    echo ========================================
    echo  ���[�N�t���[�ŃG���[���������܂���
    echo ========================================
    echo [ERROR] �I���R�[�h: %exitCode%
    echo [ERROR] �ڍׂ̓��O�t�@�C�����m�F���Ă�������: %CD%\logs\error.log
)

echo.
echo ���O�t�@�C���̏ꏊ:
echo - ���C�����O: %CD%\logs\workflow.log
echo - �G���[���O: %CD%\logs\error.log
echo - �X�N���v�g���O: %CD%\logs\scripts\
echo.

if "%1" neq "/silent" (
    pause
)

exit /b %exitCode%
