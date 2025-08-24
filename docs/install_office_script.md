## Office インストールスクリプト利用ガイド

このドキュメントは、Windows Kitting Workflow に含まれる `scripts/setup/install-office.ps1` の利用方法と挙動を説明します。

### 概要
- **設定ファイル**: `config/machine_list.csv`
- **ODT(Office Deployment Tool)**: `config/office/setup.exe`
- **テンプレートXML**:
  - 365: `config/office/configuration-Office365-x64.xml`
  - Bundle2021: `config/office/configuration-Office2021.xml`
- **完了マーカー**: `Status/install-office.completed`
- **ログ**: `logs/install-office.log`（共通ログディレクトリ配下）

### 前提条件
- `config/office/setup.exe`（ODTの `setup.exe`）が配置されていること
- 365 および Bundle2021 用のテンプレートXMLが配置されていること
- `config/machine_list.csv` に対象端末のシリアル番号と Office 情報が登録されていること

### machine_list.csv の形式
CSV は UTF-8、ヘッダー行必須。

```csv
"Serial Number","Machine Name","Office License Type","Office Product Key"
"<BIOSまたは筐体のSerialNumber>","<端末名>","365|Bundle2021","<プロダクトキー or 空>"
```

- **Office License Type**: `365` または `Bundle2021`
- **Office Product Key**: `Bundle2021` の場合に必須。`365` の場合は未入力でも可

### 動作仕様
- スクリプトは自動で現在端末のシリアル番号を取得し、`machine_list.csv` の一致レコードを検索します
- ライセンスタイプに応じて以下の通り実行します
  - **365**: `configuration-Office365-x64.xml` をそのまま使用して ODT を実行
  - **Bundle2021**: `configuration-Office2021.xml` を一時ファイルにコピーし、XML 内の `{{PRODUCT_KEY}}` を `machine_list.csv` の値で置換してから ODT を実行

### 実行方法
PowerShell からワークフロールートで実行します。

```powershell
pwsh -File scripts/setup/install-office.ps1 -ConfigPath "config/machine_list.csv"
```

> 既定値で `-ConfigPath` は `config/machine_list.csv` です。別パスを使う場合のみ指定してください。

### 完了マーカー
- インストールが正常終了すると、`Status` ディレクトリ配下に `install-office.completed` が作成されます
- 記載内容: 実行時刻／対象PC名／シリアル番号／ライセンスタイプ／使用インストーラパス／Office Product Key（マスク済み）

例:

```text
Officeインストール完了
実行時刻: 2025-01-01 12:34:56
対象PC名: PS-TEST-001
シリアル番号: 0762-...-69
ライセンスタイプ: Bundle2021
使用インストーラ: D:\PowerShell\windows-kitting-workflow\config\office\setup.exe
Office Product Key (masked): *****-*****-*****-*****-ABCDE
```

### エラーと対処
- `ODTの setup.exe が見つかりません`:
  - `config/office/setup.exe` を配置してください
- `構成テンプレートXMLが見つかりません`:
  - 365: `config/office/configuration-Office365-x64.xml`
  - Bundle2021: `config/office/configuration-Office2021.xml`
- `Bundleライセンスでは 'Office Product Key' が必須です`:
  - `machine_list.csv` の該当レコードにプロダクトキーを設定してください
- `シリアル番号に対応する機器情報が見つかりません`:
  - 端末のシリアル番号が CSV に登録されているか確認してください

### 補足
- 365 ライセンスではプロダクトキーは不要のため、完了マーカーのキー欄は空になります
- ログは共通ログ関数により `install-office.log` に出力されます
