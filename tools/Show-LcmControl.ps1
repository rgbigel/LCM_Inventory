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

    [Parameter(Mandatory = $false, HelpMessage = 'Filter by authoritative lifecycle state (suggested, in_progress, verified, in_review, completed, pushed, held, withdrawn, rejected, superseded)')]
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

    [Parameter(Mandatory = $false, HelpMessage = 'Open the lifecycle ledger in terminal detail mode')]
    [switch]$Lifecycle,

    [Parameter(Mandatory = $false, HelpMessage = 'Render HTML data cache without launching desktop browser')]
    [switch]$NoLaunch,

    [Parameter(Mandatory = $false, HelpMessage = 'Opens the Control Hub inside an Antigravity IDE editor/side pane')]
    [switch]$Pane,

    [Parameter(Mandatory = $false, HelpMessage = 'Compatibility switch; interactive launches automatically recover the desktop daemon when it is offline')]
    [switch]$StartDaemon,

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
    Version: 10.0.1
    Date: 2026-11-08 15:07:36
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
    Renders HTML artifacts without opening a Standard Display.
.PARAMETER StartDaemon
    Compatibility switch. Interactive launches use the shared HTTP launcher,
    which performs bounded daemon recovery and never opens a local-file fallback.
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

Import-Module -Name (Join-Path $PSScriptRoot '..\modules\LcmDisplayVersion.psm1') -Force
$scriptVersion = Get-LcmDisplaySourceVersion -Path $PSCommandPath

# ------------------------------------------------------------------------------
# 0. Help Handler (-h / -Help / -?) per RULE-PS-010
# ------------------------------------------------------------------------------
if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " LCM CONTROL HUB - SAFE ACTIONS (v$scriptVersion)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Renders and launches the interactive CM Control Hub single-page web dashboard."
    Write-Host "  The dashboard displays authoritative proposal lifecycle state and routes"
    Write-Host "  lifecycle actions through Invoke-ProposalAction.ps1."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh tools/Show-LcmControl.ps1 [-Lifecycle] [-Dates] [-ReviewMode] [-Repo <repo>] [-State <state>] [-Id <CRP-ID>] [-Cli] [-StartDaemon] [-h]"
    Write-Host ""
    Write-Host "MODES:" -ForegroundColor Yellow
    Write-Host "  (default)          : Opens full CM Control Hub on interactive desktop"
    Write-Host "  -Dates / -DatesMode: Opens the read-only Dates Standard Display (/dates)"
    Write-Host "  -ReviewMode        : Opens Control Hub filtered to pending Beyond Compare reviews"
    Write-Host "  -Cli / -NoBrowser  : Outputs proposal dates table directly to terminal"
    Write-Host "  -Lifecycle         : Outputs authoritative lifecycle state and transition history in terminal"
    Write-Host "  Offline recovery   : Shared HTTP launcher attempts bounded daemon recovery; no local-file fallback"
    Write-Host ""
    Write-Host "ALIASES & SHORT-NAMES:" -ForegroundColor Yellow
    Write-Host "  ShowLcmControl.cmd : Canonical launcher"
    Write-Host "  ShowCMControlHub   : Compatibility alias"
    Write-Host "  ShowCrpDates       : Compatibility alias"
    Write-Host "  CmHub.cmd / DOR.cmd: Quick desktop dispatchers"
    Write-Host ""
    Write-Host "LIFECYCLE QUICK REFERENCE:" -ForegroundColor Yellow
    Write-Host "  Suggested -> In Progress -> Verified -> In Review -> Completed -> Pushed"
    Write-Host "  BCR accepts exact CRP/BUG, repository, or declared cohort scope; omitted scope previews a bounded cohort."
    Write-Host "  -Immediately is a temporary documented BUG-cohort quality-check deferral; it is not -Force."
    Write-Host "  Inspect: ShowCM -Lifecycle -Id <CRP-ID>"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

if ($Lifecycle) {
    $CliMode = $true
    $Detail = $true
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
if ($DatesMode) {
    $htmlTemplateFile = Join-Path $workspaceRoot "LCM_Inventory\assets\CM_CRP_DATES_READONLY.html"
}
if (-not (Test-Path -LiteralPath $htmlTemplateFile)) {
    $htmlTemplateFile = Join-Path $workspaceRoot ".github\extensions\lcm-control-hub\control-hub.html"
}
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
            (Get-ObjProperty $_ 'state').ToLower() -eq $sNorm
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
        $qualityDeferred = if ((Get-ObjProperty $p 'quality_checks_deferred' 'false').ToLowerInvariant() -eq 'true') { 'YES' } else { '-' }

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
            QualityDeferred = $qualityDeferred
            Title       = $p.title
        }
    }

    $rows | Sort-Object ID -Descending | Format-Table -Property ID, Tag, Scope, State, Status, QualityDeferred, Created, InProgress, Completed, Pushed, Title -AutoSize

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

