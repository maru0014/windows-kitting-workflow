# Wi-Fi設定自動適用ガイド

## 概要

このドキュメントでは、Windows Kitting WorkflowにおけるWi-Fi設定の自動適用機能について説明します。

## 機能説明

### 自動適用される設定

- **対象プロファイル**: `config\Wi-Fi-test-wi-fi.xml`で定義されたWi-Fiプロファイル
- **実行タイミング**: ワークフローの初期化（init）ステップの直後
- **実行スクリプト**: `scripts\setup\setup-wifi.bat`

### 処理フロー

1. **ファイル存在確認**: Wi-Fi設定XMLファイルの存在を確認
2. **Wi-Fiアダプター確認**: システムにWi-Fiアダプターが存在し、有効化されているかを確認
3. **プロファイル適用**: `netsh wlan add profile`コマンドでプロファイルを追加
4. **結果確認**: 現在のWi-Fiプロファイル一覧を表示
5. **完了記録**: `status\setup-wifi.completed`ファイルを作成

### Forceオプション

`-Force`オプションを指定すると、以下の動作が可能になります：

- **Wi-Fiアダプターが存在しない場合**: アダプターがなくてもプロファイルの作成を試行
- **アダプターが無効な場合**: アダプターの有効化をスキップしてプロファイル作成を続行
- **プロファイル作成に失敗した場合**: エラーでも処理を継続し、完了ステータスを記録

**使用例**:
```powershell
# ForceオプションでWi-Fi設定を適用
.\setup-wifi.ps1 -Force

# Forceオプションで自動接続も実行
.\setup-wifi.ps1 -Force -Connect
```

## Wi-Fi設定XMLファイルの作成方法

### 手順1: 既存Wi-Fi接続の設定確認

```cmd
# 現在接続中のWi-Fiプロファイルを確認
netsh wlan show interfaces

# 特定のプロファイル詳細を確認
netsh wlan show profile name="プロファイル名" key=clear
```

### 手順2: プロファイルのエクスポート

```cmd
# Wi-Fiプロファイルをエクスポート
netsh wlan export profile name="プロファイル名" folder=C:\temp key=clear
```

### 手順3: XMLファイルの配置

1. エクスポートしたXMLファイルを確認
2. ファイル名を `Wi-Fi-test-wi-fi.xml` に変更
3. `config\` フォルダに配置

## セキュリティ考慮事項

### パスワードの暗号化

Wi-FiパスワードはWindowsの保護されたデータ（DPAPI）で暗号化されています：

```xml
<sharedKey>
    <keyType>passPhrase</keyType>
    <protected>true</protected>
    <keyMaterial>暗号化されたパスワード</keyMaterial>
</sharedKey>
```

### 注意点

- **暗号化されたパスワード**: エクスポート元とは異なるユーザー/マシンでは復号化できない場合があります
- **平文パスワード**: セキュリティを重視する場合は、`key=clear`オプションを使用せずにエクスポートしてください

## 設定ファイル例

### 基本的なWPA2-PSK設定

```xml
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>test-wi-fi</name>
    <SSIDConfig>
        <SSID>
            <hex>746573742D77692D6669</hex>
            <name>test-wi-fi</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>manual</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>true</protected>
                <keyMaterial>暗号化されたパスワード</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
```

## エラーハンドリング

### よくあるエラーと対処法

| エラー | 原因 | 対処法 |
|--------|------|--------|
| ファイルが見つからない | XMLファイルが存在しない | `config\Wi-Fi-test-wi-fi.xml`が存在することを確認 |
| プロファイル追加失敗 | Wi-Fiアダプターが無効 | Wi-Fiアダプターを有効化、または`-Force`オプションを使用 |
| Wi-Fiアダプターが見つからない | システムにWi-Fiアダプターが存在しない | `-Force`オプションを使用してプロファイル作成をスキップ |
| 権限エラー | 管理者権限なし | 管理者権限でスクリプトを実行 |
| 暗号化エラー | 異なるユーザー/マシン | 新しい環境でプロファイルを再エクスポート |

### ログ確認

```cmd
# Wi-Fiアダプターの状態確認
netsh wlan show interfaces

# 現在のプロファイル一覧
netsh wlan show profiles

