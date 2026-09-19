[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Open in pending visual review mode')]
    [Alias('r', 'DOR', 'DoReview')]
    [switch]$ReviewMode,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by repository or subsystem')]
    [Alias('Scope')]
    [string]$Repo,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by plan state (bug, suggested, approved, completed, etc.)')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = 'Render HTML data cache without launching desktop browser')]
    [switch]$NoLaunch,

    [Parameter(Mandatory = $false, HelpMessage = 'Open in CRP Lifecycle Dates modal mode')]
    [Alias('Dates', 'CrpDates')]
    [switch]$DatesMode,

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Launches the LCM Configuration Management Control Hub browser dashboard on your interactive desktop.
.DESCRIPTION
    Module: tools/Show-CmControlHub.ps1
    Purpose: Renders and launches the interactive CM Control Hub single-page web application,
             binding real-time proposal data, dual-state management, batch Beyond Compare review,
             Notepad++ specification editing, and historical log views.
    Path: tools/Show-CmControlHub.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.3.1
    Date: 2026-09-19
.PARAMETER ReviewMode
    Opens the Control Hub filtered directly to pending visual reviews requiring Beyond Compare action.
.PARAMETER Repo
    Pre-selects a specific repository or subsystem filter on launch.
.PARAMETER State
    Pre-selects a plan state filter (e.g. bug, suggested, approved, completed, deferred).
.PARAMETER Help
    Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
    pwsh tools/Show-CmControlHub.ps1
.EXAMPLE
    pwsh tools/Show-CmControlHub.ps1 -ReviewMode
.EXAMPLE
    pwsh tools/Show-CmControlHub.ps1 -Repo Workspace_AI -State bug
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------------------
# 0. PowerShell 7 (pwsh) Runtime Enforcement Guard (BUG-126)
# ------------------------------------------------------------------------------
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $boundArgs = @()
        foreach ($k in $PSBoundParameters.Keys) {
            $val = $PSBoundParameters[$k]
            if ($val -is [switch] -or $val -is [bool]) {
                if ($val) { $boundArgs += "-$k" }
            } else {
                $boundArgs += "-$k"
                $boundArgs += "$val"
            }
        }
        $proc = Start-Process -FilePath "pwsh.exe" -ArgumentList (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") + $boundArgs) -Wait -PassThru -NoNewWindow
        exit $proc.ExitCode
    }
}

