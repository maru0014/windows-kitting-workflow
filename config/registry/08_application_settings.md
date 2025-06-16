# Office・アプリケーション設定

このレジストリファイルは、Microsoft OfficeとWindows アプリケーションの設定を行います。

## 設定内容

### ShownFirstRunOptin
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\General`
- **キー名**: `ShownFirstRunOptin`
- **設定値**: `dword:00000001`
- **意味**: Office初回実行オプトイン画面の表示制御
- **選択肢**:
  - `0` (dword:00000000): 未表示（初回実行時に表示される）
  - `1` (dword:00000001): 表示済み（初回実行画面をスキップ）

### ShownFileFmtPrompt
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\General`
- **キー名**: `ShownFileFmtPrompt`
- **設定値**: `dword:00000001`
- **意味**: ファイル形式プロンプトの表示制御
- **選択肢**:
  - `0` (dword:00000000): 未表示
  - `1` (dword:00000001): 表示済み（プロンプトをスキップ）

### UserContentDisabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\Privacy`
- **キー名**: `UserContentDisabled`
- **設定値**: `dword:00000001`
- **意味**: ユーザーコンテンツの送信制御
- **選択肢**:
  - `0` (dword:00000000): 有効（コンテンツ送信を許可）
  - `1` (dword:00000001): 無効（コンテンツ送信を無効化）

### DownloadContentDisabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Common\Privacy`
- **キー名**: `DownloadContentDisabled`
- **設定値**: `dword:00000001`
- **意味**: オンラインコンテンツのダウンロード制御
- **選択肢**:
  - `0` (dword:00000000): 有効（ダウンロードを許可）
  - `1` (dword:00000001): 無効（ダウンロードを無効化）

### DoNotPromptForConvert (Word)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Word\Options`
- **キー名**: `DoNotPromptForConvert`
- **設定値**: `dword:00000001`
- **意味**: Word ファイル変換時のプロンプト制御
- **選択肢**:
  - `0` (dword:00000000): プロンプト表示
  - `1` (dword:00000001): プロンプト非表示

### ConfirmConversions
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Word\Options`
- **キー名**: `ConfirmConversions`
- **設定値**: `dword:00000000`
- **意味**: Word変換確認ダイアログの制御
- **選択肢**:
  - `0` (dword:00000000): 無効（確認ダイアログを表示しない）
  - `1` (dword:00000001): 有効（確認ダイアログを表示）

### DoNotPromptForConvert (Excel)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Office\16.0\Excel\Options`
- **キー名**: `DoNotPromptForConvert`
- **設定値**: `dword:00000001`
- **意味**: Excel ファイル変換時のプロンプト制御
- **選択肢**:
  - `0` (dword:00000000): プロンプト表示
  - `1` (dword:00000001): プロンプト非表示

### Chrome Command
- **フルパス**: `HKEY_CURRENT_USER\Software\Classes\Applications\chrome.exe\shell\open\command`
- **キー名**: `(既定)`
- **設定値**: `"\"C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe\" -- \"%1\""`
- **意味**: Google Chrome の起動コマンド設定
- **選択肢**: 任意のコマンドライン文字列

### HideMergeConflicts
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `HideMergeConflicts`
- **設定値**: `dword:00000000`
- **意味**: ファイルマージ競合の表示制御
- **選択肢**:
  - `0` (dword:00000000): 表示
  - `1` (dword:00000001): 非表示

### AppsUseLightTheme
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`
- **キー名**: `AppsUseLightTheme`
- **設定値**: `dword:00000000`
- **意味**: アプリケーションテーマ設定
- **選択肢**:
  - `0` (dword:00000000): ダークテーマ
  - `1` (dword:00000001): ライトテーマ

### SystemUsesLightTheme
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`
- **キー名**: `SystemUsesLightTheme`
- **設定値**: `dword:00000000`
- **意味**: システムテーマ設定
- **選択肢**:
  - `0` (dword:00000000): ダークテーマ
  - `1` (dword:00000001): ライトテーマ

## 効果
- Office初回起動時の設定スキップ
- プライバシー設定の強化
- 一貫したファイル関連付け
- 統一されたダークテーマの適用
- ユーザビリティの向上

## 注意事項
- Office 2016/2019/365 (Version 16.0) が対象
- Chromeのパスは標準インストール場所を想定
