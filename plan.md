## 完了マーカー集中管理 設計プラン（Windows Kitting Workflow）

### 背景 / 課題
- 各セットアップスクリプトが独自に `status/*.completed` を作成しており、重複・不整合がある
  - 例: `AutoLogin.ps1`, `TaskScheduler.ps1`, `setup-wifi.bat`, `enable-admin.bat`, 一部 PowerShell スクリプト
- 同一スクリプトを異なる引数で複数回実行したい場合、固定名の完了マーカーは不便
- すでにメインエンジン（`MainWorkflow.ps1`）でもステップ成功時に完了マーカーを作成しており、役割が二重化

### 現状整理（抜粋）
- `MainWorkflow.ps1` 内 `Invoke-WorkflowStep` にて、成功時に `Step.completionCheck.path` をもとにマーカーを作成
- 各スクリプト側でも独自のマーカー作成が混在（例: `status\autologin-setup.completed`, `status\task-scheduler-setup.completed` など）
- 共通ヘルパー `scripts/Common-WorkflowHelpers.ps1` に `Get-CompletionMarkerPath -TaskName <name>` が存在し、一部スクリプトで使用

### 目標
- 完了マーカーの生成をメインエンジン（`MainWorkflow.ps1`）に一元化
- マーカー名は「ワークフローステップID」をキーに決定（= 同一スクリプトを複数回実行しても `id` ごとに一意）
- 既存の `workflow.json` は互換を維持しつつ、段階的に `status/{step.id}.completed` へ移行
- スクリプトは「成功/失敗コードの返却」に専念し、マーカーは原則作成しない（必要なら詳細情報のみ別ファイルへ）

### 設計方針
1) マーカーの命名規則（標準）
- 既定の完了マーカー: `status/{step.id}.completed`
- `workflow.json` の各 `steps[*].id` はユニーク前提（同一スクリプトの多重実行は `id` を変えて表現）

2) パス解決のルール（互換性考慮）
- `completionCheck.type == "file"` の場合:
  - `completionCheck.path` が指定されない場合: 既定で `status/{step.id}.completed`
  - `completionCheck.path` にプレースホルダを導入し展開:
    - `{id}` or `{stepId}` → ステップID
    - `{timestamp}` → `yyyyMMdd-HHmmssfff`（必要時）
    - `{param:Name}` → ステップ引数の値（必要時）
- 既存互換: プレースホルダが無い文字列が指定されている場合は、そのパスを優先（当面の後方互換）

3) 中央集約の実装ポイント（`MainWorkflow.ps1`）
- 新規関数を導入（疑似）
  - `Compute-CompletionMarkerPath([object]$Step)`
    - 優先度: 明示パス（非テンプレート） > テンプレートパス展開 > 既定 `status/{id}.completed`
  - `Write-StepCompletion([object]$Step, [int]$ExitCode)`
    - `Compute-CompletionMarkerPath` で決めたパスへ JSON で書き出し
- `Test-StepCompletion` も同じパス決定ロジックを使用

4) スクリプト側のルール
- スクリプトは原則、完了マーカー（標準）を作成しない
- 付加情報を残したい場合は、以下に詳細を出力（例）
  - `status/details/{step.id}.json` または `logs/scripts/<script>.log`
-（任意）メインエンジンから環境変数を提供:
  - `WKF_STEP_ID={step.id}`
  - `WKF_RUN_ID={初回実行の識別子}`（既存の `workflow-initial-start.json` に紐付け）

### 段階的移行計画
Phase 0: 現状維持 + 解析
- 影響箇所の棚卸し（完了）

Phase 1: メインエンジンの拡張（互換モード）
- `MainWorkflow.ps1` にパス決定・書き込みの集中ロジックを追加
- `completionCheck.path` が明示（非テンプレート）のステップは現状通り、そのパスで読み書き
- 未指定またはテンプレート指定のステップは `status/{id}.completed` を使用

Phase 2: `workflow.json` の整理
- 各ステップの `completionCheck.path` を `status/{id}.completed`（テンプレート）に統一、もしくは省略
- ドキュメント更新（完了マーカーはステップID基準で決まることを明記）

Phase 3: スクリプトの整理
- 既存のスクリプト内マーカー作成を削除/無効化（必要なら詳細情報のみ `status/details/` へ）
- `Common-WorkflowHelpers.ps1` に詳細出力用ユーティリティを追加（例: `Write-CompletionDetail -StepId <id> -Data <obj>`）

Phase 4: フェーズアウト
- 旧固定名マーカーの参照・作成コードを削除
- クリーニング手順（`status/*.completed` の旧ファイル削除ガイド）をドキュメント化

### 実装タスク（概要）
- `MainWorkflow.ps1`
  - `Compute-CompletionMarkerPath` を追加
  - `Test-StepCompletion`, `Invoke-WorkflowStep` で同ロジックを使用
  - スクリプト実行時に `WKF_STEP_ID`, `WKF_RUN_ID` を環境変数で引き渡し（任意）
- `scripts/Common-WorkflowHelpers.ps1`
  - `Expand-PathPlaceholders -Template <string> -Step <object>` を追加（`{id}`, `{param:*}` 展開）
  - `Write-CompletionDetail -StepId <string> -Data <psobject>` を追加
- `config/workflow.json`
  - `completionCheck.path` を段階的に `status/{id}.completed`（推奨）へ移行、または省略
- スクリプト群
  - 既存のマーカー作成箇所を削除または `details/` へ移行
- ドキュメント
  - ガイドへ反映（開発ガイド、トラブルシュート、各機能ガイド）

### 仕様詳細（パス展開の例）
```json
{
  "id": "install-basic-apps",
  "completionCheck": {
    "type": "file",
    "path": "status/{id}.completed"
  }
}
```

```powershell
# 旧: 明示固定パス
#   status/install-basic-apps.completed
# 新: テンプレート or 省略で同等
```

拡張プレースホルダ例（必要に応じて）
```json
{
  "id": "copy-to-share-A",
  "parameters": { "DestinationPath": "\\\\server\\shareA" },
  "completionCheck": { "type": "file", "path": "status/{id}.completed" }
}
```

### 検証手順
1. Dry-run（`MainWorkflow.ps1 -DryRun`）でパス展開とマーカー作成スキップのログを確認
2. 少数ステップで本実行し、`status/{id}.completed` が作成されることを確認
3. 同一スクリプト・異なる `id` の複数ステップを実行し、マーカーの衝突が無いことを確認
4. 再起動を跨いで再開できること（`Test-StepCompletion` が同ロジックで検知）

### 影響範囲 / リスク
- 旧スクリプトが独自マーカーを引き続き作成する場合、二重マーカーが発生（移行期間の想定挙動）
- `workflow.json` の `id` 重複は致命的（ユニークチェックの導入を推奨）
- テンプレート展開の仕様追加による学習コスト（ドキュメントで吸収）

### まとめ
- 完了マーカーは「ステップID」基準でメインエンジンが集中管理
- `status/{id}.completed` を標準化し、スクリプトは成功/失敗の終了コードに専念
- 互換モードで段階移行し、最終的に旧固定名マーカーを廃止
