rem Wi-Fi設定プロファイル適用
rem 詳細: docs\Wi-Fi-Configuration-Guide.md を参照
rem 使用方法: setup-wifi.bat [Wi-FiプロファイルXMLファイルのパス]
rem 例: setup-wifi.bat config\office-wifi.xml
rem 引数を指定しない場合: config\wi-fi.xml が使用されます

echo === Wi-Fi設定プロファイル適用開始 ===
echo Wi-Fi設定プロファイルを適用します。
echo 詳細情報: docs\Wi-Fi-Configuration-Guide.md

rem ワークフローのルートディレクトリに移動
cd /d "%~dp0\..\.."

rem statusディレクトリが存在しない場合は作成
if not exist "status" mkdir status

rem Wi-Fi設定プロファイルファイルのパス（引数から取得、デフォルトは固定パス）
if "%~1"=="" (
    set WIFI_PROFILE_PATH=config\wi-fi.xml
    echo 引数が指定されていないため、デフォルトのプロファイルを使用します: %WIFI_PROFILE_PATH%
) else (
    set WIFI_PROFILE_PATH=%~1
    echo 指定されたプロファイルを使用します: %WIFI_PROFILE_PATH%
)

rem Wi-Fi設定プロファイルファイルの存在確認
if not exist "%WIFI_PROFILE_PATH%" (
    echo エラー: Wi-Fi設定プロファイルファイルが見つかりません: %WIFI_PROFILE_PATH%
    echo.
    echo 使用方法:
    echo   setup-wifi.bat [Wi-FiプロファイルXMLファイルのパス]
    echo   例: setup-wifi.bat config\office-wifi.xml
    echo   引数を指定しない場合: config\wi-fi.xml が使用されます
    exit /b 1
)

echo Wi-Fi設定プロファイルを適用しています: %WIFI_PROFILE_PATH%

rem Wi-Fiアダプターの状態を確認
echo Wi-Fiアダプターの状態を確認しています...
netsh interface show interface | findstr /i "wireless\|wi-fi\|wlan" | findstr /i "enabled"
if %errorlevel% neq 0 (
    echo Wi-Fiアダプターが無効になっています。有効化を試行します...

    rem Wi-Fiアダプターを有効化
    netsh interface set interface "Wi-Fi" enable 2>nul
    if %errorlevel% neq 0 (
        netsh interface set interface "Wireless Network Connection" enable 2>nul
        if %errorlevel% neq 0 (
            netsh interface set interface "WLAN" enable 2>nul
            if %errorlevel% neq 0 (
                echo 警告: Wi-Fiアダプターの有効化に失敗しました。
                echo 手動でWi-Fiアダプターを有効にしてから再実行してください。
                echo 方法: [設定] > [ネットワークとインターネット] > [Wi-Fi] から有効化
                exit /b 1
            )
        )
    )

    rem 少し待機してからアダプターの状態を再確認
    timeout /t 3 /nobreak >nul
    echo Wi-Fiアダプターの有効化後の状態確認...
    netsh interface show interface | findstr /i "wireless\|wi-fi\|wlan" | findstr /i "enabled"
    if %errorlevel% neq 0 (
        echo 警告: Wi-Fiアダプターが正常に有効化されていません。
        echo 手動でWi-Fiアダプターを確認してください。
        exit /b 1
    )
    echo Wi-Fiアダプターが正常に有効化されました。
) else (
    echo Wi-Fiアダプターは既に有効になっています。
)

rem Wi-Fiプロファイルを追加
netsh wlan add profile filename="%WIFI_PROFILE_PATH%"
if %errorlevel% neq 0 (
    echo エラー: Wi-Fi設定プロファイルの追加に失敗しました。
    echo 詳細: 管理者権限で実行されているか確認してください。
    exit /b 1
)

echo Wi-Fi設定プロファイルが正常に適用されました。

rem Wi-Fiプロファイルの一覧を表示（確認用）
echo 現在のWi-Fiプロファイル一覧:
netsh wlan show profiles

rem 完了マーカーは MainWorkflow 側で作成されます
echo === Wi-Fi設定プロファイル適用完了 ===
echo Wi-Fi設定プロファイルの適用が正常に完了しました。
exit /b 0
