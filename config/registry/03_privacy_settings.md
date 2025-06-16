# プライバシー設定

このレジストリファイルは、Windows 11のプライバシーとユーザーエクスペリエンスに関する設定を行います。

## 設定内容

### TailoredExperiencesWithDiagnosticDataEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy`
- **キー名**: `TailoredExperiencesWithDiagnosticDataEnabled`
- **設定値**: `dword:00000000`
- **意味**: 診断データを使用したカスタマイズ機能の制御
- **選択肢**:
  - `0` (dword:00000000): 無効（診断データに基づくパーソナライズを無効化）
  - `1` (dword:00000001): 有効（診断データに基づくパーソナライズを許可）

### SystemPaneSuggestionsEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SystemPaneSuggestionsEnabled`
- **設定値**: `dword:00000000`
- **意味**: システムペインでの提案表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効（提案を表示しない）
  - `1` (dword:00000001): 有効（提案を表示する）

### SilentInstalledAppsEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SilentInstalledAppsEnabled`
- **設定値**: `dword:00000000`
- **意味**: サイレントアプリインストールの制御
- **選択肢**:
  - `0` (dword:00000000): 無効（ユーザー同意なしでのアプリ自動インストールを防止）
  - `1` (dword:00000001): 有効（自動インストールを許可）

### ContentDeliveryAllowed
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `ContentDeliveryAllowed`
- **設定値**: `dword:00000000`
- **意味**: Microsoftからのコンテンツ配信制御
- **選択肢**:
  - `0` (dword:00000000): 無効（コンテンツ配信を無効化）
  - `1` (dword:00000001): 有効（コンテンツ配信を許可）

### OemPreInstalledAppsEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `OemPreInstalledAppsEnabled`
- **設定値**: `dword:00000000`
- **意味**: OEMプリインストールアプリの管理制御
- **選択肢**:
  - `0` (dword:00000000): 無効（OEMアプリの管理を無効化）
  - `1` (dword:00000001): 有効（OEMアプリの管理を許可）

### PreInstalledAppsEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `PreInstalledAppsEnabled`
- **設定値**: `dword:00000000`
- **意味**: プリインストールアプリの制御
- **選択肢**:
  - `0` (dword:00000000): 無効（プリインストールアプリを無効化）
  - `1` (dword:00000001): 有効（プリインストールアプリを許可）

### PreInstalledAppsEverEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `PreInstalledAppsEverEnabled`
- **設定値**: `dword:00000000`
- **意味**: プリインストールアプリ履歴の制御
- **選択肢**:
  - `0` (dword:00000000): 無効（履歴を無効化）
  - `1` (dword:00000001): 有効（履歴を有効化）

### SoftLandingEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SoftLandingEnabled`
- **設定値**: `dword:00000000`
- **意味**: ソフトランディング機能（アプリ推奨）の制御
- **選択肢**:
  - `0` (dword:00000000): 無効（アプリ推奨機能を無効化）
  - `1` (dword:00000001): 有効（アプリ推奨機能を有効化）

### SubscribedContentEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContentEnabled`
- **設定値**: `dword:00000000`
- **意味**: 購読コンテンツ配信の制御
- **選択肢**:
  - `0` (dword:00000000): 無効（購読型コンテンツの配信を無効化）
  - `1` (dword:00000001): 有効（購読型コンテンツの配信を有効化）

### ShowTaskViewButton
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ShowTaskViewButton`
- **設定値**: `dword:00000000`
- **意味**: タスクバーのタスクビューボタン表示制御
- **選択肢**:
  - `0` (dword:00000000): 非表示
  - `1` (dword:00000001): 表示

### ShowCortanaButton
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ShowCortanaButton`
- **設定値**: `dword:00000000`
- **意味**: タスクバーのCortanaボタン表示制御
- **選択肢**:
  - `0` (dword:00000000): 非表示
  - `1` (dword:00000001): 表示

## 効果
- プライバシー保護の強化
- 不要なアプリの自動インストール防止
- システムリソースの節約
- 業務用途に集中できる環境の構築
- Microsoft による追跡の軽減

## 推奨環境
- 企業環境
- プライバシーを重視する環境
- 管理されたPC環境
- 業務専用機

## 注意事項
- 一部のWindows機能が制限される可能性があります
- Microsoft アカウントの一部機能に影響する場合があります
- ユーザーエクスペリエンス向上機能が無効化されます
