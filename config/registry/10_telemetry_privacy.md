# テレメトリ・プライバシー強化設定

このレジストリファイルは、Windows 11のテレメトリとプライバシーに関する設定を強化します。

## 設定内容

### AllowTelemetry (Policies)
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection`
- **キー名**: `AllowTelemetry`
- **設定値**: `dword:00000000`
- **意味**: Windows テレメトリレベルの制御（ポリシー設定）
- **選択肢**:
  - `0` (dword:00000000): セキュリティのみ（Enterprise/Education版のみ）
  - `1` (dword:00000001): 基本
  - `2` (dword:00000002): 拡張
  - `3` (dword:00000003): 完全

### DoNotShowFeedbackNotifications
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection`
- **キー名**: `DoNotShowFeedbackNotifications`
- **設定値**: `dword:00000001`
- **意味**: フィードバック通知の表示制御
- **選択肢**:
  - `0` (dword:00000000): 表示する
  - `1` (dword:00000001): 表示しない

### AllowTelemetry (DataCollection)
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection`
- **キー名**: `AllowTelemetry`
- **設定値**: `dword:00000000`
- **意味**: Windows テレメトリレベルの制御（通常設定）
- **選択肢**: 上記と同様

### NumberOfSIUFInPeriod
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Siuf\Rules`
- **キー名**: `NumberOfSIUFInPeriod`
- **設定値**: `dword:00000000`
- **意味**: SIUF（Software Improvement Program）期間内実行回数
- **選択肢**: 数値（0で無効化）

### PeriodInNanoSeconds
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Siuf\Rules`
- **キー名**: `PeriodInNanoSeconds`
- **設定値**: `-` (削除)
- **意味**: SIUF期間設定（ナノ秒）
- **選択肢**: 削除または数値

### DisabledByGroupPolicy
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo`
- **キー名**: `DisabledByGroupPolicy`
- **設定値**: `dword:00000001`
- **意味**: 広告ID機能のグループポリシー制御
- **選択肢**:
  - `0` (dword:00000000): 有効
  - `1` (dword:00000001): 無効

### TailoredExperiencesWithDiagnosticDataEnabled
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy`
- **キー名**: `TailoredExperiencesWithDiagnosticDataEnabled`
- **設定値**: `dword:00000000`
- **意味**: 診断データに基づくカスタマイズ制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### Enabled (AdvertisingInfo)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo`
- **キー名**: `Enabled`
- **設定値**: `dword:00000000`
- **意味**: 個人広告ID設定
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### EnableWebContentEvaluation
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\AppHost`
- **キー名**: `EnableWebContentEvaluation`
- **設定値**: `dword:00000000`
- **意味**: アプリのWebコンテンツ評価制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### Value (Location Access)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}`
- **キー名**: `Value`
- **設定値**: `"Deny"`
- **意味**: 位置情報アクセス制御
- **選択肢**:
  - `"Allow"`: 許可
  - `"Deny"`: 拒否

### Value (Camera Access)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{E5323777-F976-4f5b-9B55-B94699C46E44}`
- **キー名**: `Value`
- **設定値**: `"Deny"`
- **意味**: カメラアクセス制御
- **選択肢**:
  - `"Allow"`: 許可
  - `"Deny"`: 拒否

### Value (Microphone Access)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{2EEF81BE-33FA-4800-9670-1CD474972C3F}`
- **キー名**: `Value`
- **設定値**: `"Deny"`
- **意味**: マイクアクセス制御
- **選択肢**:
  - `"Allow"`: 許可
  - `"Deny"`: 拒否

### EnableActivityFeed
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System`
- **キー名**: `EnableActivityFeed`
- **設定値**: `dword:00000000`
- **意味**: アクティビティフィード機能制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### PublishUserActivities
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System`
- **キー名**: `PublishUserActivities`
- **設定値**: `dword:00000000`
- **意味**: ユーザーアクティビティの公開制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### UploadUserActivities
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System`
- **キー名**: `UploadUserActivities`
- **設定値**: `dword:00000000`
- **意味**: ユーザーアクティビティのアップロード制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

## 効果
- プライバシー保護の強化
- 不要なデータ送信の防止
- システムリソースの節約
- 企業セキュリティポリシーへの準拠
- ユーザー追跡の防止

## 注意事項
- 一部設定は管理者権限が必要です
- デバイスアクセス制御により、必要なアプリケーションの機能が制限される場合があります
- 企業環境では法的要件に応じて設定を調整してください
- Windows Updateや一部のMicrosoft サービスが影響を受ける可能性があります

## 推奨事項
- 本番環境適用前にテスト環境での動作確認を推奨
- 必要に応じて個別のアプリケーションでデバイスアクセス許可を設定
