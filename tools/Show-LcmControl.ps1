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

    [Parameter(Mandatory = $false, HelpMessage = 'Display verbose execution timing telemetry milestones')]
    [Alias('Timer', 'Timing', 'timer-ON')]
    [switch]$TimerOn,

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
    Authors: Rolf, LCM_AI Engine
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
.PARAMETER TimerOn
    Display verbose execution timing milestones (Aliases: -Timer, -Timing, -timer-ON). Defaults to false.
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

$script:stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
function Write-TimingLog {
    param([string]$Message)
    if ($TimerOn) {
        Write-Host "  [+$($script:stopwatch.ElapsedMilliseconds)ms] $Message" -ForegroundColor DarkGray
    }
}

$proposalsFile = Join-Path $workspaceRoot "LCM_Inventory\data\proposals\proposals.json"
$activeLogFile = Join-Path $workspaceRoot "LCM_Inventory\logs\cm_activity.log"
$historyLogFile = Join-Path $workspaceRoot "LCM_Inventory\logs\history\cm_activity_v5_v6_history.log"
$htmlTemplateFile = Join-Path $workspaceRoot "LCM_Inventory\assets\CM_CONTROL_HUB.html"
if (-not (Test-Path -LiteralPath $htmlTemplateFile)) {
    $htmlTemplateFile = Join-Path $workspaceRoot "LCM_Inventory\docs\CM_CONTROL_HUB.html"
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
        $d = if ($p.PSObject.Properties['dates']) { $p.dates } else { $null }
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
                $crpTag = if ($p.crp_id) { $p.crp_id } else { $p.cr_id }
                Write-Host "Proposal #$($p.id) ($crpTag) - $($p.title)" -ForegroundColor Green
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

Write-TimingLog "Loading proposals ledger and activity logs..."
$proposalsRaw = Get-Content -LiteralPath $proposalsFile -Raw -Encoding UTF8
$activeLogRaw = if (Test-Path -LiteralPath $activeLogFile) { Get-Content -LiteralPath $activeLogFile -Raw -Encoding UTF8 } else { "" }
$historyLogRaw = if (Test-Path -LiteralPath $historyLogFile) { Get-Content -LiteralPath $historyLogFile -Raw -Encoding UTF8 } else { "" }

# Gather tripartite and module documentation for in-browser review
Write-TimingLog "Gathering repository tripartite docs..."
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
Write-TimingLog "Gathering proposal markdown documents..."
$propDocsDir = Join-Path $workspaceRoot "LCM_Inventory\docs\Proposals"
if (Test-Path -LiteralPath $propDocsDir) {
    $propFiles = Get-ChildItem -LiteralPath $propDocsDir -Filter "*.md" -Recurse
    foreach ($pf in $propFiles) {
        $rel = "LCM_Inventory/docs/Proposals/" + $pf.Name
        $docsCache[$rel] = Get-Content -LiteralPath $pf.FullName -Raw -Encoding UTF8
    }
}
Write-TimingLog "Gathered $($docsCache.Count) total documents into cache."

# Compile Document Metadata Catalog
function Get-CompiledDocMetadata {
    param([string]$Name, [string]$Content)
    $role = "Specification"
    $version = "v1.0.0"
    $date = (Get-Date).ToString("yyyy-MM-dd")
    $reviewState = "COMPLETED"

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
$appsCatalogFile = Join-Path $workspaceRoot "LCM_Inventory\data\catalog\apps.json"
$appsCatalogRaw = if (Test-Path -LiteralPath $appsCatalogFile) { Get-Content -LiteralPath $appsCatalogFile -Raw -Encoding UTF8 } else { '{"total_apps":0,"apps":[]}' }

Write-TimingLog "Serializing documents and compiling JSON injection blocks..."
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

$scratchDir = Join-Path $workspaceRoot "LCM_Inventory\scratch"
if (-not (Test-Path -LiteralPath $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}
$artifactsDir = Join-Path $workspaceRoot "LCM_Inventory\data\artifacts"
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}

$renderedHtmlPath = Join-Path $artifactsDir "CM_CONTROL_HUB.html"
Write-TimingLog "Writing CM_CONTROL_HUB.html to disk..."
Set-Content -LiteralPath $renderedHtmlPath -Value $htmlContent -Encoding UTF8
Set-Content -LiteralPath (Join-Path $scratchDir "CM_CONTROL_HUB.html") -Value $htmlContent -Encoding UTF8
Write-TimingLog "CM_CONTROL_HUB.html written ($([Math]::Round($htmlContent.Length / 1KB, 1)) KB)."

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
        Write-TimingLog "Compiling companion LCM Sidecar..."
        & $sidecarScript -NoLaunch
        Write-TimingLog "Companion LCM Sidecar compiled."
    }

    $hubUri = [System.Uri]::new($renderedHtmlPath).AbsoluteUri
    $launchTarget = if ($DatesMode) { "$hubUri#dates" } else { $hubUri }
    $sidecarPath = Join-Path $artifactsDir "LCM_SIDECAR.html"
    $sidecarUri = [System.Uri]::new($sidecarPath).AbsoluteUri

    # --------------------------------------------------------------------------
    # Dynamic User Default Browser Discovery (Windows Registry UserChoice)
    # --------------------------------------------------------------------------
    $browserPath = $null
    $browserName = "unknown"
    try {
        $progId = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" -ErrorAction Stop).ProgId
        $cmd = (Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\$progId\shell\open\command" -ErrorAction Stop).'(Default)'
        if ($cmd -match '"([^"]+\.exe)"') { $browserPath = $Matches[1] }
        elseif ($cmd -match '^\s*([^\s]+\.exe)') { $browserPath = $Matches[1] }
        if ($browserPath) {
            $browserName = [System.IO.Path]::GetFileNameWithoutExtension($browserPath).ToLowerInvariant()
        }
    } catch {}

    # Secondary fallback to known paths if registry query produced nothing
    if (-not $browserPath -or -not (Test-Path -LiteralPath $browserPath)) {
        $zenPath = "D:\Tools\Zen Browser\zen.exe"
        if (Test-Path -LiteralPath $zenPath) {
            $browserPath = $zenPath
            $browserName = "zen"
        } else {
            $firefoxCandidates = @(
                "C:\Program Files\Mozilla Firefox\firefox.exe",
                "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
            )
            foreach ($cand in $firefoxCandidates) {
                if (Test-Path -LiteralPath $cand) { $browserPath = $cand; $browserName = "firefox"; break }
            }
        }
    }

    $dispatcher = Join-Path $workspaceRoot ".lcm\tools\internal\Invoke-InteractiveDesktop.ps1"
    Write-TimingLog "Browser detected: $browserName ($browserPath). Dispatching windows..."
    if ($browserPath -and (Test-Path -LiteralPath $browserPath)) {
        if ($browserName -in @('zen', 'firefox')) {
            # ------------------------------------------------------------------
            # Zen Browser / Firefox: Dedicated window with Hub + Sidecar tabs
            # ------------------------------------------------------------------
            Write-Host "  -> Launching LCM Control Hub & Sidecar as two tabs in a dedicated $browserName window..." -ForegroundColor Green
            if (Test-Path -LiteralPath $dispatcher) {
                Write-TimingLog "Dispatching Tab 1: $launchTarget..."
                & $dispatcher -FilePath $browserPath -ArgumentList "--new-window `"$launchTarget`""
                Write-TimingLog "Tab 1 dispatched. Pausing 350ms..."
                Start-Sleep -Milliseconds 350
                Write-TimingLog "Dispatching Tab 2: $sidecarUri..."
                & $dispatcher -FilePath $browserPath -ArgumentList "--new-tab `"$sidecarUri`""
                Write-TimingLog "Tab 2 dispatched."
            } else {
                Start-Process -FilePath $browserPath -ArgumentList "--new-window `"$launchTarget`""
                Start-Sleep -Milliseconds 350
                Start-Process -FilePath $browserPath -ArgumentList @("--new-tab", "`"$sidecarUri`"")
            }
        } elseif ($browserName -in @('msedge', 'chrome', 'brave')) {
            # ------------------------------------------------------------------
            # Chromium / Edge: Two windows stacked vertically (one above the other)
            # ------------------------------------------------------------------
            Write-Host "  -> Launching LCM Control Hub & Sidecar in vertically stacked $browserName windows (one above the other)..." -ForegroundColor Green
            
            # Top Window: Control Hub
            $topArgs = "--new-window `"$launchTarget`" --window-position=30,20 --window-size=1860,540"
            if (Test-Path -LiteralPath $dispatcher) {
                Write-TimingLog "Dispatching Window 1: Control Hub ($topArgs)..."
                & $dispatcher -FilePath $browserPath -ArgumentList $topArgs
                Write-TimingLog "Window 1 dispatched. Pausing 450ms..."
            } else {
                Start-Process -FilePath $browserPath -ArgumentList $topArgs
            }

            Start-Sleep -Milliseconds 450

            # Bottom Window: Sidecar
            $bottomArgs = "--new-window `"$sidecarUri`" --window-position=30,575 --window-size=1860,450"
            if (Test-Path -LiteralPath $dispatcher) {
                Write-TimingLog "Dispatching Window 2: Sidecar ($bottomArgs)..."
                & $dispatcher -FilePath $browserPath -ArgumentList $bottomArgs
                Write-TimingLog "Window 2 dispatched."
            } else {
                Start-Process -FilePath $browserPath -ArgumentList $bottomArgs
            }
        } else {
            # Generic browser dispatch: two sequential tab launches
            Write-Host "  -> Launching Hub & Sidecar via detected default browser ($browserName)..." -ForegroundColor Green
            if (Test-Path -LiteralPath $dispatcher) {
                Write-TimingLog "Dispatching Tab 1: $launchTarget..."
                & $dispatcher -FilePath $browserPath -ArgumentList "`"$launchTarget`""
                Write-TimingLog "Tab 1 dispatched. Pausing 300ms..."
                Start-Sleep -Milliseconds 300
                Write-TimingLog "Dispatching Tab 2: $sidecarUri..."
                & $dispatcher -FilePath $browserPath -ArgumentList "`"$sidecarUri`""
                Write-TimingLog "Tab 2 dispatched."
            } else {
                Start-Process -FilePath $browserPath -ArgumentList "`"$launchTarget`""
                Start-Sleep -Milliseconds 300
                Start-Process -FilePath $browserPath -ArgumentList "`"$sidecarUri`""
            }
        }
    } else {
        Write-Host "  -> Dispatching Control Hub & Sidecar tabs via default browser handler..." -ForegroundColor Cyan
        if (Test-Path -LiteralPath $dispatcher) {
            Write-TimingLog "Dispatching Target 1: $launchTarget..."
            & $dispatcher -FilePath $launchTarget
            Write-TimingLog "Target 1 dispatched. Pausing 250ms..."
            Start-Sleep -Milliseconds 250
            Write-TimingLog "Dispatching Target 2: $sidecarUri..."
            & $dispatcher -FilePath $sidecarUri
            Write-TimingLog "Target 2 dispatched."
        } else {
            Start-Process -FilePath $launchTarget
            Start-Sleep -Milliseconds 250
            Start-Process -FilePath $sidecarUri
        }
    }
    Write-TimingLog "All dispatches completed. Total execution time: $($script:stopwatch.ElapsedMilliseconds)ms"
} else {
    Write-TimingLog "Browser launch suppressed via -NoLaunch. Total execution time: $($script:stopwatch.ElapsedMilliseconds)ms"
    Write-Host " Dashboard rendered cleanly (browser launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
    Write-Host "==========================================================================" -ForegroundColor Cyan
}