# 特定プロファイルの詳細
netsh wlan show profile name="test-wi-fi"
```

## 高度な設定

### 複数Wi-Fiプロファイルの対応

現在は単一プロファイルのみ対応していますが、以下の方法で複数プロファイルに対応可能：

1. **設定ファイルの拡張**: JSONで複数プロファイルを管理
2. **スクリプトの改良**: ループ処理で複数XMLファイルを適用
3. **条件分岐**: 環境に応じたプロファイル選択

### 企業ネットワーク対応

企業のWi-Fi（802.1X認証）の場合：

```xml
<security>
    <authEncryption>
        <authentication>WPA2</authentication>
        <encryption>AES</encryption>
        <useOneX>true</useOneX>
    </authEncryption>
    <OneX xmlns="http://www.microsoft.com/networking/OneX/v1">
        <!-- 802.1X設定 -->
    </OneX>
</security>
```

## トラブルシューティング

### 1. Wi-Fi接続が自動で行われない

**原因**: プロファイルは追加されるが、自動接続は別途設定が必要

**解決策**:
```cmd
# 自動接続を有効化
netsh wlan set profileparameter name="test-wi-fi" connectionmode=auto
```

### 2. パスワードが正しく設定されない

**原因**: 暗号化されたパスワードが復号化できない

**解決策**:
1. 対象マシンで直接プロファイルをエクスポート
2. または平文パスワードでプロファイルを作成

### 3. プロファイルが重複する

**原因**: 同名のプロファイルが既に存在

**解決策**:
```cmd
# 既存プロファイルを削除してから追加
netsh wlan delete profile name="test-wi-fi"
netsh wlan add profile filename="config\Wi-Fi-test-wi-fi.xml"
```

### 4. Wi-Fiアダプターが存在しない環境での実行

**原因**: デスクトップPCやWi-Fiアダプターが無効な環境でスクリプトが実行される

**解決策**:
```powershell
# Forceオプションを使用してアダプターの確認をスキップ
.\setup-wifi.ps1 -Force

# ワークフロー設定でForceオプションを有効化
# workflow.jsonのsetup-wifiステップに以下を追加:
# "parameters": { "Force": true }
```

**注意**: Forceオプションを使用すると、Wi-Fiアダプターが存在しない環境でもプロファイルの作成を試行し、ワークフローを継続できます。

## workflow.json設定詳細

### ステップ設定

#### 通常の設定（Wi-Fiアダプターが必要）

```json
{
  "id": "setup-wifi",
  "name": "Wi-Fi設定プロファイル適用",
  "description": "Wi-Fi設定プロファイルをシステムに適用",
  "script": "scripts/setup/setup-wifi.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "completionCheck": {
    "type": "file",
    "path": "status/setup-wifi.completed"
  },
  "timeout": 120,
  "retryCount": 2,
  "rebootRequired": false,
  "dependsOn": ["init"],
  "onError": "continue"
}
```

#### Forceオプション付き設定（Wi-Fiアダプターが不要）

```json
{
  "id": "setup-wifi",
  "name": "Wi-Fi設定プロファイル適用",
  "description": "Wi-Fi設定プロファイルをシステムに適用（Forceモード）",
  "script": "scripts/setup/setup-wifi.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "Force": true
  },
  "completionCheck": {
    "type": "file",
    "path": "status/setup-wifi.completed"
  },
  "timeout": 120,
  "retryCount": 2,
  "rebootRequired": false,
  "dependsOn": ["init"],
  "onError": "continue"
}
```

### 設定パラメータ説明

- **onError: "continue"**: Wi-Fiが利用できない環境でもワークフローを継続
- **retryCount: 2**: ネットワーク関連のエラーに対応するため2回リトライ
- **timeout: 120**: プロファイル適用に十分な時間を確保
- **parameters.Force**: Forceオプションを有効化（Wi-Fiアダプターが不要な環境で使用）

## 参考資料

### Windowsコマンド

- [netsh wlan コマンドリファレンス](https://docs.microsoft.com/ja-jp/windows-server/networking/technologies/netsh/netsh-wlan)
- [Wi-Fiプロファイル設定](https://docs.microsoft.com/ja-jp/windows/win32/nativewifi/wlan-profile-schema)

### セキュリティガイドライン

- **推奨**: 本番環境では暗号化されたパスワードを使用
- **注意**: XMLファイルのアクセス権限を適切に設定
- **管理**: 定期的なパスワード変更とプロファイル更新

---

**作成日**: 2025年6月16日  
**バージョン**: 1.0  
**対象**: Windows Kitting Workflow v1.0
