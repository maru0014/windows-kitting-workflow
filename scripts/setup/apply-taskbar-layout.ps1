# =========================================================================
# タスクバー レイアウト適用スクリプト
# config\TaskbarLayoutModification.XML を現在ユーザーに適用
# =========================================================================

param(
    [string]$XmlPath,
    [switch]$Force,
    [switch]$DryRun,
    [switch]$Quiet,
    [switch]$Help
)

# ヘルプ表示
if ($Help) {
    Write-Host @"
タスクバー レイアウト適用スクリプト

使用方法:
    .\apply-taskbar-layout.ps1 [オプション]

パラメータ:
    -XmlPath <path>            レイアウト XML の明示パス（未指定時は config\TaskbarLayoutModification.XML を使用）
    -Force                     既存ファイルやレジストリ削除を強制
    -DryRun                    実際の操作を行わず、実行予定のみ出力
    -Quiet                     コンソール出力を抑制（ログには出力）
    -Help                      このヘルプを表示

説明:
    指定された XML（-XmlPath）または config\TaskbarLayoutModification.XML を
    %LOCALAPPDATA%\Microsoft\Windows\Shell\LayoutModification.xml に配置し、
    タスクバー関連の設定を初期化後、Explorer を再起動して適用します。
"@
    exit 0
}

# 共通ログ関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-LogFunctions.ps1")
# ヘルパー関数の読み込み
. (Join-Path (Split-Path $PSScriptRoot -Parent) "Common-WorkflowHelpers.ps1")

$ScriptName = "apply-taskbar-layout"

# ログ関数（コンソール抑制対応）
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    Write-ScriptLog -Message $Message -Level $Level -ScriptName $ScriptName -LogFileName "apply-taskbar-layout.log" -NoConsoleOutput:$Quiet
}

Write-Log "タスクバー レイアウト適用処理を開始します"

try {
    # ワークフローのルートディレクトリを動的検出
    $workflowRoot = Get-WorkflowRoot

    # ルート検証
    if (-not $workflowRoot -or -not (Test-Path $workflowRoot)) {
        throw "ワークフローのルートディレクトリが見つかりません。PSScriptRoot: $PSScriptRoot"
    }

    # XML ソースのパス解決（引数優先、未指定時は config 既定パス）
    if ($XmlPath) {
        if (-not (Test-Path -LiteralPath $XmlPath)) {
            throw "指定された XML パスが見つかりません: $XmlPath"
        }
        $xmlSourcePath = (Resolve-Path -LiteralPath $XmlPath).Path
        Write-Log "XML ソースパス（引数）: $xmlSourcePath"
    }
    else {
        $xmlSourcePath = Get-WorkflowPath -PathType "Config" -SubPath "TaskbarLayoutModification.XML"
        Write-Log "XML ソースパス（既定）: $xmlSourcePath"
        if (-not (Test-Path $xmlSourcePath)) {
            throw "TaskbarLayoutModification.XML が見つかりません: $xmlSourcePath"
        }
    }

    # 配置先パス（現ユーザー）
    $userShellDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Shell"
    $destXmlPath  = Join-Path $userShellDir "LayoutModification.xml"
    Write-Log "ユーザー Shell ディレクトリ: $userShellDir"
    Write-Log "配置先 XML パス: $destXmlPath"

    if ($DryRun) {
        Write-Log "[DryRun] ディレクトリ作成予定: $userShellDir"
        Write-Log "[DryRun] コピー予定: $xmlSourcePath -> $destXmlPath"
    }
    else {
        # ディレクトリ作成
        if (-not (Test-Path $userShellDir)) {
            New-Item -ItemType Directory -Path $userShellDir -Force | Out-Null
            Write-Log "ディレクトリを作成しました: $userShellDir"
        }

        # XML コピー
        Copy-Item -Path $xmlSourcePath -Destination $destXmlPath -Force:$Force
        Write-Log "XML を配置しました"
    }

    # レジストリ初期化（現在ユーザー）
    $regKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore"
    )

    foreach ($key in $regKeys) {
        if ($DryRun) {
            Write-Log "[DryRun] レジストリ削除予定: $key"
            continue
        }

        try {
            if (Test-Path $key) {
                Remove-Item -Path $key -Recurse -Force:$Force -ErrorAction SilentlyContinue
                Write-Log "レジストリを削除しました: $key"
            }
            else {
                Write-Log "レジストリキーが存在しません: $key" -Level "WARN"
            }
        }
        catch {
            Write-Log "レジストリ削除に失敗しました: $key - $($_.Exception.Message)" -Level "ERROR"
        }
    }

    # Explorer 再起動
    if ($DryRun) {
        Write-Log "[DryRun] Explorer 再起動予定 (停止→1秒待機→起動)"
    }
    else {
        try {
            Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            Start-Process explorer.exe
            Write-Log "Explorer を再起動しました"
        }
        catch {
            Write-Log "Explorer 再起動に失敗しました: $($_.Exception.Message)" -Level "ERROR"
        }
    }

    # 完了ステータスファイルの作成
    $statusDir = Get-WorkflowPath -PathType "Status"
    if (-not (Test-Path $statusDir)) {
        New-Item -ItemType Directory -Path $statusDir -Force | Out-Null
    }

    $statusFile = Get-CompletionMarkerPath -TaskName "apply-taskbar-layout"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($DryRun) {
        Write-Log "[DryRun] ステータスファイル作成予定: $statusFile"
    }
    else {
        Set-Content -Path $statusFile -Value "Completed at $timestamp" -Encoding UTF8
        Write-Log "ステータスファイルを作成しました: $statusFile"
    }

    Write-Log "タスクバー レイアウト適用処理が完了しました"
}
catch {
    Write-Log "タスクバー レイアウト適用処理中にエラーが発生しました: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "エラー詳細: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
