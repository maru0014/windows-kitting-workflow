rem administrator�L����
echo === administrator���[�U�[�L�����J�n ===
echo administrator���[�U�[��L�������܂��B����͕s�v�ł��B

rem ���[�N�t���[�̃��[�g�f�B���N�g���Ɉړ�
cd /d "%~dp0\..\.."

rem status�f�B���N�g�������݂��Ȃ��ꍇ�͍쐬
if not exist "status" mkdir status

rem administrator���[�U�[��L����
net user administrator /active:yes
if %errorlevel% neq 0 (
    echo �G���[: administrator���[�U�[�̗L�����Ɏ��s���܂����B
    exit /b 1
)

rem administrator���[�U�[�̃p�X���[�h��ݒ�
set ADMIN_PASSWORD=Admin1234
net user administrator %ADMIN_PASSWORD%
if %errorlevel% neq 0 (
    echo �G���[: administrator���[�U�[�̃p�X���[�h�ݒ�Ɏ��s���܂����B
    exit /b 1
)

echo administrator���[�U�[��L�������܂����B

rem ����Ɋ��������ꍇ�A�����t�@�C�����쐬
echo %date% %time% > status\enable-admin.completed
echo === administrator���[�U�[�L�������� ===
echo administrator���[�U�[�̗L����������Ɋ������܂����B
exit /b 0
