# BitLocker設定ガイド

## 概要

Windows Kitting WorkflowのBitLocker機能は、システムドライブの自動暗号化を提供します。
TPM（Trusted Platform Module）を使用した安全な暗号化により、データ保護を強化します。

## 主な機能

### 🔐 自動暗号化設定
- システムドライブ（通常はCドライブ）の自動暗号化
- TPMベースの保護（TPM 2.0推奨）
- 回復キーの自動生成と安全な保存

### 🔑 認証オプション
- **TPMのみ**: 起動時の自動ロック解除（推奨）
- **TPM + PIN**: より高いセキュリティ（手動PIN入力が必要）

### 📱 通知機能
- 暗号化設定完了の通知
- PIN設定時のユーザー対応要求の通知

## 設定方法

### workflow.json設定

BitLocker設定は `config/workflow.json` の `setup-bitlocker` ステップで管理されています：

```json
{
  "id": "setup-bitlocker",
  "name": "BitLocker暗号化設定",
  "description": "システムドライブのBitLocker暗号化を設定",
  "script": "scripts/setup/setup-bitlocker.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "EnablePIN": false,
    "Force": false
  },
  "completionCheck": {
    "type": "file",
    "path": "status/setup-bitlocker.completed"
  },
  "timeout": 600,
  "retryCount": 1,
  "rebootRequired": false,
  "dependsOn": [
    "deploy-desktop-files"
  ],
  "onError": "continue"
}
```

### パラメータ説明

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| `EnablePIN` | PINコード認証を有効にする | `false` |
| `Force` | 既に暗号化済みでも再設定する | `false` |

## 使用例

### 基本的な暗号化（TPMのみ）

```json
"parameters": {
  "EnablePIN": false,
  "Force": false
}
```

この設定では：
- 起動時に自動でロック解除
- ユーザーの手動操作は不要
- 企業環境での一括展開に適している

### 高セキュリティ暗号化（TPM + PIN）

```json
"parameters": {
  "EnablePIN": true,
  "Force": false
}
```

この設定では：
- ⚠️ **重要**: 次回再起動時にPINコードの設定が必要
- 起動時にPIN入力が必要
- より高いセキュリティレベル

## 前提条件

### システム要件
- Windows 11 Pro/Enterprise または Windows 10 Pro/Enterprise
- TPM 2.0（推奨）または TPM 1.2
- BIOSでTPMが有効になっている
- 管理者権限

### TPM確認方法

```powershell
# TPMステータス確認
Get-Tpm

# BitLockerサポート確認
Get-BitLockerVolume
```

## 実行タイミング

BitLocker設定は以下の順序で実行されます：

1. **基本セットアップ完了後**: アプリインストール、レジストリ設定等
2. **デスクトップファイル配置後**: ユーザー環境設定完了後
3. **クリーンアップ前**: 最終段階での暗号化実行

この順序により、システム設定が安定した状態で暗号化を行います。

## セキュリティ機能

### 回復キーの管理

- 回復キーは `backup/bitlocker-recovery-keys/` に自動保存
- ファイル名: `bitlocker-recovery-key-YYYYMMDD_HHMMSS.txt`
- コンピューター名、日時、回復パスワードを記録

#### 回復キーファイル例
```
BitLocker Recovery Key Information
==================================
Computer Name: DESKTOP-ABC123
Drive: C:
Date: 2025/06/17 09:30:45
Recovery Key ID: {12345678-1234-5678-9ABC-123456789ABC}
Recovery Password: 123456-654321-789012-345678-901234-567890

Important: Store this recovery key in a safe location!
==================================
```

### 暗号化方式
- **暗号化アルゴリズム**: XTS-AES 256ビット
- **キー長**: 256ビット
- **保護方法**: TPM 2.0ハードウェア保護

## トラブルシューティング

### よくある問題

#### 1. TPMが検出されない
```
ERROR: TPMが検出されませんでした
```

