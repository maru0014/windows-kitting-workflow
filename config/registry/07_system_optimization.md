# システム最適化設定

このレジストリファイルは、Windows 11のシステムパフォーマンス最適化に関する設定を行います。

## 設定内容

### HibernateEnabled
- **フルパス**: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power`
- **キー名**: `HibernateEnabled`
- **設定値**: `dword:00000000`
- **意味**: ハイバネーション（高速スタートアップ）の制御
- **選択肢**:
  - `0` (dword:00000000): 無効（ハイバネーションを無効化）
  - `1` (dword:00000001): 有効（ハイバネーションを有効化）

### DisablePagingExecutive
- **フルパス**: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`
- **キー名**: `DisablePagingExecutive`
- **設定値**: `dword:00000001`
- **意味**: システムカーネルのページング制御
- **選択肢**:
  - `0` (dword:00000000): 有効（カーネルのページングを許可）
  - `1` (dword:00000001): 無効（カーネルのページングを無効化）

### LargeSystemCache
- **フルパス**: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management`
- **キー名**: `LargeSystemCache`
- **設定値**: `dword:00000001`
- **意味**: システムキャッシュサイズの制御
- **選択肢**:
  - `0` (dword:00000000): 標準サイズ
  - `1` (dword:00000001): 大きなサイズ（サーバー用途向け）

### MenuShowDelay
- **フルパス**: `HKEY_CURRENT_USER\Control Panel\Desktop`
- **キー名**: `MenuShowDelay`
- **設定値**: `"100"`
- **意味**: メニュー表示遅延時間（ミリ秒）
- **選択肢**: 数値文字列（既定値: "400"）

### ListviewAlphaSelect
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ListviewAlphaSelect`
- **設定値**: `dword:00000000`
- **意味**: リストビューでのアルファ選択機能制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### ListviewShadow
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ListviewShadow`
- **設定値**: `dword:00000000`
- **意味**: リストビューでの影効果制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### EnableBalloonTips
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `EnableBalloonTips`
- **設定値**: `dword:00000000`
- **意味**: バルーンチップ（ポップアップヒント）の制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### SystemResponsiveness
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`
- **キー名**: `SystemResponsiveness`
- **設定値**: `dword:00000014`
- **意味**: システム応答性の設定（0-100の値）
- **選択肢**: 0-100の数値（既定値: 20、低い値ほどマルチメディア処理を優先）

### GPU Priority
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`
- **キー名**: `GPU Priority`
- **設定値**: `dword:00000008`
- **意味**: GPU優先度設定
- **選択肢**: 1-8の数値（8が最高優先度）

### Priority
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`
- **キー名**: `Priority`
- **設定値**: `dword:00000006`
- **意味**: プロセス優先度設定
- **選択肢**: 1-6の数値（6が最高優先度）

### Scheduling Category
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`
- **キー名**: `Scheduling Category`
- **設定値**: `"High"`
- **意味**: スケジューリングカテゴリ設定
- **選択肢**:
  - `"Low"`: 低優先度
  - `"Medium"`: 中優先度
  - `"High"`: 高優先度

### SFIO Priority
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games`
- **キー名**: `SFIO Priority`
- **設定値**: `"High"`
- **意味**: ストレージI/O優先度設定
- **選択肢**:
  - `"Low"`: 低優先度
  - `"Normal"`: 標準優先度
  - `"High"`: 高優先度

### EnableAeroPeek (DWM)
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM`
- **キー名**: `EnableAeroPeek`
- **設定値**: `dword:00000000`
- **意味**: Aero Peek機能の制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

### AlwaysHibernateThumbnails
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM`
- **キー名**: `AlwaysHibernateThumbnails`
- **設定値**: `dword:00000000`
- **意味**: サムネイルのハイバネーション制御
- **選択肢**:
  - `0` (dword:00000000): 無効
  - `1` (dword:00000001): 有効

## 効果
- システム起動時間の短縮
- メモリ使用効率の向上
- UI応答性の向上
- マルチメディア処理性能の向上
- 視覚効果によるオーバーヘッドの削減

## 注意事項
- 一部設定は管理者権限が必要
- メモリ容量が少ないシステムでは効果が限定的な場合があります
- ゲーム・マルチメディア設定は用途に応じて調整してください
