# レジストリ設定ガイド

## 概要

Windows Kitting Workflowでは、`.reg`ファイルを使用してWindowsのレジストリ設定を自動的に適用できます。
このドキュメントでは、含まれているレジストリ設定の詳細と、カスタム設定の追加方法について説明します。

## 含まれている設定ファイル

### 1. 01_explorer_settings.reg - エクスプローラーの設定

**目的**: ファイル拡張子を表示してセキュリティ向上と誤操作防止

```reg
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"HideFileExt"=dword:00000000  ; 0=拡張子表示, 1=拡張子非表示
```

**効果**:
- 既知のファイル種類でも拡張子が表示される
- 悪意のあるファイルを見分けやすくなる
- ファイル操作時の誤操作を防止

### 2. 02_performance_settings.reg - パフォーマンス設定

**目的**: システムの応答性向上と視覚効果の最適化

```reg
[HKEY_CURRENT_USER\Control Panel\Desktop]
"AutoEndTasks"="1"                    ; 応答停止アプリを自動終了
"HungAppTimeout"="1000"               ; アプリ応答タイムアウト(ミリ秒)
"WaitToKillAppTimeout"="2000"         ; アプリ強制終了タイムアウト
"LowLevelHooksTimeout"="1000"         ; フック応答タイムアウト

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects]
"VisualFXSetting"=dword:00000002      ; 2=パフォーマンス重視

[HKEY_CURRENT_USER\Control Panel\Mouse]
"MouseHoverTime"="400"                ; マウスホバー時間(ミリ秒)
```

**効果**:
- 応答のないアプリケーションの自動終了
- アプリ終了タイムアウトの短縮（1秒）
- アプリ強制終了タイムアウトの短縮（2秒）
- マウスホバー時間短縮（400ミリ秒）
- 視覚効果をパフォーマンス重視に設定

### 3. 03_privacy_settings.reg - プライバシー設定とUI調整

**目的**: 不要な情報収集・広告配信の抑制とタスクバーの最適化

```reg
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Privacy]
"TailoredExperiencesWithDiagnosticDataEnabled"=dword:00000000  ; カスタム体験無効

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager]
"SystemPaneSuggestionsEnabled"=dword:00000000      ; システムパネル提案無効
"SilentInstalledAppsEnabled"=dword:00000000        ; サイレントアプリインストール無効
"ContentDeliveryAllowed"=dword:00000000            ; コンテンツ配信無効
"OemPreInstalledAppsEnabled"=dword:00000000        ; プリインストールアプリ無効

[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
"ShowTaskViewButton"=dword:00000000   ; タスクビューボタン非表示
"ShowCortanaButton"=dword:00000000    ; Cortanaボタン非表示
```

**効果**:
- カスタマイズされたエクスペリエンス無効化
- システムパネルの提案無効化
- サイレントアプリインストール無効化
- コンテンツ配信無効化
- プリインストールアプリ関連機能無効化
- タスクビュー・Cortanaボタンの非表示

## 安全性について

### 自動バックアップ機能
- レジストリ変更前に自動的にバックアップが作成されます
- バックアップは `backup/registry/` に保存されます
- 日時付きファイル名で複数のバックアップを保持

### 適用される設定の安全性
- **ユーザーレベル設定**: HKEY_CURRENT_USER のみ変更（システム全体に影響しない）
- **リバーシブル**: 全ての設定は手動で元に戻すことが可能
- **最小限の変更**: セキュリティやプライバシー、パフォーマンス向上に関する設定のみ

## カスタム設定の追加

### 1. 新しい.regファイルの作成

```
config/registry/04_custom_settings.reg
```

### 2. ファイル形式とガイドライン

```reg
Windows Registry Editor Version 5.00

; コメント: 設定の説明を記載
[HKEY_CURRENT_USER\Your\Registry\Path]
"SettingName"="StringValue"           ; 文字列値
"NumericSetting"=dword:00000001       ; 数値（16進数）
"BinarySetting"=hex:01,02,03          ; バイナリ値
```

### 3. 推奨事項
- **HKEY_CURRENT_USER のみ使用**: システム全体への影響を避ける
- **コメント追加**: 設定の目的と効果を記載
- **段階的適用**: 少数の設定から始めて動作確認
- **事前テスト**: 仮想環境などでテストしてから本番適用

### 4. 設定例

```reg
; デスクトップアイコンのカスタマイズ
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel]
"{20D04FE0-3AEA-1069-A2D8-08002B30309D}"=dword:00000000  ; PC表示
"{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"=dword:00000000  ; コントロールパネル表示
```

## 設定の適用と確認

### 適用タイミング
- メインワークフロー実行時に自動適用
- 手動実行: `.\scripts\setup\import-registry.ps1`

### 設定の確認方法

1. **レジストリエディタで確認**
   ```cmd
   regedit
   ```

2. **PowerShellで確認**
   ```powershell
   # ファイル拡張子表示設定の確認
   Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt"
   
   # 視覚効果設定の確認
   Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting"
   ```

3. **設定の効果確認**
   - エクスプローラーでファイル拡張子が表示されることを確認
   - タスクバーからタスクビュー/Cortanaボタンが消えることを確認
   - アプリケーションの応答性向上を体感

### トラブルシューティング
- 設定が反映されない場合は、一度ログオフ・ログオンを試行
- バックアップファイルから復元: `backup/registry/` のファイルをダブルクリック

## 関連ドキュメント
- [メインREADME](../README.md)
- [トラブルシューティングガイド](Troubleshooting.md)
- [カスタマイズガイド](Customization-Guide.md)
