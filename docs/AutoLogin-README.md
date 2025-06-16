# 自動ログイン設定について

## 概要
`AutoLogin.ps1`スクリプトは、Windows の自動ログイン機能を管理します。
JSONファイルを使用してユーザーID/パスワードを事前設定することができ、設定がない場合は実行時に入力を求めます。

## 設定ファイル
### config/autologin.json

```json
{
  "autologin": {
    "enabled": true,
    "credentials": {
      "username": "ユーザー名",
      "password": "パスワード",
      "domain": "ドメイン名"
    },
    "settings": {
      "autoLogonCount": 999,
      "forcePasswordPrompt": false,
      "description": "自動ログイン設定"
    }
  }
}
```

### 設定項目

#### credentials セクション
- `username`: 自動ログインに使用するユーザー名（空の場合は現在のユーザーまたは実行時入力）
- `password`: 自動ログインに使用するパスワード（空の場合は実行時入力）
- `domain`: ドメイン名（空の場合は現在のコンピューター名）

#### settings セクション
- `autoLogonCount`: 自動ログインの回数（デフォルト: 999）
- `forcePasswordPrompt`: パスワードが設定されていても強制的に入力を求める（デフォルト: false）

## 使用方法

### 1. 事前設定による自動実行
1. `config/autologin.json` にユーザー名とパスワードを設定
2. スクリプトを実行すると、設定値を使用して自動ログインを設定

### 2. 実行時入力
1. `config/autologin.json` のユーザー名またはパスワードを空にする
2. スクリプト実行時に必要な情報の入力を求められる

### 3. コマンドライン引数での指定
```powershell
.\AutoLogin.ps1 -Action Setup -Username "user" -Password "pass" -Domain "domain"
```

## セキュリティ注意事項
- JSONファイルにパスワードを保存する場合は、ファイルのアクセス権限を適切に設定してください
- 本機能は初期セットアップ期間中の一時的な使用を想定しています
- セットアップ完了後は自動ログイン設定を削除することを推奨します

## 実行例

### セットアップ
```powershell
.\AutoLogin.ps1 -Action Setup -Force
```

### 削除
```powershell
.\AutoLogin.ps1 -Action Remove -Force
```

### 現在の設定確認
```powershell
.\AutoLogin.ps1 -Action Setup
```
