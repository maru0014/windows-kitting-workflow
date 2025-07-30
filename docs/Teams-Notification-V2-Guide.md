# Teams通知V2 - 改行処理ガイド

## 概要

Windows Kitting WorkflowのTeams通知機能では、Power Automate側で`contentType: "html"`を指定することで、HTML改行タグ（`<br>`）が正しく表示されることが確認されています。

## 改行処理の仕組み

### PowerShell側の処理

`scripts/Common-NotificationFunctions.ps1`の`Send-TeamsNotification`関数では、以下の処理を行います：

1. **改行文字の正規化**: `\r\n`と`\r`を`\n`に統一
2. **HTML改行タグへの変換**: `\n`を`<br>`に置換
3. **JSONペイロードの送信**: Power Automateフローに送信

```powershell
# 改行文字を適切に処理（Teams対応版）
$processedMessage = $Message -replace "`r`n", "`n" -replace "`r", "`n"

# Teams対応の改行処理（HTML改行タグを使用）
# Power Automate側でcontentType: "html"を指定することで<br>タグが正しく反映される
$htmlMessage = $processedMessage -replace "`n", "<br>"
$payload.message = $htmlMessage
```

### Power Automate側の設定

Power Automateフローでは、Microsoft Graph APIを使用してTeamsにメッセージを送信する際に、以下の設定が必要です：

```json
{
  "body": {
    "content": "メッセージ内容（<br>タグを含む）",
    "contentType": "html"
  }
}
```

**重要**: `contentType`を`"html"`に設定することで、`<br>`タグが正しく改行として解釈されます。

## 設定手順

### 1. Power Automateフローの設定

1. Power Automateフローを開く
2. Microsoft Graph APIアクションを追加
3. リクエストボディに以下を設定：
   ```json
   {
     "body": {
       "content": "@{triggerBody()?['message']}",
       "contentType": "html"
     }
   }
   ```

### 2. テスト方法

`tests/Test-TeamsNotificationV2.ps1`を使用して改行処理をテストできます：

```powershell
# 改行テストを実行
.\tests\Test-TeamsNotificationV2.ps1 -TestLineBreaks
```

## トラブルシューティング

### 改行が表示されない場合

1. **Power Automate側の確認**:
   - `contentType`が`"html"`に設定されているか確認
   - リクエストボディの構造が正しいか確認

2. **PowerShell側の確認**:
   - ログで`HTML改行タグ適用後`のメッセージを確認
   - JSONペイロードに`<br>`タグが含まれているか確認

### よくある問題

- **`contentType`が`"text"`の場合**: `<br>`タグが文字列として表示される
- **`contentType`が設定されていない場合**: デフォルトで`"text"`として扱われる

## 参考情報

- [Microsoft Graph API - Create Message](https://docs.microsoft.com/en-us/graph/api/channel-post-messages)
- [Teams Markdown Formatting](https://support.microsoft.com/en-us/office/use-markdown-formatting-in-teams-4d10bd65-55e2-4b2d-a1f3-2bebdcd2c772)

## 変更履歴

- **2024年**: HTML改行タグ方式に統一
  - 複数の改行処理方法を削除
  - `<br>`タグのみを使用するように簡素化
  - Power Automate側での`contentType: "html"`設定を確認 
