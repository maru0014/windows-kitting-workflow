# Windows Update設定

このレジストリファイルは、Windows Updateの動作に関する設定を行います。

## 設定内容

### AllowMUUpdateService
- **フルパス**: `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings`
- **キー名**: `AllowMUUpdateService`
- **設定値**: `dword:00000001`
- **意味**: Microsoft Update サービスの使用許可
- **選択肢**:
  - `0` (dword:00000000): 無効（Windows Updateのみ）
  - `1` (dword:00000001): 有効（Microsoft製品の更新も含める）

## 効果
- Microsoft Office製品の自動更新が可能
- Windows Update経由でMicrosoft製品を一元管理
- セキュリティ更新の包括的な適用
- システム管理の簡素化

## 対象製品
- Microsoft Office (Word, Excel, PowerPoint, Outlook等)
- Microsoft SQL Server
- Microsoft .NET Framework
- Microsoft Visual C++ 再頒布可能パッケージ
- その他のMicrosoft製品

## 推奨理由
- **セキュリティ**: 全Microsoft製品のセキュリティ更新を一元化
- **管理効率**: Windows Update経由での統合管理
- **自動化**: 手動での個別更新作業が不要
- **一貫性**: システム全体での更新ポリシーの統一

## 注意事項
- Microsoft Update サービスが有効になります
- Office等の更新により再起動が必要になる場合があります
- 企業環境では更新ポリシーとの整合性を確認してください
- WSUSやConfigMgr環境では設定の競合に注意

## 関連設定
この設定は以下の機能と連携します：
- Windows Update自動更新設定
- 再起動スケジュール設定
- 更新の延期設定
- メンテナンス時間設定
