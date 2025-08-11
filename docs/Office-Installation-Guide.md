## Office インストールガイド（ODT 連携）

このガイドでは、Windows Kitting Workflow に追加された `scripts/setup/install-office.ps1` による Office 展開ツール（ODT: Office Deployment Tool）連携の使い方を説明します。ODT の `setup.exe /configure <構成XML>` を用い、`config/machine_list.csv` から取得したシリアル番号やライセンス種別に応じて、構成テンプレート XML 内のトークンを置換して実行します。

参考: Microsoft 公式の ODT 概要は「Office 展開ツールの概要」を参照してください（`https://learn.microsoft.com/ja-jp/microsoft-365-apps/deploy/overview-office-deployment-tool`）。

### 対象スクリプト
- `scripts/setup/install-office.ps1`

### 想定ディレクトリ構成
`setup.exe` と構成テンプレート XML は次のいずれかに配置してください。
- `scripts/setup/office/setup.exe`
- `scripts/setup/office/ODT/setup.exe`

構成テンプレート XML（いずれかが存在すること）
- 365 用: `scripts/setup/office/configuration-365.xml` または `scripts/setup/office/installconfig-365.xml`、フォールバックとして `configuration.xml`
- Bundle 2019 用: `scripts/setup/office/configuration-2019-bundle.xml` または `installconfig-2019.xml`
- Bundle 2021 用: `scripts/setup/office/configuration-2021-bundle.xml` または `installconfig-2021.xml`

テンプレート XML 内で以下のトークンを使用できます。スクリプトが置換してから `/configure` を実行します。
- `{{SERIAL_NUMBER}}`（必須）
- `{{MACHINE_NAME}}`（任意）
- `{{PRODUCT_KEY}}`（Bundle 系で必須）

ODT の詳細や構成要素は公式ドキュメントを参照してください（`https://learn.microsoft.com/ja-jp/microsoft-365-apps/deploy/overview-office-deployment-tool`）。

### 前提条件
- ODT の `setup.exe` を上記いずれかのパスに配置済み
- 該当するライセンスタイプに対応するテンプレート XML が存在
- `config/machine_list.csv` に以下の列が存在し、対象マシンの行が登録されていること
  - `Serial Number`
  - `Machine Name`
  - `Office License Type`（例: `365`, `Bundle2019`, `Bundle2021`。表記ゆれも一部吸収: `o365/m365/office365`→`365`、`office2019`→`Bundle2019`、`office2021`→`Bundle2021`）
  - `Office Product Key`（Bundle 系では必須）

### 実行手順
管理者 PowerShell で実行します。

```
pwsh -File scripts/setup/install-office.ps1 -Force
```

スクリプトの挙動概要
1. シリアル番号を取得し、`config/machine_list.csv` から該当行を検索
2. `Office License Type` を正規化（`365` / `bundle2019` / `bundle2021` など）
3. ODT の `setup.exe` とライセンスタイプに対応するテンプレート XML を探索
4. テンプレート内の `{{SERIAL_NUMBER}}`, `{{MACHINE_NAME}}`, `{{PRODUCT_KEY}}` を置換した一時 XML を `%TEMP%` に生成
5. `setup.exe /configure <一時XML>` を実行
6. 成否をログ出力し、完了時は `status/install-office.completed` を作成

### ログと完了フラグ
- ログ: `logs/install-office.log`（共通ログ基盤により保存。スクリプト名: `InstallOffice`）
- 完了フラグ: `status/install-office.completed`

`Office Product Key` はログ上で末尾 5 桁を除きマスクされます。

### テンプレート XML サンプル（抜粋）
以下は 365 用の一例です。実際の構成要素は環境に合わせて調整してください。

```xml
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="ja-jp" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <!-- カスタム要素にトークンを埋め込む例 -->
  <Property Name="CUSTOM_SERIAL" Value="{{SERIAL_NUMBER}}" />
  <Property Name="CUSTOM_MACHINE" Value="{{MACHINE_NAME}}" />
</Configuration>
```

Bundle 版（永続ライセンス）の場合、テンプレート側で `PIDKEY` を受け取るようにします。

```xml
<Configuration>
  <Add OfficeClientEdition="64">
    <Product ID="ProPlus2021Retail" PIDKEY="{{PRODUCT_KEY}}">
      <Language ID="ja-jp" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="CUSTOM_SERIAL" Value="{{SERIAL_NUMBER}}" />
</Configuration>
```

ODT の構成方法や要素は公式を参照してください（`https://learn.microsoft.com/ja-jp/microsoft-365-apps/deploy/overview-office-deployment-tool`）。

### トラブルシューティング
- 「setup.exe が見つかりません」: `scripts/setup/office/` または `scripts/setup/office/ODT/` に配置されているか確認
- 「テンプレート XML が見つかりません」: ライセンスタイプに対応する候補ファイル名で配置されているか確認
- 「Bundle でプロダクトキー未指定」: `Office Product Key` が空でないかを `config/machine_list.csv` で確認
- ODT の詳細ログ: `%temp%` 配下の ODT ログや、ODT のログオプションを活用

### セキュリティ注意事項
- プロダクトキーは CSV とテンプレートの取り扱いに注意し、リポジトリに平文でコミットしない運用を推奨
- スクリプトはキーをマスクしてログ出力します（末尾 5 桁以外を非表示）

### 参考資料
- Office 展開ツール（ODT）概要: `https://learn.microsoft.com/ja-jp/microsoft-365-apps/deploy/overview-office-deployment-tool`
