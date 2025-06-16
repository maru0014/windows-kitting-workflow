# パフォーマンス設定

このレジストリファイルは、Windowsシステムのパフォーマンス向上に関する設定を行います。

## 設定内容

### UserPreferencesMask
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `UserPreferencesMask`
- **設定値**: `hex:9e,1e,07,80,12,00,00,00`
- **意味**: ユーザー設定マスク（視覚効果とパフォーマンスのバランス設定）
- **選択肢**: カスタム設定（16進数値による複合設定）

### AutoEndTasks
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `AutoEndTasks`
- **設定値**: `"1"`
- **意味**: 応答しないアプリケーションの自動終了
- **選択肢**:
  - `"0"`: 無効（手動で終了する必要がある）
  - `"1"`: 有効（自動的に終了する）

### HungAppTimeout
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `HungAppTimeout`
- **設定値**: `"1000"`
- **意味**: アプリケーションが応答しないと判断するまでの時間（ミリ秒）
- **選択肢**: 数値文字列（既定値: "5000"）

### WaitToKillAppTimeout
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `WaitToKillAppTimeout`
- **設定値**: `"2000"`
- **意味**: アプリケーション終了の待機時間（ミリ秒）
- **選択肢**: 数値文字列（既定値: "20000"）

### LowLevelHooksTimeout
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `LowLevelHooksTimeout`
- **設定値**: `"1000"`
- **意味**: 低レベルフックの応答タイムアウト（ミリ秒）
- **選択肢**: 数値文字列（既定値: "5000"）

### VisualFXSetting
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects`
- **キー名**: `VisualFXSetting`
- **設定値**: `dword:00000002`
- **意味**: 視覚効果レベルの設定
- **選択肢**:
  - `0` (dword:00000000): カスタム設定
  - `1` (dword:00000001): 最高の外観
  - `2` (dword:00000002): パフォーマンス重視
  - `3` (dword:00000003): 自動調整

### MouseHoverTime
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Mouse`
- **キー名**: `MouseHoverTime`
- **設定値**: `"400"`
- **意味**: ツールチップ表示までのマウスホバー時間（ミリ秒）
- **選択肢**: 数値文字列（既定値: "400"）

## 効果
- システム全体の応答性向上
- アプリケーションのフリーズ時間短縮
- 視覚効果を抑制してパフォーマンス優先
- マウス操作の快適性向上

## 推奨環境
- 業務用PC
- パフォーマンスを重視する環境
- 古いハードウェアでの動作改善
- サーバー環境（GUI使用時）

## 注意事項
- 視覚的な美しさが犠牲になります
- 一部のアプリケーションで表示が変わる可能性があります
- タイムアウト値は環境に応じて調整してください
