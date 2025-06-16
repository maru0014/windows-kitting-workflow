# Windows 11 UI設定

このレジストリファイルは、Windows 11特有のUI要素の設定を行います。

## 設定内容

### AllowNewsAndInterests
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Dsh`
- **キー名**: `AllowNewsAndInterests`
- **設定値**: `dword:00000000`
- **意味**: タスクバーのWidgetボタン表示制御
- **選択肢**:
  - `0` (dword:00000000): 非表示
  - `1` (dword:00000001): 表示

### TaskbarMn
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `TaskbarMn`
- **設定値**: `dword:00000000`
- **意味**: タスクバーのChatボタン表示制御
- **選択肢**:
  - `0` (dword:00000000): 非表示
  - `1` (dword:00000001): 表示

### SearchboxTaskbarMode
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `SearchboxTaskbarMode`
- **設定値**: `dword:00000001`
- **意味**: タスクバーの検索ボックス表示モード
- **選択肢**:
  - `0` (dword:00000000): 非表示
  - `1` (dword:00000001): 検索アイコンのみ表示
  - `2` (dword:00000002): 検索ボックス表示

### InlineSearch
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `InlineSearch`
- **設定値**: `dword:00000000`
- **意味**: Windows 11の新しいコンテキストメニューの制御
- **選択肢**:
  - `0` (dword:00000000): 従来のコンテキストメニューを使用
  - `1` (dword:00000001): 新しいコンテキストメニューを使用

### BingSearchEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search`
- **キー名**: `BingSearchEnabled`
- **設定値**: `dword:00000000`
- **意味**: Bing検索機能の制御
- **選択肢**:
  - `0` (dword:00000000): 無効（Bing検索を無効化）
  - `1` (dword:00000001): 有効（Bing検索を有効化）

### CortanaConsent
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search`
- **キー名**: `CortanaConsent`
- **設定値**: `dword:00000000`
- **意味**: Cortana・Web検索の同意設定
- **選択肢**:
  - `0` (dword:00000000): 無効（Web検索・Cortanaを無効化）
  - `1` (dword:00000001): 有効（Web検索・Cortanaを有効化）

### SilentInstalledAppsEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SilentInstalledAppsEnabled`
- **設定値**: `dword:00000000`
- **意味**: おすすめアプリの自動インストール制御
- **選択肢**:
  - `0` (dword:00000000): 無効（自動インストールを防止）
  - `1` (dword:00000001): 有効（自動インストールを許可）

### SubscribedContent-338388Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-338388Enabled`
- **設定値**: `dword:00000000`
- **意味**: Microsoft Store アプリのプロモーション制御
- **選択肢**:
  - `0` (dword:00000000): 無効（プロモーションを無効化）
  - `1` (dword:00000001): 有効（プロモーションを有効化）

### SubscribedContent-338389Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-338389Enabled`
- **設定値**: `dword:00000000`
- **意味**: Microsoft Store アプリのプロモーション制御（追加）
- **選択肢**:
  - `0` (dword:00000000): 無効（プロモーションを無効化）
  - `1` (dword:00000001): 有効（プロモーションを有効化）

## 効果
- Windows 11の新機能による画面の煩雑さを軽減
- 業務用途に不要な機能の無効化
- 従来のWindowsに近い操作感の維持
- システムリソースの節約

## 推奨環境
- 企業環境
- 業務専用機
- 従来のWindows操作に慣れたユーザー
- シンプルなデスクトップ環境を希望する場合

## 注意事項
- Windows 11の新機能が制限されます
- 一部のユーザーには操作性の向上機能が無効化されます
- 設定後はサインアウト・サインインが推奨されます
