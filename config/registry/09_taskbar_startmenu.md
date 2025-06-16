# タスクバー・スタートメニューカスタマイズ

このレジストリファイルは、Windows 11のタスクバーとスタートメニューの設定を行います。

## 設定内容

### TaskbarGlomLevel
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `TaskbarGlomLevel`
- **設定値**: `dword:00000002`
- **意味**: タスクバーボタンのグループ化レベル設定
- **選択肢**:
  - `0` (dword:00000000): 常にグループ化、ラベル非表示
  - `1` (dword:00000001): タスクバーが満杯の時のみグループ化
  - `2` (dword:00000002): グループ化しない

### TaskbarGlomming
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `TaskbarGlomming`
- **設定値**: `dword:00000000`
- **意味**: タスクバーボタンのグループ化制御
- **選択肢**:
  - `0` (dword:00000000): グループ化しない
  - `1` (dword:00000001): グループ化する

### TaskbarSmallIcons
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `TaskbarSmallIcons`
- **設定値**: `dword:00000001`
- **意味**: タスクバーアイコンサイズ設定
- **選択肢**:
  - `0` (dword:00000000): 大きなアイコン
  - `1` (dword:00000001): 小さなアイコン

### Start_TrackDocs
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `Start_TrackDocs`
- **設定値**: `dword:00000000`
- **意味**: スタートメニューでの最近使ったファイル追跡設定
- **選択肢**:
  - `0` (dword:00000000): 追跡しない（表示しない）
  - `1` (dword:00000001): 追跡する（表示する）

### EnableAutoTray
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `EnableAutoTray`
- **設定値**: `dword:00000000`
- **意味**: 通知領域の自動非表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効（自動非表示しない）
  - `1` (dword:00000001): 有効（自動非表示する）

### ShowSecondsInSystemClock
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ShowSecondsInSystemClock`
- **設定値**: `dword:00000001`
- **意味**: システム時計での秒表示制御
- **選択肢**:
  - `0` (dword:00000000): 秒を表示しない
  - `1` (dword:00000001): 秒を表示する

### OpenAtLogon
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage`
- **キー名**: `OpenAtLogon`
- **設定値**: `dword:00000000`
- **意味**: ログオン時のスタートメニュー自動表示制御
- **選択肢**:
  - `0` (dword:00000000): 自動表示しない
  - `1` (dword:00000001): 自動表示する

### SystemPaneSuggestionsEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SystemPaneSuggestionsEnabled`
- **設定値**: `dword:00000000`
- **意味**: システムペインでの提案表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効（提案を表示しない）
  - `1` (dword:00000001): 有効（提案を表示する）

### SubscribedContent-338388Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-338388Enabled`
- **設定値**: `dword:00000000`
- **意味**: Microsoft Store アプリの提案制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### SubscribedContent-338389Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-338389Enabled`
- **設定値**: `dword:00000000`
- **意味**: Microsoft Store アプリの提案制御（追加）
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### SubscribedContent-338393Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-338393Enabled`
- **設定値**: `dword:00000000`
- **意味**: 設定アプリの提案制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### SubscribedContent-353694Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-353694Enabled`
- **設定値**: `dword:00000000`
- **意味**: インクワークスペースの提案制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### SubscribedContent-353696Enabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`
- **キー名**: `SubscribedContent-353696Enabled`
- **設定値**: `dword:00000000`
- **意味**: 設定の提案制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### NoLogoff
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer`
- **キー名**: `NoLogoff`
- **設定値**: `dword:00000000`
- **意味**: ログオフボタンの表示制御
- **選択肢**:
  - `0` (dword:00000000): 表示
  - `1` (dword:00000001): 非表示

### NoClose
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer`
- **キー名**: `NoClose`
- **設定値**: `dword:00000000`
- **意味**: シャットダウンボタンの表示制御
- **選択肢**:
  - `0` (dword:00000000): 表示
  - `1` (dword:00000001): 非表示

### HistoryViewEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search`
- **キー名**: `HistoryViewEnabled`
- **設定値**: `dword:00000000`
- **意味**: 検索履歴表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効（履歴を表示しない）
  - `1` (dword:00000001): 有効（履歴を表示する）

### DeviceHistoryEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search`
- **キー名**: `DeviceHistoryEnabled`
- **設定値**: `dword:00000000`
- **意味**: デバイス履歴制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

## 効果
- タスクバーの操作性向上
- 不要な提案・広告の除去
- 一貫したユーザーインターフェース
- プライバシーの向上
- 業務用途に最適化された環境

## 注意事項
- 一部設定はユーザーログオン後に反映されます
- 時計の秒表示はシステムリソースを若干消費します
