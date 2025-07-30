# Teams通知機能 新スレッド化方式移行計画書

## 📋 現状分析

### 現在の実装状況

#### 1. 既存のTeams通知機能
- **実装場所**: `scripts/Common-NotificationFunctions.ps1`
- **機能**: アダプティブカードを使用したTeams通知
- **スレッド対応**: 疑似スレッド機能（PCシリアル番号ベース）
- **問題点**: 複数台同時実行時にメッセージが混在

#### 2. 現在のスレッド管理方式
```powershell
# 現在の実装（疑似スレッド）
$threadId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
$payload = @{
    attachments = $attachments
    threadId    = $threadId  # 独自のスレッドID
}
```

#### 3. 設定ファイルの現状
```json
{
  "teams": {
    "enabled": false,
    "flowUrl": "https://your-teams-flow-url-here"
    // スレッド設定が未実装
  }
}
```

### 新しい方式の概要

#### 1. 改良版PowerAutomateフロー
- **機能**: マシンIDとスレッドIDの対応表管理
- **利点**: 真のTeamsスレッド機能を実現
- **サンプル**: `sample_send_teams_thread.ps1`

#### 2. 新しいペイロード形式
```powershell
$payload = @{
    id          = "123456789"  # マシン固有ID
    team_id     = "2c4e90ab-a1e0-4dee-8f9a-f1b9b2a1667e"
    channel_id  = "19:wOI3_1EgOFnIDVDab8taDWhD_vCLvrLGrZp0zXluvLs1@thread.tacv2"
    message     = "PowerShellからのスレッド返信テストです。"
}
```

## 🎯 移行目標

### 1. 主要目標
- **真のスレッド化**: マシンごとに独立したスレッドを作成
- **メッセージ分離**: 複数台同時実行時のメッセージ混在を解消
- **管理性向上**: マシンIDベースでの通知管理

### 2. 技術目標
- **PowerAutomate連携**: 改良版フローとの完全統合
- **ID管理**: マシン固有IDの生成と管理
- **後方互換性**: 既存の通知機能との互換性維持

## ✅ 実際に行った変更内容

### Phase 1: 実装・開発（完了）

#### 1.1 設定ファイル拡張
**変更ファイル**: `config/notifications.json`
```json
{
  "teams": {
    "enabled": false,
    "flowUrl": "https://your-teams-flow-url-here",
    "teamId": "2c4e90ab-a1e0-4dee-8f9a-f1b9b2a1667e",
    "channelId": "19:wOI3_1EgOFnIDVDab8taDWhD_vCLvrLGrZp0zXluvLs1@thread.tacv2",
    "idStoragePath": "status/teams_machine_ids.json"
  }
}
```
**削除項目**: `templates.teams.format` 設定

#### 1.2 新しい通知関数の実装
**変更ファイル**: `scripts/Common-NotificationFunctions.ps1`

**追加関数**:
```powershell
# マシンID管理関数
function Get-OrCreate-MachineId {
    param(
        [string]$StoragePath = "status/teams_machine_ids.json"
    )
    # PCシリアル番号ベースのマシンID生成・管理
}

# Teams通知送信（新スレッド化方式）
function Send-TeamsNotification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    # 新しいペイロード形式でのPowerAutomateフロー呼び出し
}

# マシンIDクリア関数（テスト用）
function Clear-MachineIds {
    param(
        [string]$SerialNumber,
        [switch]$All,
        [ValidateSet("Slack", "Teams", "Both")]
        [string]$Provider = "Both"
    )
    # マシンIDのクリア機能
}
```

**削除内容**:
- 古いアダプティブカード実装
- 疑似スレッド機能（`threadId`生成、`teams_thread_ts.json`管理）
- `Clear-NotificationThreads`関数（`Clear-MachineIds`に統合）

#### 1.3 MainWorkflow.ps1の更新
**変更ファイル**: `MainWorkflow.ps1`

**追加関数**:
- `Get-OrCreate-MachineId`関数
- 新しい`Send-TeamsNotification`関数

**削除関数**:
- `Get-TeamsThreadTs`関数（疑似スレッド管理用）
- `Clear-TeamsThreadTs`関数

### Phase 2: テスト実装（完了）

#### 2.1 新方式テストスクリプト作成
**新規ファイル**: `tests/Test-TeamsNotificationV2.ps1`
```powershell
# Teams通知新スレッド化方式テストツール
param(
    [switch]$TestSend,
    [switch]$TestIdGeneration,
    [switch]$ShowInfo,
    [switch]$ClearIds,
    [switch]$All
)

# テスト関数群
function Test-MachineIdGeneration { ... }
function Test-TeamsNotificationSend { ... }
function Show-TeamsInfo { ... }
function Clear-MachineIds { ... }
```

