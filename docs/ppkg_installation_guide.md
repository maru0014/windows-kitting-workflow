## PPKG インストールガイド（Windows Kitting Workflow）

このガイドでは、Windows Kitting Workflow で Provisioning Package (.ppkg) を適用する方法を説明します。ワークフローには `scripts/setup/install-ppkg.ps1` が含まれ、`config/start_pins.ppkg` を例としてスタートメニューのピン留めを「コントロールパネル」と「Microsoft Edge」のみに置き換えます。

### 目的
- PPKG を安全に適用・（任意で）削除する一連の手順をスクリプト化
- ログ保存・完了マーカー出力・ワークフロー統合を標準化

### 前提条件
- 管理者権限が推奨（権限不足で適用に失敗する可能性があります）
- PPKG コマンドレットが使用可能な環境（`Get/Add/Remove-ProvisioningPackage`）
- ファイル配置例: `config/start_pins.ppkg`

### スクリプトの場所
- スクリプト: `scripts/setup/install-ppkg.ps1`
- ログ: `logs/scripts/install-ppkg.log` と `logs/ppkg/` 配下
- 完了判定: MainWorkflow が `status/{id}.completed`（既定: `status/install-ppkg.completed`）を作成
  - 互換: `completionCheck.path` のパスが存在しても完了とみなされます

### 使い方（単体実行）
```powershell
# config 配下で単一の .ppkg が見つかった場合、それを自動で適用
.\scripts\setup\install-ppkg.ps1

# 明示的にパスを指定
.\scripts\setup\install-ppkg.ps1 -PackagePath "config\start_pins.ppkg"

# 既存の同一 PackageId を削除してから適用
.\scripts\setup\install-ppkg.ps1 -PackagePath "config\start_pins.ppkg" -RemoveExisting

# インストール直後に削除（検証向け）
.\scripts\setup\install-ppkg.ps1 -PackagePath "config\start_pins.ppkg" -RemoveAfterInstall
```

### パラメータ
- `-PackagePath <path>`: 適用する `.ppkg` のパス。未指定時は `config` 配下から単一ファイルを自動選択
- `-Force`: `Add-ProvisioningPackage` に `-ForceInstall` を付与
- `-RemoveExisting`: 同一 `PackageId` の既存適用がある場合、事前に削除
- `-RemoveAfterInstall`: 適用直後に削除（サンプル動作の再現）
- `-Help`: 使い方を表示

### ワークフローへの統合
`config/workflow.json` には、タスクバーレイアウト適用の直後に PPKG インストール手順が登録されています。

抜粋（既定では `config/start_pins.ppkg` を適用）:
```json
{
  "id": "install-ppkg",
  "name": "PPKGインストール",
  "script": "scripts/setup/install-ppkg.ps1",
  "type": "powershell",
  "runAsAdmin": true,
  "parameters": {
    "PackagePath": "config/start_pins.ppkg"
  },
  "completionCheck": { "type": "file" },
  "dependsOn": ["apply-taskbar-layout"],
  "onError": "continue"
}
```

### 成功の確認
- `status/install-ppkg.completed`（または互換パス）が存在する（JSON には `packageId`, `packageName`, `version` などの情報が MainWorkflow 側詳細に保存される場合があります）
- `logs/ppkg/` に `Add-ProvisioningPackage` のログが出力される
- スタートメニューのピン留めが「コントロールパネル」と「Microsoft Edge」のみに置き換わる（サンプル PPKG の場合）

### 既存の PPKG の確認・削除
```powershell
# インストール済み PPKG の一覧
Get-ProvisioningPackage -AllInstalledPackages

# PackageId を指定して削除
Remove-ProvisioningPackage -PackageId <PACKAGE_ID>
```

### 注意事項
- 本サンプル PPKG は「スタートメニューのピン留め」のみを変更します。タスクバーのピン留めは `apply-taskbar-layout.ps1` で行います
- PPKG の適用対象やユーザー範囲は PPKG の内容に依存します。必要に応じて Windows Configuration Designer で編集してください


### PPKG の作成手順（概要）

- Windows 構成デザイナーを起動し、「高度なプロビジョニング」を選択
- プロジェクト名を入力し、対象の Windows エディション/デバイス種別を選択
- 必要な設定（共通設定、ポリシー、アプリ/スクリプト、ファイル、レジストリなど）を追加・編集
- エクスポート/ビルド時にパッケージ情報を設定（名前、任意でバージョン、所有者は「IT 管理者」、任意で順位）
- セキュリティ（任意）：暗号化または署名を選択。署名運用の場合は信頼済みプロビジョナーの証明書配置や `RequireProvisioningPackageSignature` の方針を検討
- 出力先を指定してビルドし、生成された `.ppkg` を取得
- 生成した `.ppkg` を本リポジトリの `config/` に配置し、本ガイドの手順で適用

参考（公式ヘルプ）：プロビジョニング パッケージを作成する（詳細）
`https://learn.microsoft.com/ja-jp/windows/configuration/provisioning-packages/provisioning-create-package`


### スタートメニュー設定のエクスポート手順（概要）

- 参照端末でタスクバーとスタートのピンを理想状態に整える
- スタート ピンのエクスポート（Windows 10 は XML、Windows 11 は JSON）
  - PowerShell（管理者）:
```powershell
Export-StartLayout -Path .\StartLayout.json
```
- エクスポート内容のアプリ情報を `config/TaskbarLayoutModification.XML` に反映
  - UWP/Store アプリ: 取得した AppUserModelID を `<taskbar:UWA ...>` に設定
  - デスクトップアプリ: `.lnk` を `<taskbar:DesktopApp DesktopApplicationLinkPath="...">` に設定
- タスクバーのピン自体を直接「エクスポート」する公式手段はないため、XML を手動で整備するのが確実
- 組織配布の参考（スタート ピン）
  - MDM/GPO: `Start/ConfigureStartPins`（Windows 11 24H2 以降、KB5062660）
  - PPKG: `Policies/Start/ConfigureStartPins` に JSON を 1 行で設定（改行除去）

参考: [Microsoft Learn: スタート画面のレイアウトをカスタマイズします](https://learn.microsoft.com/ja-jp/windows/configuration/start/layout?tabs=intune-10%2Cintune-11&pivots=windows-10)
