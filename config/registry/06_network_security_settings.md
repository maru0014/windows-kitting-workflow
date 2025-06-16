# ネットワーク・セキュリティ設定

このレジストリファイルは、ネットワーク接続とセキュリティに関する設定を行います。

## 設定内容

### EnableLUA
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- **キー名**: `EnableLUA`
- **設定値**: `dword:00000000`
- **意味**: UAC（User Account Control）の有効/無効制御
- **選択肢**:
  - `0` (dword:00000000): 無効（UACを完全に無効化）
  - `1` (dword:00000001): 有効（UACを有効化）

### ConsentPromptBehaviorAdmin
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- **キー名**: `ConsentPromptBehaviorAdmin`
- **設定値**: `dword:00000000`
- **意味**: 管理者のUAC同意プロンプト動作
- **選択肢**:
  - `0` (dword:00000000): プロンプトなしで昇格
  - `1` (dword:00000001): セキュアデスクトップで資格情報をプロンプト
  - `2` (dword:00000002): セキュアデスクトップで同意をプロンプト
  - `5` (dword:00000005): 同意をプロンプト

### ConsentPromptBehaviorUser
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- **キー名**: `ConsentPromptBehaviorUser`
- **設定値**: `dword:00000000`
- **意味**: 標準ユーザーのUAC同意プロンプト動作
- **選択肢**:
  - `0` (dword:00000000): 昇格要求を自動的に拒否
  - `1` (dword:00000001): セキュアデスクトップで資格情報をプロンプト
  - `3` (dword:00000003): 資格情報をプロンプト

### PromptOnSecureDesktop
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`
- **キー名**: `PromptOnSecureDesktop`
- **設定値**: `dword:00000000`
- **意味**: セキュアデスクトップでのプロンプト表示制御
- **選択肢**:
  - `0` (dword:00000000): 無効（通常デスクトップで表示）
  - `1` (dword:00000001): 有効（セキュアデスクトップで表示）

### Zone 3 設定（1200）
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3`
- **キー名**: `1200`
- **設定値**: `dword:00000000`
- **意味**: インターネットゾーンでのActiveXコントロール実行制御
- **選択肢**:
  - `0` (dword:00000000): 有効
  - `1` (dword:00000001): プロンプト
  - `3` (dword:00000003): 無効

### Zone 3 設定（1001）
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3`
- **キー名**: `1001`
- **設定値**: `dword:00000000`
- **意味**: ActiveXコントロールとプラグインのダウンロード制御
- **選択肢**:
  - `0` (dword:00000000): 有効
  - `1` (dword:00000001): プロンプト
  - `3` (dword:00000003): 無効

### AutoDetect
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings`
- **キー名**: `AutoDetect`
- **設定値**: `dword:00000000`
- **意味**: プロキシの自動検出制御
- **選択肢**:
  - `0` (dword:00000000): 無効（自動検出を無効化）
  - `1` (dword:00000001): 有効（自動検出を有効化）

### KeepRasConnections
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer`
- **キー名**: `KeepRasConnections`
- **設定値**: `dword:00000001`
- **意味**: RAS接続の維持制御
- **選択肢**:
  - `0` (dword:00000000): 無効（接続を維持しない）
  - `1` (dword:00000001): 有効（接続を維持する）

### SMB1
- **フルパス**: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters`
- **キー名**: `SMB1`
- **設定値**: `dword:00000000`
- **意味**: SMBv1プロトコルの有効/無効制御
- **選択肢**:
  - `0` (dword:00000000): 無効（SMBv1を無効化）
  - `1` (dword:00000001): 有効（SMBv1を有効化）

### Hidden
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `Hidden`
- **設定値**: `dword:00000001`
- **意味**: 隠しファイル・フォルダの表示制御
- **選択肢**:
  - `1` (dword:00000001): 表示する
  - `2` (dword:00000002): 表示しない

### ShowSuperHidden
- **フルパス**: `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`
- **キー名**: `ShowSuperHidden`
- **設定値**: `dword:00000001`
- **意味**: システムファイルの表示制御
- **選択肢**:
  - `0` (dword:00000000): 表示しない
  - `1` (dword:00000001): 表示する

## 効果
- キッティング作業時の権限プロンプト削減
- ネットワーク接続の安定性向上
- セキュリティリスクの軽減
- システム管理の効率化

## 注意事項
- UAC設定の変更は管理者権限が必要
- 本番環境ではUACの完全無効化は推奨されません
- SMBv1の無効化により古いシステムとの互換性に影響する可能性があります
