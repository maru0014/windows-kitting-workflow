rem administrator有効化
echo === administratorユーザー有効化開始 ===
echo administratorユーザーを有効化します。操作は不要です。

rem ワークフローのルートディレクトリに移動
cd /d "%~dp0\..\.."

rem statusディレクトリが存在しない場合は作成
if not exist "status" mkdir status

rem administratorユーザーを有効化
net user administrator /active:yes
if %errorlevel% neq 0 (
    echo エラー: administratorユーザーの有効化に失敗しました。
    exit /b 1
)

rem administratorユーザーのパスワードを設定
set ADMIN_PASSWORD=Admin1234
net user administrator %ADMIN_PASSWORD%
if %errorlevel% neq 0 (
    echo エラー: administratorユーザーのパスワード設定に失敗しました。
    exit /b 1
)

echo administratorユーザーを有効化しました。

rem 完了マーカーは MainWorkflow 側で作成されます
echo === administratorユーザー有効化完了 ===
echo administratorユーザーの有効化が正常に完了しました。
exit /b 0