$scriptVersion = "1.3.1"
$scriptName = "Show-CmControlHub"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM CONFIGURATION MANAGEMENT CONTROL HUB LAUNCHER (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Renders and launches the interactive CM Control Hub single-page web dashboard"
    Write-Host "  on your interactive desktop with live dual-state and batch review dispatch."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Show-CmControlHub.ps1 [-ReviewMode] [-Repo <repo>] [-State <state>] [-h]"
    Write-Host ""
    Write-Host "ALIASES & SHORT-NAMES:" -ForegroundColor Yellow
    Write-Host "  CmHub.cmd      : Opens the full Control Hub in browser"
    Write-Host "  DOR.cmd        : Opens in Review Mode (Pending Beyond Compare Reviews)"
    Write-Host "  DoReview.cmd   : Alias for DOR.cmd"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$proposalsFile = Join-Path $workspaceRoot "Workspace_Inventory\data\proposals\proposals.json"
$activeLogFile = Join-Path $workspaceRoot "Workspace_Inventory\logs\cm_activity.log"
$historyLogFile = Join-Path $workspaceRoot "Workspace_Inventory\logs\history\cm_activity_v5_v6_history.log"
$htmlTemplateFile = Join-Path $workspaceRoot "Workspace_Inventory\assets\CM_CONTROL_HUB.html"
if (-not (Test-Path -LiteralPath $htmlTemplateFile)) {
    $htmlTemplateFile = Join-Path $workspaceRoot "Workspace_Inventory\docs\CM_CONTROL_HUB.html"
}

if (-not (Test-Path -LiteralPath $proposalsFile)) {
    throw "Proposals ledger not found at: $proposalsFile"
}
if (-not (Test-Path -LiteralPath $htmlTemplateFile)) {
    throw "CM Control Hub HTML template not found at: $htmlTemplateFile"
}

# ------------------------------------------------------------------------------
# 1. Load Real-Time Data & Render Dynamic Dashboard
# ------------------------------------------------------------------------------
$proposalsRaw = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8
$activeLogRaw = if (Test-Path -LiteralPath $activeLogFile) { Get-Content -LiteralPath $activeLogFile -Raw -Encoding UTF8 } else { "" }
$historyLogRaw = if (Test-Path -LiteralPath $historyLogFile) { Get-Content -LiteralPath $historyLogFile -Raw -Encoding UTF8 } else { "" }

# Pre-load full documents into cache dictionary for instant offline zero-CORS browser viewing
$docsCache = @{}

# Load Plans & Walkthroughs
$planFiles = @(Get-ChildItem -Path (Join-Path $workspaceRoot "Workspace_Inventory\data\proposals\plans") -Filter "*.md" -File -ErrorAction SilentlyContinue)
foreach ($f in $planFiles) {
    $rel = "Workspace_Inventory/data/proposals/plans/$($f.Name)"
    $docsCache[$rel] = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
}

# Load CRP Specifications
$crpFiles = @(Get-ChildItem -Path (Join-Path $workspaceRoot "Workspace_Inventory\docs\Proposals") -Filter "*.md" -File -ErrorAction SilentlyContinue)
foreach ($f in $crpFiles) {
    $rel = "Workspace_Inventory/docs/Proposals/$($f.Name)"
    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $docsCache[$rel] = $content
    if ($f.Name -match '^((?:CRP|BUG)-(?:\d{4}-)?\d{3,})') {
        $docsCache[$Matches[1]] = $content
        $docsCache[$f.Name] = $content
    }
}

# Load Review Receipts
$receiptFiles = @(Get-ChildItem -Path (Join-Path $workspaceRoot "Workspace_Inventory\data\reviews") -Filter "*.json" -File -ErrorAction SilentlyContinue)
foreach ($f in $receiptFiles) {
    $rel = "Workspace_Inventory/data/reviews/$($f.Name)"
    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    $docsCache[$rel] = $content
    $docsCache[$f.Name] = $content
    if ($f.Name -match '^review_([^_]+)_') {
        $docsCache["receipt_" + $Matches[1]] = $content
    }
}

# Load Repo Documentation
$governedRepos = @("Workspace_Inventory", ".lcm", "Installation_LCD", "Workspace_AI", "SystemConfiguration", "BackgroundModifier", "VolumeInventory", "HaSSD06", "HaSSD06_Inventory", "AuthorizeMasterUser", "SharedModules", "Git_Repositories")
$docNames = @("Architecture.md", "Requirements.md", "Implementation.md", "install/Installation.md", "Installation.md", "README.md", "docs/Architecture.md", "docs/Requirements.md", "docs/Implementation.md", "docs/CM_POLICIES.md")

foreach ($r in $governedRepos) {
    $repoDir = if ($r -eq "Git_Repositories") { $workspaceRoot } else { Join-Path $workspaceRoot $r }
    if (Test-Path -LiteralPath $repoDir) {
        foreach ($d in $docNames) {
            $fullDoc = Join-Path $repoDir $d.Replace('/', '\')
            if (Test-Path -LiteralPath $fullDoc) {
                $key = "$r/$d"
                $docsCache[$key] = Get-Content -LiteralPath $fullDoc -Raw -Encoding UTF8
            }
        }
        if ($r -eq "Workspace_Inventory") {
            $wiTools = @("tools/Show-CmControlHub.ps1", "tools/Invoke-BeyondCompareReview.ps1", "tools/Invoke-WorkspacePush.ps1", "tools/Invoke-ProposalAction.ps1", "tools/Submit-ReviewResult.ps1", "modules/ProposalManager.psm1")
            foreach ($wt in $wiTools) {
                $fullTool = Join-Path $repoDir $wt.Replace('/', '\')
                if (Test-Path -LiteralPath $fullTool) {
                    $docsCache["$r/$wt"] = Get-Content -LiteralPath $fullTool -Raw -Encoding UTF8
                }
            }
        }
    }
}

# ------------------------------------------------------------------------------
# 2. Compile-Time Document & Tool Metadata Pre-Compilation (BUG-127)
# ------------------------------------------------------------------------------
function Get-CompiledDocMetadata {
    param(
        [string]$Name,
        [string]$Content
    )

    $role = "Specification"
    $version = "v1.0.0"
    $date = (Get-Date).ToString("yyyy-MM-dd")
    $reviewState = "ACCEPTED"

    $lower = $Name.ToLowerInvariant()
    if ($lower -like "*architecture*") { $role = "Architecture" }
    elseif ($lower -like "*requirements*") { $role = "Requirements" }
    elseif ($lower -like "*implementation*") { $role = "Implementation" }
    elseif ($lower -like "*installation*") { $role = "Runbook" }
    elseif ($lower -like "*readme*") { $role = "Overview" }
    elseif ($lower -like "*crp*" -or $lower -like "*proposal*" -or $lower -like "*bug*") { $role = "Proposal" }
    elseif ($lower -like "*policy*" -or $lower -like "*policies*" -or $lower -like "*rules*") { $role = "Policy" }
    elseif ($lower.EndsWith(".ps1") -or $lower.EndsWith(".cmd") -or $lower.EndsWith(".bat")) { $role = "Tool" }
    elseif ($lower.EndsWith(".psm1") -or $lower.EndsWith(".psd1")) { $role = "Module" }

    if ($Content) {
        # Priority 1: Script runtime version variable ($scriptVersion or $VERSION)
        if ($Content -match '(?m)^\s*\$(?:scriptVersion|VERSION|ScriptVersion)\s*=\s*["'']([^"'']+)["'']') {
            $v = $Matches[1].Trim()
            $version = if ($v.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) { $v } else { "v$v" }
        }
        # Priority 2: Header comment Version
        elseif ($Content -match '(?i)(?:Version|Ver)\s*:\s*(v?[0-9.]+)') {
            $v = $Matches[1].Trim()
            $version = if ($v.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) { $v } else { "v$v" }
        }

        if ($Content -match '(?i)(?:Date|Last Modified|Timestamp)\s*:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})') {
            $date = $Matches[1]
        }
        if ($Content -match '(?i)Status\s*:\s*([A-Za-z0-9_-]+)') {
            $reviewState = $Matches[1].ToUpperInvariant()
        }
    }

    return [ordered]@{
        name        = $Name
        role        = $role
        version     = $version
        date        = $date
        reviewState = $reviewState
    }
}

$compiledCatalog = [ordered]@{}
foreach ($k in $docsCache.Keys) {
    $leafName = Split-Path $k -Leaf
    $itemContent = $docsCache[$k]
    $meta = Get-CompiledDocMetadata -Name $leafName -Content $itemContent
    $entry = [ordered]@{
        name        = $meta.name
        key         = $k
        role        = $meta.role
        version     = $meta.version
        date        = $meta.date
        reviewState = $meta.reviewState
    }
    $compiledCatalog[$k] = $entry
    if (-not $compiledCatalog.Contains($leafName)) {
        $compiledCatalog[$leafName] = $entry
    }
}

# Resolve active LCM baseline
$lcmBaseline = "v7.4.2"
$sessionFile = Join-Path $workspaceRoot ".agents\ACTIVE_SESSION.md"
if (Test-Path -LiteralPath $sessionFile) {
    $sessContent = Get-Content -LiteralPath $sessionFile -Raw
    if ($sessContent -match '(?i)LCM Version\s*:\s*(v?[0-9.]+)') {
        $lcmBaseline = $Matches[1]
        if (-not $lcmBaseline.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) { $lcmBaseline = "v$lcmBaseline" }
    }
}

$compiledTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$hubVersionSubtitle = "Tool: Show-CmControlHub v$scriptVersion | LCM Baseline: $lcmBaseline | Compiled: $compiledTimestamp"

# Resolve and load LcmTablePrintAtom engine
$atomJsCandidates = @(
    (Join-Path $workspaceRoot '.lcm\assets\lcm-table-print-atom.js'),
    (Join-Path $workspaceRoot 'tools\assets\lcm-table-print-atom.js')
)
$atomJsPath = $null
foreach ($cand in $atomJsCandidates) {
    if (Test-Path -LiteralPath $cand) {
        $atomJsPath = $cand
        break
    }
}
$atomJsContent = if ($atomJsPath) { Get-Content -LiteralPath $atomJsPath -Raw -Encoding UTF8 } else { "" }

$injectedBlock = @"
    const RAW_PROPOSALS = $proposalsRaw;
    const RAW_ACTIVE_LOG = $($activeLogRaw | ConvertTo-Json);
    const RAW_HISTORY_LOG = $($historyLogRaw | ConvertTo-Json);
    const RAW_DOCS_CACHE = $($docsCache | ConvertTo-Json -Depth 3);
    const RAW_COMPILED_CATALOG = $($compiledCatalog | ConvertTo-Json -Depth 3);
"@

$htmlContent = Get-Content -LiteralPath $htmlTemplateFile -Raw -Encoding UTF8
$htmlContent = $htmlContent.Replace('/*__INJECTED_ATOM_PLACEHOLDER__*/', $atomJsContent)
$htmlContent = $htmlContent.Replace('/*__INJECTED_DATA_PLACEHOLDER__*/', $injectedBlock)

# Static Token Substitutions (BUG-127)
$htmlContent = $htmlContent.Replace('{{HUB_TITLE}}', "LCM Configuration Management Control Hub v$scriptVersion")
$htmlContent = $htmlContent.Replace('{{HUB_VERSION}}', "v$scriptVersion")
$htmlContent = $htmlContent.Replace('{{HUB_VERSION_SUBTITLE}}', $hubVersionSubtitle)
$htmlContent = $htmlContent.Replace('{{LCM_BASELINE}}', $lcmBaseline)

$scratchDir = Join-Path $workspaceRoot "Workspace_Inventory\scratch"
if (-not (Test-Path -LiteralPath $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}
$artifactsDir = Join-Path $workspaceRoot "Workspace_Inventory\data\artifacts"
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}

$renderedHtmlPath = Join-Path $artifactsDir "CM_CONTROL_HUB.html"
Set-Content -LiteralPath $renderedHtmlPath -Value $htmlContent -Encoding UTF8
Set-Content -LiteralPath (Join-Path $scratchDir "CM_CONTROL_HUB.html") -Value $htmlContent -Encoding UTF8

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM CONFIGURATION MANAGEMENT CONTROL HUB" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dashboard: $renderedHtmlPath"
Write-Host " Ledger   : $proposalsFile"

# ------------------------------------------------------------------------------
# 2. Dispatch to Session 1 Interactive Desktop
# ------------------------------------------------------------------------------
if (-not $NoLaunch) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    $fileUri = [System.Uri]::new($renderedHtmlPath).AbsoluteUri
    $launchTarget = if ($DatesMode) { "$fileUri#dates" } else { $fileUri }
    $dispatcher = Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"
    if (Test-Path -LiteralPath $dispatcher) {
        & $dispatcher -FilePath $launchTarget
    } else {
        Start-Process -FilePath $launchTarget
    }
} else {
    Write-Host " Dashboard rendered cleanly (browser launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
    Write-Host "==========================================================================" -ForegroundColor Cyan
}
