@echo off
rem �t�@�C���̃Z�L�����e�B�u���b�N���ꊇ��������o�b�`�t�@�C��
echo �t�@�C���̃Z�L�����e�B�u���b�N�������J�n���܂�...

rem PowerShell�X�N���v�g�����s
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\Unblock-AllFiles.ps1" -Recurse

echo.
echo �������������܂����B
pause
