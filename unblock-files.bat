@echo off
rem �t�@�C���̃Z�L�����e�B�u���b�N���ꊇ��������o�b�`�t�@�C��
echo �t�@�C���̃Z�L�����e�B�u���b�N�������J�n���܂�...

rem �o�b�`�t�@�C��������f�B���N�g���Ɉړ�
cd /d "%~dp0"

rem PowerShell�X�N���v�g�����s
powershell -ExecutionPolicy Bypass -File "scripts\Unblock-AllFiles.ps1" -Recurse

echo.
echo �������������܂����B
pause
