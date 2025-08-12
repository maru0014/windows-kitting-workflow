# 自動ログイン設定について

## 概要
`AutoLogin.ps1`スクリプトは、Windows の自動ログイン機能を管理します。
`workflow.json`のパラメータでユーザーID/パスワードを事前設定できます。パスワードの扱いは次の通りです。

- 未指定（パラメーターを省略）: 実行時にプロンプトで入力（2回確認）
- 空文字（`""` を明示指定）: パスワードなしで設定（警告ログを出力）
- 非空文字列を指定: 指定したパスワードを使用

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
- `Username`: 自動ログインに使用するユーザー名（省略時は現在のユーザーを既定として利用）
- `Password`: 自動ログインに使用するパスワード
  - 省略: 実行時プロンプトで入力（2回確認）
  - 空文字（`""`）: パスワードなしで設定（警告ログを出力）
  - 非空文字列: 指定値を使用
- `Domain`: ドメイン名（省略時は現在のコンピューター名）

#### デフォルト設定
- `autoLogonCount`: 自動ログインの回数（デフォルト: 999）
- `forcePasswordPrompt`: パスワードが設定されていても強制的に入力を求める（デフォルト: false）

## 使用方法

### 1. workflow.jsonでの事前設定
1. `config/workflow.json`の`autologin-setup`ステップにユーザー名とパスワードを設定
2. ワークフロー実行時に、設定値を使用して自動ログインを設定

### 2. 実行時入力（パスワード未指定）
1. `workflow.json`で`Password`を省略する（またはコマンドラインで指定しない）
2. スクリプト実行時にパスワード入力（2回確認）が求められる

### 3. コマンドライン引数での指定
```powershell
# パスワード未指定（プロンプトで入力）
.\AutoLogin.ps1 -Action Setup -Username "user" -Domain "domain"

# パスワードを明示指定
.\AutoLogin.ps1 -Action Setup -Username "user" -Password "P@ssw0rd" -Domain "domain"

# パスワードなしで設定（警告ログが出ます）
.\AutoLogin.ps1 -Action Setup -Username "user" -Password "" -Domain "domain"
```

### 4. workflow.json での空文字/未指定の扱い

```json
{
  "id": "autologin-setup",
  "name": "自動ログイン設定",
  "script": "AutoLogin.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "Action": "Setup",
    "Force": true,
    "Username": "Administrator",
    "Domain": "WORKGROUP"
    // Password を省略すると、実行時にプロンプトで入力されます
  }
}
```

パスワードなしで設定する場合は、空文字を明示してください。

```json
{
  "parameters": {
    "Action": "Setup",
    "Username": "Administrator",
    "Password": "",
    "Domain": "WORKGROUP"
  }
}
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

### v2.1 (最新)
- `-Password` の扱いを明確化（未指定: プロンプト、空文字: パスワードなし＋警告）
- コマンド例と workflow.json 設定例を更新

### v2.0
- `config/autologin.json`を廃止
- `workflow.json`のパラメータで設定を管理
- よりシンプルで管理しやすい構造に変更

### v1.0 (旧版)
- `config/autologin.json`を使用した設定管理
