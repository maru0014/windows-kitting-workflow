@echo off

setlocal enabledelayedexpansion

echo ====================================
echo  Windows Kitting Workflow �e�X�g�X�C�[�g
echo ====================================
echo.

:: PowerShell���s�|���V�[�̊m�F�E�ݒ�
echo PowerShell���s�|���V�[���m�F��...
powershell -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted') { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'PowerShell���s�|���V�[��RemoteSigned�ɐݒ肵�܂���' -ForegroundColor Green } else { Write-Host '���s�|���V�[�͊��ɓK�؂ɐݒ肳��Ă��܂�' -ForegroundColor Green }"

echo.
echo �e�X�g���J�n���܂�...
echo.

:: Run-AllTests.ps1�����s
powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" %*

:: �I���R�[�h��ێ�
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% equ 0 (
    echo ? ���ׂẴe�X�g������Ɋ������܂���
) else (
    echo ? �e�X�g�ŃG���[���������܂����i�I���R�[�h: %EXITCODE%�j
    echo   �ڍׂ͏�L�̏o�͂��m�F���Ă�������
)

echo.
echo �����L�[�������ƏI�����܂�...
pause > nul

exit /b %EXITCODE%
