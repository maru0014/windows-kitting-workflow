# ドキュメント修正計画（fix/docs-links-and-structure）

## 目的
- プロジェクトの実体とドキュメントの不整合（リンク切れ・ファイル構成の相違）を解消する。

## 対応内容
1. README.md（ルート）
   - ファイル構成から `config/autologin.json` を削除。
   - `config/wi-fi.xml` をファイル構成に追記。
   - ドキュメント一覧内のリンクを実体に合わせて修正：
     - `docs/Teams-Notifications-Enhancement.md` → `docs/Teams-Notification-V2-Guide.md`
     - `docs/Teams-Adaptive-Cards-Implementation.md` は削除（該当ファイル不存在のため）。
   - ファイル構成の `docs/` セクションの一覧から上記2件を同様に修正/削除。

2. docs/README.md
   - 「技術実装詳細（開発者向け）」のリンクを実体に合わせて修正：
     - `Teams-Notifications-Enhancement.md` → `Teams-Notification-V2-Guide.md`
     - `Teams-Adaptive-Cards-Implementation.md` は削除。
   - 「開発・保守担当者」の推奨読書順序のリンクを同様に修正。
   - 「ドキュメント間の関連性」のツリーから不存在の2ファイルを削除し、`Teams-Notification-V2-Guide.md` を記載。

3. docs/Common-Notification-Library.md
   - 末尾「関連ドキュメント」の2リンクを `Teams-Notification-V2-Guide.md` に統合。

## 影響範囲
- ドキュメントのみ（コード・スクリプトには変更なし）。

## 確認手順
1. リンク切れ検出（置換漏れの確認）
   - `Teams-Notifications-Enhancement.md`／`Teams-Adaptive-Cards-Implementation.md` への参照が 0 件であることを確認。
2. ルート README のファイル構成が実ファイルと一致することを目視確認。

## コミット方針
- 1コミットでまとめて反映。


