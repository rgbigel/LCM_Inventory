[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Open in pending visual review mode')]
    [Alias('r', 'DOR', 'DoReview')]
    [switch]$ReviewMode,

    [Parameter(Mandatory = $false, HelpMessage = 'Open in CRP Lifecycle Dates modal mode')]
    [Alias('Dates', 'CrpDates')]
    [switch]$DatesMode,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by repository or subsystem')]
    [Alias('Scope')]
    [string]$Repo,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by plan state (bug, suggested, approved, completed, deferred, etc.)')]
    [string]$State,

    [Parameter(Mandatory = $false, HelpMessage = 'Optional array of Proposal IDs to filter (e.g. 1, 28, 44, 164)')]
    [object[]]$Id,

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by state change event presence (created, in_progress, completed, pushed, deferred)')]
    [string]$StateEvent,

    [Parameter(Mandatory = $false, HelpMessage = 'Output proposal dates table directly to terminal without launching desktop browser')]
    [Alias('Cli', 'Text', 'NoBrowser')]
    [switch]$CliMode,

    [Parameter(Mandatory = $false, HelpMessage = 'Displays detailed individual state transition timeline in terminal CLI mode')]
    [switch]$Detail,

    [Parameter(Mandatory = $false, HelpMessage = 'Render HTML data cache without launching desktop browser')]
    [switch]$NoLaunch,

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Unified LCM Configuration Management Control Hub & Proposal Lifecycle Manager.
.DESCRIPTION
    Module: tools/Show-LcmControl.ps1
    Purpose: Renders and launches the interactive CM Control Hub single-page web dashboard
             and provides direct terminal/CLI proposal lifecycle date querying.
             Absorbs and consolidates Show-CmControlHub and Show-CrpDates into a single canonical tool.
    Path: tools/Show-LcmControl.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 1.4.0
    Date: 2026-09-25
.PARAMETER ReviewMode
    Opens the Control Hub filtered directly to pending visual reviews requiring Beyond Compare action.
.PARAMETER DatesMode
    Opens the Control Hub focused directly on the CRP Lifecycle Dates & Transition Timeline modal.
.PARAMETER Repo
    Pre-selects a specific repository or subsystem filter on launch.
.PARAMETER State
    Pre-selects a plan state filter (e.g. bug, suggested, approved, completed, deferred).
.PARAMETER Id
    Optional array of Proposal IDs to filter in CLI or browser mode.
.PARAMETER StateEvent
    Filter by presence of milestone date (created, in_progress, completed, pushed, deferred).
.PARAMETER CliMode
    Outputs the formatted proposal lifecycle dates table to the terminal without opening a browser.
.PARAMETER Detail
    Displays detailed individual state transition timeline and user notes in CLI mode.
.PARAMETER NoLaunch
    Renders HTML artifacts without launching the desktop browser.
.PARAMETER Help
    Displays this parameter reference (Aliases: -h, -?).
.EXAMPLE
    pwsh tools/Show-LcmControl.ps1
.EXAMPLE
    pwsh tools/Show-LcmControl.ps1 -ReviewMode
.EXAMPLE
    pwsh tools/Show-LcmControl.ps1 -Dates
.EXAMPLE
    pwsh tools/Show-LcmControl.ps1 -Cli -Detail
.EXAMPLE
    pwsh tools/Show-LcmControl.ps1 -Id 164
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

$scriptVersion = "1.4.0"
$scriptName = "Show-LcmControl"

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " UNIFIED LCM CONTROL HUB & LIFECYCLE MANAGER (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Renders and launches the interactive CM Control Hub single-page web dashboard"
    Write-Host "  and provides command-line proposal lifecycle dates querying."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Show-LcmControl.ps1 [-Dates] [-ReviewMode] [-Repo <repo>] [-State <state>] [-Cli] [-h]"
    Write-Host ""
    Write-Host "MODES:" -ForegroundColor Yellow
    Write-Host "  (default)          : Opens full CM Control Hub on interactive desktop"
    Write-Host "  -Dates / -DatesMode: Opens Control Hub with CRP Dates modal active"
    Write-Host "  -ReviewMode        : Opens Control Hub filtered to pending Beyond Compare reviews"
    Write-Host "  -Cli / -NoBrowser  : Outputs proposal dates table directly to terminal"
    Write-Host ""
    Write-Host "ALIASES & SHORT-NAMES:" -ForegroundColor Yellow
    Write-Host "  ShowLcmControl.cmd : Canonical launcher"
    Write-Host "  ShowCMControlHub   : Compatibility alias"
    Write-Host "  ShowCrpDates       : Compatibility alias"
    Write-Host "  CmHub.cmd / DOR.cmd: Quick desktop dispatchers"
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

# ------------------------------------------------------------------------------
# 1. CLI Terminal Mode (Absorbs Show-CrpDates CLI engine)
# ------------------------------------------------------------------------------
if ($CliMode) {
    function Get-ObjProperty {
        param($Object, [string]$PropName, $Default = "-")
        if ($null -eq $Object) { return $Default }
        $prop = $Object.PSObject.Properties[$PropName]
        if ($null -ne $prop -and $null -ne $prop.Value -and $prop.Value -ne '') {
            return [string]$prop.Value
        }
        return $Default
    }

    $rawJson = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $list = @($rawJson.proposals)

    if ($Id) {
        $idSet = [System.Collections.Generic.HashSet[int]]::new()
        foreach ($item in $Id) {
            if ($item -match '^\d+$') {
                $null = $idSet.Add([int]$item)
            } elseif ($item -match '(?:crp|bug)-?(\d+)') {
                $null = $idSet.Add([int]$Matches[1])
            }
        }
        $list = @($list | Where-Object { $idSet.Contains([int]$_.id) })
    }

    if ($State) {
        $sNorm = $State.ToLower()
        $list = @($list | Where-Object {
            ((Get-ObjProperty $_ 'state').ToLower() -eq $sNorm) -or
            ((Get-ObjProperty $_ 'progress_state').ToLower() -eq $sNorm)
        })
    }

    if ($StateEvent) {
        $eNorm = $StateEvent.ToLower()
        $list = @($list | Where-Object {
            $dates = $_.dates
            if ($null -eq $dates) { return $false }
            $hasDate = (Get-ObjProperty $dates $eNorm) -ne '-'
            if (-not $hasDate -and $eNorm -eq 'created') { $hasDate = [bool]$_.timestamp }
            if (-not $hasDate -and $eNorm -eq 'pushed') { $hasDate = [bool]$_.pushed_at }
            return $hasDate
        })
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM PROPOSAL & CRP LIFECYCLE DATES LEDGER" -ForegroundColor Cyan
    Write-Host " Found $($list.Count) proposal(s) matching filter criteria." -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Cyan

    $rows = foreach ($p in $list) {
        $d = $p.dates
        $created = if ($d) { Get-ObjProperty $d 'created' (Get-ObjProperty $p 'timestamp') } else { Get-ObjProperty $p 'timestamp' }
        $inProg  = if ($d) { Get-ObjProperty $d 'in_progress' } else { '-' }
        $comp    = if ($d) { Get-ObjProperty $d 'completed' } else { '-' }
        $pushed  = if ($d) { Get-ObjProperty $d 'pushed' (Get-ObjProperty $p 'pushed_at') } else { Get-ObjProperty $p 'pushed_at' }

        [PSCustomObject]@{
            ID          = $p.id
            Tag         = Get-ObjProperty $p 'crp_id' (Get-ObjProperty $p 'cr_id')
            Scope       = Get-ObjProperty $p 'origin_repo' 'LCM'
            State       = (Get-ObjProperty $p 'state').ToUpper()
            Status      = (Get-ObjProperty $p 'progress_state' 'undecided').ToUpper()
            Created     = $created
            InProgress  = $inProg
            Completed   = $comp
            Pushed      = $pushed
            Title       = $p.title
        }
    }

    $rows | Sort-Object ID -Descending | Format-Table -Property ID, Tag, Scope, State, Status, Created, InProgress, Completed, Pushed, Title -AutoSize

    if ($Detail) {
        Write-Host ""
        Write-Host "=== DETAILED STATE TRANSITION TIMELINES ===" -ForegroundColor Cyan
        foreach ($p in $list) {
            $history = $p.state_history
            if ($history -and $history.Count -gt 0) {
                Write-Host ""
                Write-Host "Proposal #$($p.id) ($($p.crp_id || $p.cr_id)) - $($p.title)" -ForegroundColor Green
                foreach ($h in $history) {
                    $ts = Get-ObjProperty $h 'timestamp'
                    $st = (Get-ObjProperty $h 'state').ToUpper()
                    $usr = Get-ObjProperty $h 'user' 'User'
                    $note = Get-ObjProperty $h 'note' ''
                    Write-Host "  [$ts] $st by $usr $(if ($note) { '- ' + $note })" -ForegroundColor DarkGray
                }
            }
        }
    }
    return
}

# ------------------------------------------------------------------------------
# 2. GUI Control Hub Dashboard Compilation
# ------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $htmlTemplateFile)) {
    throw "CM Control Hub HTML template not found at: $htmlTemplateFile"
}

$proposalsRaw = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8
$activeLogRaw = if (Test-Path -LiteralPath $activeLogFile) { Get-Content -LiteralPath $activeLogFile -Raw -Encoding UTF8 } else { "" }
$historyLogRaw = if (Test-Path -LiteralPath $historyLogFile) { Get-Content -LiteralPath $historyLogFile -Raw -Encoding UTF8 } else { "" }

# Gather tripartite and module documentation for in-browser review
$docsCache = [ordered]@{}
$repoDirs = Get-ChildItem -LiteralPath $workspaceRoot -Directory | Where-Object { -not ($_.Name.StartsWith(".") -or $_.Name -in @("tools", "scratch", "data", "logs")) }

foreach ($r in $repoDirs) {
    $rName = $r.Name
    $docCandidates = @(
        (Join-Path $r.FullName "Architecture.md"),
        (Join-Path $r.FullName "Requirements.md"),
        (Join-Path $r.FullName "Implementation.md"),
        (Join-Path $r.FullName "install\Installation.md"),
        (Join-Path $r.FullName "README.md"),
        (Join-Path $r.FullName "docs\Architecture.md"),
        (Join-Path $r.FullName "docs\Requirements.md"),
        (Join-Path $r.FullName "docs\Implementation.md"),
        (Join-Path $r.FullName "docs\CM_POLICIES.md")
    )
    foreach ($cand in $docCandidates) {
        if (Test-Path -LiteralPath $cand) {
            $rel = "$rName/" + (Split-Path $cand -Leaf)
            if ($cand -like "*\install\*") { $rel = "$rName/install/Installation.md" }
            elseif ($cand -like "*\docs\*") { $rel = "$rName/docs/" + (Split-Path $cand -Leaf) }
            $docsCache[$rel] = Get-Content -LiteralPath $cand -Raw -Encoding UTF8
        }
    }
}

# Gather Proposal Markdown documents
$propDocsDir = Join-Path $workspaceRoot "Workspace_Inventory\docs\Proposals"
if (Test-Path -LiteralPath $propDocsDir) {
    $propFiles = Get-ChildItem -LiteralPath $propDocsDir -Filter "*.md" -Recurse
    foreach ($pf in $propFiles) {
        $rel = "Workspace_Inventory/docs/Proposals/" + $pf.Name
        $docsCache[$rel] = Get-Content -LiteralPath $pf.FullName -Raw -Encoding UTF8
    }
}

# Compile Document Metadata Catalog
function Get-CompiledDocMetadata {
    param([string]$Name, [string]$Content)
    $role = "Specification"
    $version = "v1.0.0"
    $date = (Get-Date).ToString("yyyy-MM-dd")
    $reviewState = "ACCEPTED"

    if ($Content -match '(?ms)<---\s*DOX\s*(.*?)\s*--->') {
        $metaBlock = $Matches[1]
        if ($metaBlock -match '(?i)Role\s*:\s*([^\r\n]+)') { $role = $Matches[1].Trim() }
        if ($metaBlock -match '(?i)Version\s*:\s*([^\r\n]+)') { $version = $Matches[1].Trim() }
        if ($metaBlock -match '(?i)Date\s*:\s*([^\r\n]+)') { $date = $Matches[1].Trim() }
        if ($metaBlock -match '(?i)ReviewStatus\s*:\s*([^\r\n]+)') { $reviewState = $Matches[1].Trim().ToUpper() }
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
$lcmBaseline = "v7.5.2"
$sessionFile = Join-Path $workspaceRoot ".agents\ACTIVE_SESSION.md"
if (Test-Path -LiteralPath $sessionFile) {
    $sessContent = Get-Content -LiteralPath $sessionFile -Raw
    if ($sessContent -match '(?i)LCM Version\s*:\s*(v?[0-9.]+)') {
        $lcmBaseline = $Matches[1]
        if (-not $lcmBaseline.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) { $lcmBaseline = "v$lcmBaseline" }
    }
}

$compiledTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$hubVersionSubtitle = "Tool: Show-LcmControl v$scriptVersion | LCM Baseline: $lcmBaseline | Compiled: $compiledTimestamp"

# Load Table Atom engine if present
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
$appsCatalogFile = Join-Path $workspaceRoot "Workspace_Inventory\data\catalog\apps.json"
$appsCatalogRaw = if (Test-Path -LiteralPath $appsCatalogFile) { Get-Content -LiteralPath $appsCatalogFile -Raw -Encoding UTF8 } else { '{"total_apps":0,"apps":[]}' }

$injectedBlock = @"
    const RAW_PROPOSALS = $proposalsRaw;
    const RAW_APPS_CATALOG = $appsCatalogRaw;
    const RAW_ACTIVE_LOG = $($activeLogRaw | ConvertTo-Json);
    const RAW_HISTORY_LOG = $($historyLogRaw | ConvertTo-Json);
    const RAW_DOCS_CACHE = $($docsCache | ConvertTo-Json -Depth 3);
    const RAW_COMPILED_CATALOG = $($compiledCatalog | ConvertTo-Json -Depth 3);
"@

$htmlContent = Get-Content -LiteralPath $htmlTemplateFile -Raw -Encoding UTF8
$htmlContent = $htmlContent.Replace('/*__INJECTED_ATOM_PLACEHOLDER__*/', $atomJsContent)
$htmlContent = $htmlContent.Replace('/*__INJECTED_DATA_PLACEHOLDER__*/', $injectedBlock)

# Static Token Substitutions
$htmlContent = $htmlContent.Replace('{{HUB_TITLE}}', "LCM Control Hub v$scriptVersion")
$htmlContent = $htmlContent.Replace('{{HUB_VERSION}}', "v$scriptVersion")
$htmlContent = $htmlContent.Replace('{{HUB_VERSION_SUBTITLE}}', $hubVersionSubtitle)
$htmlContent = $htmlContent.Replace('{{LCM_BASELINE}}', $lcmBaseline)
$htmlContent = $htmlContent.Replace('{{COMPILE_DATE}}', $compiledTimestamp)

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
Write-Host " UNIFIED LCM CONTROL HUB COMPILED" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dashboard : $renderedHtmlPath"
Write-Host " Ledger    : $proposalsFile"

# ------------------------------------------------------------------------------
# 3. Dual App Window Dispatch to Session 1 Interactive Desktop
# ------------------------------------------------------------------------------
if (-not $NoLaunch) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    
    # 1. Compile companion LCM Sidecar dashboard
    $sidecarScript = Join-Path $PSScriptRoot "Show-LcmSidecar.ps1"
    if (Test-Path -LiteralPath $sidecarScript) {
        & $sidecarScript -NoLaunch
    }

    $hubUri = [System.Uri]::new($renderedHtmlPath).AbsoluteUri
    $launchTarget = if ($DatesMode) { "$hubUri#dates" } else { $hubUri }
    $sidecarPath = Join-Path $artifactsDir "LCM_SIDECAR.html"
    $sidecarUri = [System.Uri]::new($sidecarPath).AbsoluteUri

    $edgeCandidates = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    )
    $edgePath = $null
    foreach ($cand in $edgeCandidates) {
        if (Test-Path -LiteralPath $cand) { $edgePath = $cand; break }
    }

    $dispatcher = Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"

    if ($edgePath) {
        Write-Host "  -> Launching LCM Control Hub & Sidecar in dual standalone App Windows..." -ForegroundColor Green
        
        # Window 1: LCM Control Hub (Left side, wide)
        $hubArgs = "--app=`"$launchTarget`" --window-size=1260,980 --window-position=30,30"
        if (Test-Path -LiteralPath $dispatcher) {
            & $dispatcher -FilePath $edgePath -ArgumentList $hubArgs
        } else {
            Start-Process -FilePath $edgePath -ArgumentList $hubArgs
        }

        Start-Sleep -Milliseconds 450

        # Window 2: LCM Sidecar (Right side, narrow companion)
        $sidecarArgs = "--app=`"$sidecarUri`" --window-size=560,980 --window-position=1310,30"
        if (Test-Path -LiteralPath $dispatcher) {
            & $dispatcher -FilePath $edgePath -ArgumentList $sidecarArgs
        } else {
            Start-Process -FilePath $edgePath -ArgumentList $sidecarArgs
        }
    } else {
        Write-Host "  -> Dispatching via Interactive Desktop..." -ForegroundColor Cyan
        if (Test-Path -LiteralPath $dispatcher) {
            & $dispatcher -FilePath $launchTarget
            Start-Sleep -Milliseconds 300
            & $dispatcher -FilePath $sidecarUri
        } else {
            Start-Process -FilePath $launchTarget
            Start-Sleep -Milliseconds 300
            Start-Process -FilePath $sidecarUri
        }
    }
} else {
    Write-Host " Dashboard rendered cleanly (browser launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
    Write-Host "==========================================================================" -ForegroundColor Cyan
}