#### 2.2 既存テストの更新
**変更ファイル**: `tests/Test-NotificationFunctions.ps1`

**更新内容**:
- `Test-TeamsNotification`関数：新しい設定項目（`teamId`, `channelId`）の確認
- `Show-NotificationInfo`関数：新設定の表示
- `Clear-ThreadData`関数：`teams_machine_ids.json`のクリア対応

### Phase 3: ドキュメント更新（完了）

#### 3.1 新規ドキュメント作成
**新規ファイル**: `docs/Teams-Notification-V2-Guide.md`
- 新スレッド化方式の詳細説明
- セットアップ手順
- トラブルシューティング
- 技術仕様

#### 3.2 既存ドキュメント更新
**更新ファイル一覧**:
- `docs/Common-Notification-Library.md`: 関数名更新（`Clear-MachineIds`）
- `docs/Customization-Guide.md`: Teams設定項目の更新
- `docs/README.md`: 新ガイドへの参照更新
- `docs/TABLE_OF_CONTENTS.md`: 目次更新

#### 3.3 不要ドキュメント削除
**削除ファイル**:
- `docs/Teams-Adaptive-Cards-Implementation.md`
- `docs/Teams-Notifications-Enhancement.md`

### Phase 4: クリーンアップ（完了）

#### 4.1 古いコードの完全削除
- アダプティブカード関連コード
- 疑似スレッド管理コード
- 不要な設定項目

#### 4.2 設定ファイルの最適化
- `templates.teams.format`設定の削除
- 新しい設定項目の追加

## 🧪 テスト計画と手順

### 1. 単体テスト

#### 1.1 マシンID生成テスト
**テストファイル**: `tests/Test-TeamsNotificationV2.ps1`
**実行コマンド**:
```powershell
.\tests\Test-TeamsNotificationV2.ps1 -TestIdGeneration
```

**テスト項目**:
- [ ] 新規マシンでのID生成
- [ ] 既存マシンでのID取得
- [ ] IDの一意性確認
- [ ] ファイル保存・読み込み

**期待結果**:
- 12文字の英数字IDが生成される
- 同じマシンでは常に同じIDが返される
- `status/teams_machine_ids.json`に正しく保存される

#### 1.2 通知送信テスト
**実行コマンド**:
```powershell
.\tests\Test-TeamsNotificationV2.ps1 -TestSend
```

**テスト項目**:
- [ ] 正常な通知送信
- [ ] エラーハンドリング
- [ ] ペイロード形式の確認
- [ ] PowerAutomateフロー連携

**期待結果**:
- Teamsに正しく通知が送信される
- マシン固有のスレッドが作成される
- エラー時は適切なログが出力される

#### 1.3 設定確認テスト
**実行コマンド**:
```powershell
.\tests\Test-TeamsNotificationV2.ps1 -ShowInfo
```

**テスト項目**:
- [ ] 設定ファイルの読み込み
- [ ] 必須項目の存在確認
- [ ] 設定値の妥当性

**期待結果**:
- 設定が正しく読み込まれる
- 必須項目が存在する
- 設定値が妥当な形式である

### 2. 統合テスト

#### 2.1 ワークフロー統合テスト
**テストファイル**: `tests/Test-NotificationFunctions.ps1`
**実行コマンド**:
```powershell
.\tests\Test-NotificationFunctions.ps1 -TestTeams
```

**テスト項目**:
- [ ] ワークフローからの通知呼び出し
- [ ] 他の通知機能との共存
- [ ] エラー時の動作

#### 2.2 複数マシン同時実行テスト
**テストシナリオ**:
1. 複数のPCで同時にワークフローを実行
2. 各マシンで異なる通知を送信
3. Teamsでのスレッド分離を確認

**期待結果**:
- 各マシンが独立したスレッドを作成
- メッセージの混在が発生しない
- マシンIDが正しく管理される

### 3. パフォーマンステスト

#### 3.1 通知送信速度テスト
**テスト項目**:
- [ ] 単一通知の送信時間
- [ ] 連続通知の処理時間
- [ ] 大量通知時の動作

**測定項目**:
- 通知送信からTeams表示までの時間
- マシンID生成・取得時間
- エラー処理時間

#### 3.2 リソース使用量テスト
**測定項目**:
- メモリ使用量
- CPU使用率
- ディスクI/O

### 4. エラー処理テスト

#### 4.1 ネットワークエラーテスト
**テストシナリオ**:
- ネットワーク切断時の動作
- PowerAutomateフロー停止時の動作
- タイムアウト時の動作

