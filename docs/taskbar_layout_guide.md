### タスクバー設定ガイド（Windows Kitting Workflow）

このドキュメントでは、Windows 11 のタスクバーにピン留めするアプリと並び順を、XML とスクリプトで統一適用する方法を説明します。

- **対象**: Windows 11 22H2 以降（ローカルユーザーごとの適用）
- **構成ファイル**: `config/TaskbarLayoutModification.XML`
- **適用スクリプト**: `scripts/setup/apply-taskbar-layout.ps1`

---

### 基本概念

- **ピン留め順序**: XML の並び順がタスクバー左→右の順序になります（Windows 11 で中央配置でも並び自体は維持）。
- **置換動作**: 本プロジェクトの XML は `PinListPlacement="Replace"` を使用し、既存のピン留めを置換します。
- **適用範囲**: スクリプトは「現在ログオン中のユーザー」プロファイルに対してのみ適用します。

---

### 設定ファイルの場所と例

`config/TaskbarLayoutModification.XML` にタスクバーピン留めを定義します。代表的な要素は以下です。

- **UWP/Store アプリ**: `<taskbar:UWA AppUserModelID="…" />`
- **デスクトップアプリ**: ショートカット経由 `<taskbar:DesktopApp DesktopApplicationLinkPath="…\*.lnk" />`
- **エクスプローラー（システムアプリ）**: `<taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />`

現在のファイルの主要部（抜粋）:

```9:18:config/TaskbarLayoutModification.XML
    <defaultlayout:TaskbarLayout>
        <taskbar:TaskbarPinList>
            <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />
            <taskbar:UWA AppUserModelID ="Microsoft.WindowsNotepad_8wekyb3d8bbwe!App"/>
            <taskbar:UWA AppUserModelID="Microsoft.WindowsCalculator_8wekyb3d8bbwe!App" />
            <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk"/>
            <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\Control Panel.lnk"/>
        </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
```

---

### エクスプローラーを左端に固定する

- **必須エントリ**: `Microsoft.Windows.Explorer`
- 上記のように `<taskbar:TaskbarPinList>` の先頭に次の 1 行を置くと、エクスプローラーが最左端になります。

```xml
<taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />
```

---

### よく使う AppUserModelID（例）

- **メモ帳**: `Microsoft.WindowsNotepad_8wekyb3d8bbwe!App`
- **電卓**: `Microsoft.WindowsCalculator_8wekyb3d8bbwe!App`
- （参考）Windows ターミナル: `Microsoft.WindowsTerminal_8wekyb3d8bbwe!App`（環境により異なる場合あり）

デスクトップアプリは `.lnk` を指定してください（例: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\System Tools\Command Prompt.lnk`）。

---

### 適用手順（スクリプト）

スクリプトは XML を `%LOCALAPPDATA%\Microsoft\Windows\Shell\LayoutModification.xml` に配置し、タスクバー関連レジストリ初期化後に Explorer を再起動します。

- **DryRun（動作確認）**:
```powershell
scripts/setup/apply-taskbar-layout.ps1 -DryRun
```

- **実適用（置換・再起動まで）**:
```powershell
scripts/setup/apply-taskbar-layout.ps1 -Force
```

- **XML を差し替えて適用**:
```powershell
scripts/setup/apply-taskbar-layout.ps1 -XmlPath "D:\path\to\TaskbarLayoutModification.XML" -Force
```

- **サイレント適用（ログのみ）**:
```powershell
scripts/setup/apply-taskbar-layout.ps1 -Force -Quiet
```

- **ログ/結果ファイル**
  - ログ: `logs/apply-taskbar-layout.log`
  - 完了マーカー: `status/apply-taskbar-layout.completed`

---

### ワークフローへの組み込み

`config/workflow.json` には、以下のステップが登録済みです（`deploy-desktop-files` の直後）。

```json
{
  "id": "apply-taskbar-layout",
  "name": "タスクバーレイアウト適用",
  "description": "TaskbarLayoutModification.XML を現在ユーザーに適用し、エクスプローラー等を指定順序でピン留め",
  "script": "scripts/setup/apply-taskbar-layout.ps1",
  "type": "powershell",
  "runAsAdmin": false,
  "parameters": { "Force": true, "Quiet": true },
  "completionCheck": { "type": "file", "path": "status/apply-taskbar-layout.completed" },
  "timeout": 180,
  "retryCount": 1,
  "rebootRequired": false,
  "dependsOn": ["deploy-desktop-files"],
  "onError": "continue"
}
```

---

### トラブルシュート

- **ピン留めが置換されない**:
  - XML の `PinListPlacement` が `Replace` であることを確認
  - サインアウト/サインイン、または再起動で反映が安定
  - 本スクリプトは `Taskband` と `CloudStore` を初期化済み

- **左端に見えない**:
  - Windows 11 のタスクバー配置が「中央」の場合、並びは中央寄せで表示。設定から「左寄せ」に変更可能

- **UWP の AUMID が不明**:
  - `Get-StartApps`（PowerShell）で AUMID を列挙可能

- **複数ユーザーでの適用**:
  - 本スクリプトは「実行ユーザー」のみ対象。複数ユーザーに適用する場合は、各ユーザーで実行するか、ログオン時に自動実行されるタスクを用意してください

- **元に戻したい**:
  - XML のピン留めリストを目的の状態に変更し、再度適用
  - ユーザー個別のカスタムを尊重したい場合は `Replace` → `Append` への変更を検討

---

### 変更履歴

- 2025-08-12: エクスプローラーを最左に固定。ワークフローへ適用ステップを追加。
