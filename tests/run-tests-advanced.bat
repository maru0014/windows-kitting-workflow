@echo off

setlocal enabledelayedexpansion

echo ====================================
echo  Windows Kitting Workflow �e�X�g�X�C�[�g
echo  �i�ڍ׃I�v�V�����t���j
echo ====================================
echo.

if "%1"=="/?" goto :help
if "%1"=="--help" goto :help
if "%1"=="-h" goto :help

:: PowerShell���s�|���V�[�̊m�F�E�ݒ�
echo PowerShell���s�|���V�[���m�F��...
powershell -Command "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted') { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'PowerShell���s�|���V�[��RemoteSigned�ɐݒ肵�܂���' -ForegroundColor Green } else { Write-Host '���s�|���V�[�͊��ɓK�؂ɐݒ肳��Ă��܂�' -ForegroundColor Green }"

echo.

:: �p�����[�^�̉�͂Ǝ��s
if "%1"=="fix" (
    echo �����C���t���Ńe�X�g�����s���܂�...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -Fix -Verbose
) else if "%1"=="json" (
    echo JSON�ݒ�t�@�C���̃e�X�g�݂̂����s���܂�...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Test-JsonConfiguration.ps1" -Verbose
) else if "%1"=="structure" (
    echo �v���W�F�N�g�\���̃e�X�g�݂̂����s���܂�...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Test-ProjectStructure.ps1" -Verbose
) else if "%1"=="report" (
    echo �ڍ׃��|�[�g�����t���Ńe�X�g�����s���܂�...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -GenerateReport -OutputJson -Verbose
) else if "%1"=="quick" (
    echo �N�C�b�N�e�X�g�i�G���[����~�Ȃ��j�����s���܂�...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -ContinueOnFailure
) else (
    echo �W���e�X�g�i���|�[�g�����t���j�����s���܂�...
    powershell -ExecutionPolicy RemoteSigned -File "%~dp0Run-AllTests.ps1" -GenerateReport -OutputJson -Verbose
)

:: �I���R�[�h��ێ�
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE% equ 0 (
    echo ? �e�X�g������Ɋ������܂���
) else (
    echo ? �e�X�g�ŃG���[���������܂����i�I���R�[�h: %EXITCODE%�j
)

echo.
echo �����L�[�������ƏI�����܂�...
pause > nul

exit /b %EXITCODE%

:help
echo.
echo �g�p���@:
echo   run-tests-advanced.bat [�I�v�V����]
echo.
echo �I�v�V����:
echo   �i�Ȃ��j      �W���e�X�g�i���|�[�g�����t���j
echo   fix          �����C���t���e�X�g
echo   json         JSON�ݒ�t�@�C���̃e�X�g�̂�
echo   structure    �v���W�F�N�g�\���̃e�X�g�̂�
echo   report       �ڍ׃��|�[�g�����t���e�X�g
echo   quick        �N�C�b�N�e�X�g�i�G���[���p���j
echo   /?, -h, --help  ���̃w���v��\��
echo.
echo ��:
echo   run-tests-advanced.bat          �W���e�X�g�i���|�[�g�����t���j
echo   run-tests-advanced.bat fix      ���̎����C�������s
echo   run-tests-advanced.bat json     JSON�t�@�C���̂݃e�X�g
echo   run-tests-advanced.bat report   �ڍ׃��|�[�g����
echo.
pause
exit /b 0