**解決方法**:
- BIOSでTPMを有効にする
- Windows Hello for Businessが有効な場合は設定を確認
- `Get-Tpm` コマンドで詳細を確認

#### 2. TPMが有効でない
```
ERROR: TPMが有効になっていません。BIOSでTPMを有効にしてください
```

**解決方法**:
1. PC再起動してBIOS/UEFI設定画面に入る
2. セキュリティ設定でTPMを有効にする
3. セキュアブートも有効にする（推奨）

#### 3. 既にBitLockerが有効
```
INFO: BitLockerは既に有効になっています
```

**対処法**:
- 正常な状態です
- 強制再設定する場合は `-Force` パラメータを使用

#### 4. 暗号化に時間がかかる
- バックグラウンドで暗号化が進行中
- `Get-BitLockerVolume` で進捗確認可能
- 通常、数時間から数日かかる場合があります

### デバッグ方法

#### 手動実行
```powershell
# ドライラン（テスト実行）
.\scripts\setup\setup-bitlocker.ps1 -DryRun

# 通常実行
.\scripts\setup\setup-bitlocker.ps1

# PIN有効で実行
.\scripts\setup\setup-bitlocker.ps1 -EnablePIN

# 強制実行
.\scripts\setup\setup-bitlocker.ps1 -Force
```

#### ログ確認
```powershell
# BitLockerログ確認
Get-Content logs\scripts\setup-bitlocker.log -Tail 20

# システムイベントログ確認
Get-WinEvent -LogName System | Where-Object {$_.ProviderName -like "*BitLocker*"}
```

## PIN設定時の注意事項

### ⚠️ 重要な警告

`EnablePIN: true` を設定した場合：

1. **次回再起動時にPIN設定が必要**
   - システムが起動時にPIN設定画面を表示
   - 4-20桁の数字PINを設定する必要
   - この操作は手動で行う必要があります

2. **通知について**
   - Slack/Teamsに自動通知が送信
   - 「ユーザー対応が必要」のメッセージが表示
   - 管理者は該当PCのPIN設定を確認する必要

3. **企業展開での考慮事項**
   - 大量展開時はTPMのみの使用を推奨
   - PIN設定が必要な場合は個別対応が必要
   - エンドユーザーへの事前説明が重要

## 運用上の推奨事項

### 企業環境での推奨設定

```json
"parameters": {
  "EnablePIN": false,
  "Force": false
}
```

**理由**:
- 自動化されたセットアップが可能
- ユーザー介入が不要
- 大量展開に適している
- TPMによる十分なセキュリティ

### 高セキュリティ環境での推奨設定

```json
"parameters": {
  "EnablePIN": true,
  "Force": false
}
```

**理由**:
- より高いセキュリティレベル
- 物理的なアクセス制御が強化
- 規制要件への対応

### 回復キーの管理

1. **自動バックアップ**
   - 回復キーファイルを安全な場所にコピー
   - Active Directoryへの自動エスクロー（組織設定による）

2. **アクセス制御**
   - 回復キーファイルへのアクセス制限
   - 管理者のみが閲覧可能にする

3. **定期的な確認**
   - 回復キーの有効性を定期確認
   - 紛失時の再生成手順を整備

## 関連ドキュメント

- [メインREADME](../README.md)
- [カスタマイズガイド](Customization-Guide.md)
- [トラブルシューティングガイド](Troubleshooting.md)
- [セキュリティベストプラクティス](Security-Best-Practices.md)

## 技術仕様

### サポートされる暗号化方式
- XTS-AES 256
- XTS-AES 128
- AES-CBC 256（レガシー）
- AES-CBC 128（レガシー）

### 対応プロテクター
- TPMプロテクター（推奨）
- TPM+PINプロテクター
- 回復パスワードプロテクター（自動追加）

### ファイル出力
- 回復キーファイル: `backup/bitlocker-recovery-keys/`
- ログファイル: `logs/scripts/setup-bitlocker.log`
- 完了フラグ: `status/setup-bitlocker.completed`
