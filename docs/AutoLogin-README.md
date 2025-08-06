# 自動ログイン設定について

## 概要
`AutoLogin.ps1`スクリプトは、Windows の自動ログイン機能を管理します。
`workflow.json`のパラメータでユーザーID/パスワードを事前設定することができ、設定がない場合は実行時に入力を求めます。

## 設定方法

### workflow.jsonでの設定

`config/workflow.json`の`autologin-setup`ステップでパラメータを設定できます：

```json
{
  "id": "autologin-setup",
  "name": "自動ログイン設定",
  "description": "セットアップ期間中の自動ログイン設定（workflow.jsonのパラメータまたは対話入力で設定）",
  "script": "AutoLogin.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "Action": "Setup",
    "Force": true,
    "Username": "Administrator",
    "Password": "YourPassword",
    "Domain": "WORKGROUP"
  }
}
```

### 設定項目

#### parameters セクション
- `Username`: 自動ログインに使用するユーザー名（空の場合は現在のユーザーまたは実行時入力）
- `Password`: 自動ログインに使用するパスワード（空の場合は実行時入力）
- `Domain`: ドメイン名（空の場合は現在のコンピューター名）

#### デフォルト設定
- `autoLogonCount`: 自動ログインの回数（デフォルト: 999）
- `forcePasswordPrompt`: パスワードが設定されていても強制的に入力を求める（デフォルト: false）

## 使用方法

### 1. workflow.jsonでの事前設定
1. `config/workflow.json`の`autologin-setup`ステップにユーザー名とパスワードを設定
2. ワークフロー実行時に、設定値を使用して自動ログインを設定

### 2. 実行時入力
1. `workflow.json`のユーザー名またはパスワードを空にする
2. スクリプト実行時に必要な情報の入力を求められる

### 3. コマンドライン引数での指定
```powershell
.\AutoLogin.ps1 -Action Setup -Username "user" -Password "pass" -Domain "domain"
```

## セキュリティ注意事項
- workflow.jsonにパスワードを保存する場合は、ファイルのアクセス権限を適切に設定してください
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

## 変更履歴

### v2.0 (最新)
- `config/autologin.json`を廃止
- `workflow.json`のパラメータで設定を管理
- よりシンプルで管理しやすい構造に変更

### v1.0 (旧版)
- `config/autologin.json`を使用した設定管理
