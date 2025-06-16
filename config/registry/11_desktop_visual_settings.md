# デスクトップ・視覚効果設定

このレジストリファイルは、Windows 11のデスクトップと視覚効果に関する設定を行います。

## 設定内容

### AutoArrange
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `AutoArrange`
- **設定値**: `"1"`
- **意味**: デスクトップアイコンの自動整列制御
- **選択肢**:
  - `"0"`: 無効（自動整列しない）
  - `"1"`: 有効（自動整列する）

### Wallpaper
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `Wallpaper`
- **設定値**: `""` (空文字)
- **意味**: デスクトップ壁紙の設定
- **選択肢**: ファイルパス文字列または空文字（無地背景）

### WallpaperStyle
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `WallpaperStyle`
- **設定値**: `"0"`
- **意味**: 壁紙の表示スタイル設定
- **選択肢**:
  - `"0"`: 中央に表示
  - `"2"`: 拡大して表示
  - `"6"`: フィット
  - `"10"`: フィル

### ScreenSaveActive
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `ScreenSaveActive`
- **設定値**: `"0"`
- **意味**: スクリーンセーバーの有効/無効制御
- **選択肢**:
  - `"0"`: 無効
  - `"1"`: 有効

### ScreenSaveTimeOut
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `ScreenSaveTimeOut`
- **設定値**: `"900"`
- **意味**: スクリーンセーバー開始時間（秒）
- **選択肢**: 数値文字列（秒単位）

### BorderWidth
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics`
- **キー名**: `BorderWidth`
- **設定値**: `"1"`
- **意味**: ウィンドウの境界線幅設定
- **選択肢**: 数値文字列（ピクセル単位）

### PaddedBorderWidth
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics`
- **キー名**: `PaddedBorderWidth`
- **設定値**: `"4"`
- **意味**: パディング境界線幅設定
- **選択肢**: 数値文字列（ピクセル単位）

### HideDesktopWallpaper
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `HideDesktopWallpaper`
- **設定値**: `dword:00000000`
- **意味**: デスクトップ壁紙の表示制御
- **選択肢**:
  - `0` (dword:00000000): 表示
  - `1` (dword:00000001): 非表示

### ShowInfoTip
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ShowInfoTip`
- **設定値**: `dword:00000000`
- **意味**: エクスプローラーでの詳細ペイン表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### FolderContentsInfoTip
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `FolderContentsInfoTip`
- **設定値**: `dword:00000000`
- **意味**: フォルダーのヒント表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### TaskbarAnimations
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `TaskbarAnimations`
- **設定値**: `dword:00000000`
- **意味**: タスクバーアニメーション制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### ListviewAlphaSelect (Advanced)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ListviewAlphaSelect`
- **設定値**: `dword:00000000`
- **意味**: リストビューのアルファ選択制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### EnableAeroPeek (DWM)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM`
- **キー名**: `EnableAeroPeek`
- **設定値**: `dword:00000000`
- **意味**: Aero Peek透明効果制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### CompositionPolicy
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM`
- **キー名**: `CompositionPolicy`
- **設定値**: `dword:00000000`
- **意味**: DWMコンポジション設定
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### EnableTransparency
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`
- **キー名**: `EnableTransparency`
- **設定値**: `dword:00000000`
- **意味**: システム全体の透明効果制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### VisualFXSetting
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`
- **キー名**: `VisualFXSetting`
- **設定値**: `dword:00000003`
- **意味**: 視覚効果レベル設定
- **選択肢**:
  - `0` (dword:00000000): カスタム設定
  - `1` (dword:00000001): 最高の外観
  - `2` (dword:00000002): パフォーマンス重視
  - `3` (dword:00000003): 自動調整

## 効果
- システムパフォーマンスの向上
- 視覚的な装飾の最小化
- 一貫したデスクトップ環境の提供
- 業務用途に適した設定

## 推奨環境
- 業務用PC
- パフォーマンスを重視する環境
- 古いハードウェア
- バッテリー駆動デバイス

## 注意事項
- 視覚的な美しさが犠牲になります
- 一部のユーザーには操作性が低下する可能性があります
- 設定後はサインアウト・サインインが推奨されます
