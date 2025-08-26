# ============================================================================
# ワークフロー共通ヘルパー関数
# WorkflowRootパス取得とその他の共通ユーティリティ
# ============================================================================

# WorkflowRootパスを取得する関数
function Get-WorkflowRoot {
    param(
        [string]$StartPath = $PSScriptRoot
    )

    # キャッシュされた値を確認
    if ($Global:WorkflowRootCache) {
        return $Global:WorkflowRootCache
    }

    # 開始パスがスクリプトファイルの場合は親ディレクトリを取得
    if ($StartPath -like "*.ps1") {
        $StartPath = Split-Path $StartPath -Parent
    }

    $workflowRoot = $StartPath

    # scripts/setup/ や scripts/ フォルダから開始する場合は適切に親を取得
    if ($workflowRoot -like "*\scripts\setup") {
        $workflowRoot = Split-Path (Split-Path $workflowRoot -Parent) -Parent
    } elseif ($workflowRoot -like "*\scripts") {
        $workflowRoot = Split-Path $workflowRoot -Parent
    } elseif ($workflowRoot -like "*\tests") {
        $workflowRoot = Split-Path $workflowRoot -Parent
    }

    # MainWorkflow.ps1が見つかるまで上位ディレクトリを検索
    $maxDepth = 10  # 無限ループ防止
    $currentDepth = 0

    while ($workflowRoot -and $currentDepth -lt $maxDepth) {
        if (Test-Path (Join-Path $workflowRoot "MainWorkflow.ps1")) {
            # WorkflowRootが見つかったのでキャッシュして返す
            $Global:WorkflowRootCache = $workflowRoot
            return $workflowRoot
        }

        $parent = Split-Path $workflowRoot -Parent
        if ($parent -eq $workflowRoot) {
            # ルートディレクトリに到達した場合は開始パスを返す
            break
        }

        $workflowRoot = $parent
        $currentDepth++
    }

    # MainWorkflow.ps1が見つからない場合は開始パスを返す
    Write-Warning "MainWorkflow.ps1が見つかりませんでした。開始パス '$StartPath' を使用します。"
    $Global:WorkflowRootCache = $StartPath
    return $StartPath
}

# WorkflowRootのキャッシュをクリアする関数（テスト用）
function Clear-WorkflowRootCache {
    $Global:WorkflowRootCache = $null
}

# よく使用されるパスを取得するヘルパー関数
function Get-WorkflowPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Config", "Scripts", "Logs", "Status", "Tests", "Backup")]
        [string]$PathType,

        [string]$SubPath = ""
    )

    $workflowRoot = Get-WorkflowRoot

    $basePaths = @{
        "Config"  = "config"
        "Scripts" = "scripts"
        "Logs"    = "logs"
        "Status"  = "status"
        "Tests"   = "tests"
        "Backup"  = "backup"
    }

    $fullPath = Join-Path $workflowRoot $basePaths[$PathType]

    if ($SubPath) {
        $fullPath = Join-Path $fullPath $SubPath
    }

    return $fullPath
}

# 設定ファイルを読み込むヘルパー関数
function Get-WorkflowConfig {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("workflow", "notifications", "applications", "autologin")]
        [string]$ConfigType
    )

    $configPath = Get-WorkflowPath -PathType "Config" -SubPath "$ConfigType.json"

    if (-not (Test-Path $configPath)) {
        throw "設定ファイルが見つかりません: $configPath"
    }

    try {
        $configContent = Get-Content $configPath -Raw -Encoding UTF8
        return $configContent | ConvertFrom-Json
    }
    catch {
        throw "設定ファイルの読み込みに失敗しました: $configPath - $($_.Exception.Message)"
    }
}

# 完了マーカーファイルのパスを取得する関数
function Get-CompletionMarkerPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )

    return Get-WorkflowPath -PathType "Status" -SubPath "${TaskName}.completed"
}

# パステンプレートのプレースホルダを展開する関数
# 使用可能なトークン:
#  - {id} / {stepId}           : ステップID
#  - {timestamp}               : yyyyMMdd-HHmmssfff 形式の現在時刻
#  - {param:Name}              : ステップ引数 (parameters.Name) の値
function Expand-PathPlaceholders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Template,

        [Parameter(Mandatory = $true)]
        [object]$Step
    )

    $result = $Template

    # ステップID
    if ($Step -and $Step.id) {
        $result = $result -replace '\{id\}', [Regex]::Escape($Step.id).Replace('\\', '\\')
        $result = $result -replace '\{stepId\}', [Regex]::Escape($Step.id).Replace('\\', '\\')
    }

    # タイムスタンプ
    $timestamp = (Get-Date -Format 'yyyyMMdd-HHmmssfff')
    $result = $result -replace '\{timestamp\}', $timestamp

    # parameters の展開 {param:Name}
    $result = [regex]::Replace($result, '\{param:([^}]+)\}', {
        param($m)
        $paramName = $m.Groups[1].Value
        try {
            if ($Step -and $Step.parameters -and $Step.parameters.PSObject.Properties[$paramName]) {
                return [string]$Step.parameters.$paramName
            }
            else {
                return ''
            }
        }
        catch {
            return ''
        }
    })

    return $result
}

# 完了詳細情報を書き出すユーティリティ
function Write-CompletionDetail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StepId,

        [Parameter(Mandatory = $true)]
        [object]$Data
    )

    $detailsDir = Get-WorkflowPath -PathType "Status" -SubPath "details"
    if (-not (Test-Path $detailsDir)) {
        New-Item -ItemType Directory -Path $detailsDir -Force | Out-Null
    }

    $detailsPath = Join-Path $detailsDir ("{0}.json" -f $StepId)
    $Data | ConvertTo-Json -Depth 5 | Out-File -FilePath $detailsPath -Encoding UTF8
    return $detailsPath
}