# Gather Proposal Markdown documents across all workspace repositories
Write-TimingLog "Gathering proposal markdown documents..."
foreach ($r in $repoDirs) {
    $rDocsDir = Join-Path $r.FullName "docs\Proposals"
    if (Test-Path -LiteralPath $rDocsDir) {
        $propFiles = Get-ChildItem -LiteralPath $rDocsDir -Filter "*.md" -Recurse
        foreach ($pf in $propFiles) {
            $rel = $pf.FullName.Substring($workspaceRoot.Length).TrimStart('\').Replace('\', '/')
            $docsCache[$rel] = Get-Content -LiteralPath $pf.FullName -Raw -Encoding UTF8
        }
    }
}

$proposalPlansDir = Join-Path $workspaceRoot "LCM_Inventory\data\proposals\plans"
if (Test-Path -LiteralPath $proposalPlansDir) {
    $proposalPlanFiles = Get-ChildItem -LiteralPath $proposalPlansDir -Filter "*.md" -Recurse
    foreach ($proposalPlanFile in $proposalPlanFiles) {
        $relativePlanPath = $proposalPlanFile.FullName.Substring($workspaceRoot.Length).TrimStart('\').Replace('\', '/')
        $docsCache[$relativePlanPath] = Get-Content -LiteralPath $proposalPlanFile.FullName -Raw -Encoding UTF8
    }
}

$reviewReceipts = @()
$reviewReceiptsDir = Join-Path $workspaceRoot "LCM_Inventory\data\reviews"
if (Test-Path -LiteralPath $reviewReceiptsDir) {
    foreach ($reviewReceiptFile in Get-ChildItem -LiteralPath $reviewReceiptsDir -Filter "*.json" -File) {
        try {
            $reviewReceipts += [ordered]@{
                path    = $reviewReceiptFile.FullName.Substring($workspaceRoot.Length).TrimStart('\').Replace('\', '/')
                content = Get-Content -LiteralPath $reviewReceiptFile.FullName -Raw -Encoding UTF8
            }
        } catch {
            throw "Unable to read review receipt '$($reviewReceiptFile.FullName)': $($_.Exception.Message)"
        }
    }
}
Write-TimingLog "Gathered $($docsCache.Count) total documents into cache."

# Compile Document Metadata Catalog
function Get-CompiledDocMetadata {
    param([string]$Name, [string]$Content)
    $role = "Specification"
    $version = "10.0.0"
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
$lcmBaseline = "10.0.0"
$sessionFile = Join-Path $workspaceRoot ".agents\ACTIVE_SESSION.md"
if (Test-Path -LiteralPath $sessionFile) {
    $sessContent = Get-Content -LiteralPath $sessionFile -Raw
    if ($sessContent -match '(?i)LCM Version\s*:\s*(v?[0-9.]+)') {
        $lcmBaseline = $Matches[1]
        if (-not $lcmBaseline.StartsWith("v", [System.StringComparison]::OrdinalIgnoreCase)) { $lcmBaseline = "v$lcmBaseline" }
    }
}

$compiledTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$appsCatalogFile = Join-Path $workspaceRoot "LCM_Inventory\data\catalog\apps.json"
$appsCatalogRaw = if (Test-Path -LiteralPath $appsCatalogFile) { Get-Content -LiteralPath $appsCatalogFile -Raw -Encoding UTF8 } else { '{"total_apps":0,"apps":[]}' }

Write-TimingLog "Serializing documents and compiling JSON injection blocks..."
$displayPayload = [ordered]@{
    proposals      = $proposalsRaw | ConvertFrom-Json
    appsCatalog    = $appsCatalogRaw | ConvertFrom-Json
    activeLog      = $activeLogRaw
    historyLog     = $historyLogRaw
    docs           = $docsCache
    reviewReceipts = @($reviewReceipts)
    compiledCatalog = $compiledCatalog
} | ConvertTo-Json -Depth 16 -Compress
$displayPayload = $displayPayload.Replace('<', '\u003c')

$htmlContent = Get-Content -LiteralPath $htmlTemplateFile -Raw -Encoding UTF8
$htmlContent = $htmlContent.Replace('{"__lcm_unrendered_template__":true}', $displayPayload)
$htmlContent = $htmlContent.Replace('{"proposals":{"proposals":[]},"__lcm_unrendered_template__":true}', $displayPayload)
$displayId = if ($DatesMode) { 'dates' } else { 'hub' }
$htmlContent = $htmlContent.Replace('content="hub"', "content=`"$displayId`"")
$htmlContent = $htmlContent.Replace('href="../../assets/StandardTableDisplay.css"', 'href="/assets/StandardTableDisplay.css"')

# Dynamic Version Token Substitutions per RULE-DSP-016 (Dual Significance: Tool + Template)
$provenance = Get-LcmDisplayProvenance -ScriptPath $PSCommandPath -TemplatePath $htmlTemplateFile
$templateVersion = $provenance.TemplateVersion.TrimStart('v')
$dualVersion = $provenance.Label
$htmlContent = $htmlContent.Replace('v{{HUB_VERSION}}', $dualVersion)
$htmlContent = $htmlContent.Replace('{{HUB_VERSION}}', $dualVersion)
$htmlContent = $htmlContent.Replace('{{SHOW_VERSION}}', "v$scriptVersion")
$htmlContent = $htmlContent.Replace('{{TEMPLATE_VERSION}}', "v$templateVersion")
$htmlContent = $htmlContent.Replace('LCM Control Hub Developer Template - Render Required', "LCM Control Hub ($dualVersion)")
$htmlContent = $htmlContent.Replace('{{HUB_TITLE}}', "LCM Control Hub ($dualVersion)")
$htmlContent = $htmlContent.Replace('{{HUB_VERSION_SUBTITLE}}', "Constructed by Show-LcmControl v$scriptVersion | Template: v$templateVersion | Baseline: $lcmBaseline | Compiled: $compiledTimestamp")
$htmlContent = $htmlContent.Replace('{{LCM_BASELINE}}', $lcmBaseline)
$htmlContent = $htmlContent.Replace('{{COMPILE_DATE}}', $compiledTimestamp)

$unresolvedTemplateTokens = @([regex]::Matches($htmlContent, '\{\{(?:HUB_VERSION|SHOW_VERSION|TEMPLATE_VERSION|HUB_TITLE|HUB_VERSION_SUBTITLE|LCM_BASELINE|COMPILE_DATE)\}\}') | ForEach-Object { $_.Value } | Select-Object -Unique)
if ($unresolvedTemplateTokens.Count -gt 0) {
    throw ("Control Hub rendering failed: unresolved template token(s) remain in the generated artifact: {0}" -f ($unresolvedTemplateTokens -join ', '))
}

$artifactsDir = Join-Path $workspaceRoot "LCM_Inventory\data\artifacts"
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}

$renderedHtmlLeaf = if ($DatesMode) { "CM_CRP_DATES.html" } else { "CM_CONTROL_HUB.html" }
$renderedHtmlPath = Join-Path $artifactsDir $renderedHtmlLeaf
Write-TimingLog "Writing CM_CONTROL_HUB.html to disk..."
Set-Content -LiteralPath $renderedHtmlPath -Value $htmlContent -Encoding UTF8
Write-TimingLog "CM_CONTROL_HUB.html written ($([Math]::Round($htmlContent.Length / 1KB, 1)) KB)."

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " LCM CONTROL HUB - SAFE ACTIONS COMPILED" -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Dashboard : $renderedHtmlPath"
Write-Host " Ledger    : $proposalsFile"

# ------------------------------------------------------------------------------
# 3. Single Window Interactive Desktop Dispatch
# ------------------------------------------------------------------------------
if (-not $NoLaunch) {
    $standardDisplayModule = Join-Path $workspaceRoot 'LCM_Inventory\modules\LcmStandardDisplay.psm1'
    if (-not (Test-Path -LiteralPath $standardDisplayModule -PathType Leaf)) {
        throw "Standard Display launcher module is missing: $standardDisplayModule"
    }
    Import-Module -Name $standardDisplayModule -Force
    $displayId = if ($DatesMode) { 'dates' } else { 'hub' }
    $displayParameters = @{
        ReviewMode = [string]$ReviewMode.IsPresent
        Repo = $Repo
        State = $State
        Id = @($Id) -join ','
        StateEvent = $StateEvent
    }
    Open-LcmStandardDisplay -DisplayId $displayId -Pane:$Pane -Parameters $displayParameters
    Write-TimingLog "All dispatches completed. Total execution time: $($script:stopwatch.ElapsedMilliseconds)ms"
} else {
    Write-TimingLog "Browser launch suppressed via -NoLaunch. Total execution time: $($script:stopwatch.ElapsedMilliseconds)ms"
    Write-Host " Dashboard rendered cleanly (browser launch suppressed via -NoLaunch)." -ForegroundColor DarkGray
    Write-Host "==========================================================================" -ForegroundColor Cyan
}
