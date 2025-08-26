rem Wi-Fi�ݒ�v���t�@�C���K�p
rem �ڍ�: docs\Wi-Fi-Configuration-Guide.md ���Q��
rem �g�p���@: setup-wifi.bat [Wi-Fi�v���t�@�C��XML�t�@�C���̃p�X]
rem ��: setup-wifi.bat config\office-wifi.xml
rem �������w�肵�Ȃ��ꍇ: config\wi-fi.xml ���g�p����܂�

echo === Wi-Fi�ݒ�v���t�@�C���K�p�J�n ===
echo Wi-Fi�ݒ�v���t�@�C����K�p���܂��B
echo �ڍ׏��: docs\Wi-Fi-Configuration-Guide.md

rem ���[�N�t���[�̃��[�g�f�B���N�g���Ɉړ�
cd /d "%~dp0\..\.."

rem status�f�B���N�g�������݂��Ȃ��ꍇ�͍쐬
if not exist "status" mkdir status

rem Wi-Fi�ݒ�v���t�@�C���t�@�C���̃p�X�i��������擾�A�f�t�H���g�͌Œ�p�X�j
if "%~1"=="" (
    set WIFI_PROFILE_PATH=config\wi-fi.xml
    echo �������w�肳��Ă��Ȃ����߁A�f�t�H���g�̃v���t�@�C�����g�p���܂�: %WIFI_PROFILE_PATH%
) else (
    set WIFI_PROFILE_PATH=%~1
    echo �w�肳�ꂽ�v���t�@�C�����g�p���܂�: %WIFI_PROFILE_PATH%
)

rem Wi-Fi�ݒ�v���t�@�C���t�@�C���̑��݊m�F
if not exist "%WIFI_PROFILE_PATH%" (
    echo �G���[: Wi-Fi�ݒ�v���t�@�C���t�@�C����������܂���: %WIFI_PROFILE_PATH%
    echo.
    echo �g�p���@:
    echo   setup-wifi.bat [Wi-Fi�v���t�@�C��XML�t�@�C���̃p�X]
    echo   ��: setup-wifi.bat config\office-wifi.xml
    echo   �������w�肵�Ȃ��ꍇ: config\wi-fi.xml ���g�p����܂�
    exit /b 1
)

echo Wi-Fi�ݒ�v���t�@�C����K�p���Ă��܂�: %WIFI_PROFILE_PATH%

rem Wi-Fi�A�_�v�^�[�̏�Ԃ��m�F
echo Wi-Fi�A�_�v�^�[�̏�Ԃ��m�F���Ă��܂�...
netsh interface show interface | findstr /i "wireless\|wi-fi\|wlan" | findstr /i "enabled"
if %errorlevel% neq 0 (
    echo Wi-Fi�A�_�v�^�[�������ɂȂ��Ă��܂��B�L���������s���܂�...

    rem Wi-Fi�A�_�v�^�[��L����
    netsh interface set interface "Wi-Fi" enable 2>nul
    if %errorlevel% neq 0 (
        netsh interface set interface "Wireless Network Connection" enable 2>nul
        if %errorlevel% neq 0 (
            netsh interface set interface "WLAN" enable 2>nul
            if %errorlevel% neq 0 (
                echo �x��: Wi-Fi�A�_�v�^�[�̗L�����Ɏ��s���܂����B
                echo �蓮��Wi-Fi�A�_�v�^�[��L���ɂ��Ă���Ď��s���Ă��������B
                echo ���@: [�ݒ�] > [�l�b�g���[�N�ƃC���^�[�l�b�g] > [Wi-Fi] ����L����
                exit /b 1
            )
        )
    )

    rem �����ҋ@���Ă���A�_�v�^�[�̏�Ԃ��Ċm�F
    timeout /t 3 /nobreak >nul
    echo Wi-Fi�A�_�v�^�[�̗L������̏�Ԋm�F...
    netsh interface show interface | findstr /i "wireless\|wi-fi\|wlan" | findstr /i "enabled"
    if %errorlevel% neq 0 (
        echo �x��: Wi-Fi�A�_�v�^�[������ɗL��������Ă��܂���B
        echo �蓮��Wi-Fi�A�_�v�^�[���m�F���Ă��������B
        exit /b 1
    )
    echo Wi-Fi�A�_�v�^�[������ɗL��������܂����B
) else (
    echo Wi-Fi�A�_�v�^�[�͊��ɗL���ɂȂ��Ă��܂��B
)

rem Wi-Fi�v���t�@�C����ǉ�
netsh wlan add profile filename="%WIFI_PROFILE_PATH%"
if %errorlevel% neq 0 (
    echo �G���[: Wi-Fi�ݒ�v���t�@�C���̒ǉ��Ɏ��s���܂����B
    echo �ڍ�: �Ǘ��Ҍ����Ŏ��s����Ă��邩�m�F���Ă��������B
    exit /b 1
)

echo Wi-Fi�ݒ�v���t�@�C��������ɓK�p����܂����B

rem Wi-Fi�v���t�@�C���̈ꗗ��\���i�m�F�p�j
echo ���݂�Wi-Fi�v���t�@�C���ꗗ:
netsh wlan show profiles

rem �����}�[�J�[�� MainWorkflow ���ō쐬����܂�
echo === Wi-Fi�ݒ�v���t�@�C���K�p���� ===
echo Wi-Fi�ݒ�v���t�@�C���̓K�p������Ɋ������܂����B
exit /b 0