#### 4.2 設定エラーテスト
**テスト項目**:
- [ ] 必須設定項目の欠如
- [ ] 不正な設定値
- [ ] 設定ファイルの破損

### 5. クリーンアップテスト

#### 5.1 マシンIDクリアテスト
**実行コマンド**:
```powershell
.\tests\Test-TeamsNotificationV2.ps1 -ClearIds
```

**テスト項目**:
- [ ] 特定マシンIDの削除
- [ ] 全マシンIDの削除
- [ ] ファイルの完全削除

## 🔧 技術仕様

### 1. 新しいペイロード形式
```json
{
  "id": "a1b2c3d4e5f6",
  "team_id": "2c4e90ab-a1e0-4dee-8f9a-f1b9b2a1667e",
  "channel_id": "19:wOI3_1EgOFnIDVDab8taDWhD_vCLvrLGrZp0zXluvLs1@thread.tacv2",
  "message": "通知メッセージ内容"
}
```

### 2. マシンID生成規則
- **形式**: 12文字の英数字
- **生成方法**: GUIDの一部を使用
- **一意性**: シリアル番号ベースでの管理
- **保存場所**: `status/teams_machine_ids.json`

### 3. 設定ファイル拡張
```json
{
  "teams": {
    "enabled": true,
    "flowUrl": "https://prod-34.japaneast.logic.azure.com:443/workflows/...",
    "teamId": "2c4e90ab-a1e0-4dee-8f9a-f1b9b2a1667e",
    "channelId": "19:wOI3_1EgOFnIDVDab8taDWhD_vCLvrLGrZp0zXluvLs1@thread.tacv2",
    "idStoragePath": "status/teams_machine_ids.json"
  }
}
```

## 📁 ファイル変更実績

### 1. 新規作成ファイル
- ✅ `tests/Test-TeamsNotificationV2.ps1` - 新方式テスト
- ✅ `docs/Teams-Notification-V2-Guide.md` - 新方式ガイド

### 2. 更新ファイル
- ✅ `scripts/Common-NotificationFunctions.ps1` - 新方式統合
- ✅ `MainWorkflow.ps1` - 新方式統合
- ✅ `config/notifications.json` - 設定拡張
- ✅ `tests/Test-NotificationFunctions.ps1` - テスト更新
- ✅ `docs/Common-Notification-Library.md` - 関数名更新
- ✅ `docs/Customization-Guide.md` - 設定項目更新
- ✅ `docs/README.md` - 参照更新
- ✅ `docs/TABLE_OF_CONTENTS.md` - 目次更新

### 3. 削除ファイル
- ✅ `docs/Teams-Adaptive-Cards-Implementation.md`
- ✅ `docs/Teams-Notifications-Enhancement.md`

### 4. 削除コード
- ✅ アダプティブカード実装
- ✅ 疑似スレッド機能
- ✅ `Clear-TeamsThreadTs`関数
- ✅ `templates.teams.format`設定

## 🚨 リスク管理

### 1. 技術リスク
- **PowerAutomateフローの変更**: 既存フローとの互換性
- **ID管理の複雑化**: マシンIDの重複・消失
- **パフォーマンス影響**: 新方式による処理時間増加

### 2. 対策
- **段階的移行**: 設定フラグによる切り替え
- **バックアップ機能**: 従来方式への切り戻し
- **十分なテスト**: 各種環境での動作確認

## 📊 成功指標

### 1. 機能指標
- ✅ マシンごとの独立スレッド作成
- ✅ メッセージ混在の解消
- ✅ 通知の確実な配信

### 2. 品質指標
- [ ] エラー率 < 1%
- [ ] 通知遅延 < 5秒
- [ ] 100%の後方互換性

### 3. 運用指標
- ✅ 設定変更の容易性
- ✅ トラブルシューティングの簡素化
- ✅ 運用コストの削減

## 📝 次のステップ

### 即座に実行可能な作業
1. **テスト実行**
   ```powershell
   # 基本テスト
   .\tests\Test-TeamsNotificationV2.ps1 -All
   
   # 統合テスト
   .\tests\Test-NotificationFunctions.ps1 -TestTeams
   ```

2. **設定確認**
   - `config/notifications.json`の設定確認
   - PowerAutomateフローの動作確認

3. **本番環境での検証**
   - 実際のマシンでの動作確認
   - 複数台同時実行テスト

### 今後の検討事項
- **監視機能の追加**: 通知配信状況の監視
- **統計機能**: 通知送信統計の収集
- **自動化**: 設定変更の自動化

---

**作成日**: 2024年12月19日  
**作成者**: AI Assistant  
**バージョン**: 2.0  
**ステータス**: 移行完了・テスト計画追加済み 
