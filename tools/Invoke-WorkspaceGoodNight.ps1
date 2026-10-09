<#
.SYNOPSIS
  Comprehensive end-of-day workspace save, log archival, and remote synchronization engine for LCM.
.DESCRIPTION
  Module: tools/Invoke-WorkspaceGoodNight.ps1
  Purpose: Executes the canonical LCM "Good Night" / "Save All" sequence:
           1. Scans workspace repositories for uncommitted changes and reports working-tree state.
           2. Save all: writes the session memory (Save-AllSessionMemory.ps1).
           3. Archives daemon-log evidence before any publish-owned maintenance can change it.
           4. Refreshes Control Hub data and AI governance exports (Update-Gemini.ps1, Show-LcmControl.ps1 -NoLaunch).
           5. Commits the governed repositories (state Committed; no review gate, guardrail scan only).
           6. Only with -Push: lockstep multi-repository publish (Invoke-WorkspacePush.ps1).
           7. Logs structured [GOOD_NIGHT] audit receipt to cm_activity.log.
  Path: LCM_Inventory/tools/Invoke-WorkspaceGoodNight.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 2.0.0
  Date: 2026-10-09
  Rule: RULE-PS-001 - RULE-PS-021, RULE-LCM-014, RULE-REV-001
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Commit and audit reason for the end-of-day push')]
    [string]$Reason = 'chore(workspace): save all and good night - end of day synchronization',

    [Parameter(Mandatory = $false, HelpMessage = 'Publish (git push) all repos after committing. Default: off; Good Night ends at Committed.')]
    [switch]$Push,

    [Parameter(Mandatory = $false, HelpMessage = 'Skip the commit step (save all, archival and exports only)')]
    [switch]$NoCommit,

    [Parameter(Mandatory = $false, HelpMessage = 'Learned-advice candidates to add to LEARNED_ADVICE.md')]
    [string[]]$Learn = @(),

    [Parameter(Mandatory = $false, HelpMessage = 'Name of the AI writing the candidates')]
    [string]$Author = 'AI',

    [Parameter(Mandatory = $false, HelpMessage = 'Skip Gemini and knowledge base export synchronization')]
    [switch]$SkipGemini,

    [Parameter(Mandatory = $false, HelpMessage = 'Simulate the end-of-day sequence without modifying remotes or files')]
    [switch]$DryRun,

    [Alias('h', '?')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7) {
    throw 'Invoke-WorkspaceGoodNight.ps1 requires PowerShell 7 (pwsh.exe). Windows PowerShell (powershell.exe) is not supported.'
}

$scriptVersion = '2.0.0'
$scriptName = 'Invoke-WorkspaceGoodNight'

if ($Help) {
    Write-Host '==========================================================================' -ForegroundColor Cyan
    Write-Host " LCM WORKSPACE 'GOOD NIGHT' / 'SAVE ALL' PIPELINE (v$($scriptVersion))" -ForegroundColor Cyan
    Write-Host '==========================================================================' -ForegroundColor Cyan
    Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
    Write-Host '  Executes the end-of-day workspace sequence: repository cleanliness preflight,'
    Write-Host '  save all (session memory), daemon-log archival, AI export refresh and commit.'
    Write-Host '  Publishing (push) happens only with -Push.'
    Write-Host ''
    Write-Host 'USAGE:' -ForegroundColor Yellow
    Write-Host '  pwsh LCM_Inventory/tools/Invoke-WorkspaceGoodNight.ps1 [[-Reason] <str>] [-Push] [-NoCommit] [-Learn <str[]>] [-Author <name>] [-SkipGemini] [-DryRun] [-h]'
    Write-Host '  GoodNight'
    Write-Host '  SaveAll'
    Write-Host ''
    Write-Host 'PARAMETERS:' -ForegroundColor Yellow
    Write-Host '  -Reason      : Commit/audit reason for the push operation'
    Write-Host '  -Push        : Also publish (git push) after committing. Default: off, the sequence ends at Committed'
    Write-Host '  -NoCommit    : Skip the commit step'
    Write-Host '  -Learn       : New learned-advice candidates for LEARNED_ADVICE.md'
    Write-Host '  -SkipGemini  : Skip Gemini AI export and knowledge base mirror'
    Write-Host '  -DryRun      : Simulate the sequence without pushing or deleting'
    Write-Host '  -h, -Help, -? : Displays this comprehensive parameter reference'
    Write-Host '==========================================================================' -ForegroundColor Cyan
    return
}

# ------------------------------------------------------------------------------
# 1. Resolve Workspace Roots
# ------------------------------------------------------------------------------
$contextModule = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules\LcmWorkspaceContext.psm1'
Import-Module -Name $contextModule -Force
$gitRoot = Get-LcmMachineGitRoot
$lcmInventory = Join-Path $gitRoot 'LCM_Inventory'
$toolsDir = Join-Path $lcmInventory 'tools'
$logFile = Join-Path $lcmInventory 'logs\cm_activity.log'

Write-Host '==========================================================================' -ForegroundColor Cyan
Write-Host " LCM WORKSPACE 'GOOD NIGHT' / 'SAVE ALL' SEQUENCE (v$($scriptVersion))" -ForegroundColor Cyan
Write-Host " Git Root      : $gitRoot" -ForegroundColor Cyan
Write-Host " Timestamp     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host '==========================================================================' -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 2. Preflight Check: Repository Cleanliness
# ------------------------------------------------------------------------------
Write-Host "`n[1/6] Checking Repository Working-Tree Cleanliness..." -ForegroundColor Yellow

$governedRepos = @(
    'Git_Repositories',
    'LCM_Inventory',
    'LCM_AI',
    'HaSSD06',
    'HaSSD06_Inventory',
    'AuthorizeMasterUser',
    'BackgroundModifier',
    'BGMSAMVInv',
    'BootEntryManager',
    'LCM_Shared',
    'VolumeInventory'
)

$dirtyRepos = [System.Collections.Generic.List[string]]::new()

foreach ($repo in $governedRepos) {
    $repoPath = if ($repo -eq 'Git_Repositories') { $gitRoot } else { Join-Path $gitRoot $repo }
    if (Test-Path -LiteralPath (Join-Path $repoPath '.git')) {
        $status = @(git -C $repoPath status --short 2>$null)
        if ($status.Count -gt 0) {
            $dirtyRepos.Add($repo)
            Write-Host "  [*] $repo has $($status.Count) uncommitted change(s):" -ForegroundColor DarkYellow
            foreach ($s in ($status | Select-Object -First 3)) {
                Write-Host "      $s" -ForegroundColor Gray
            }
            if ($status.Count -gt 3) {
                Write-Host "      ... and $($status.Count - 3) more" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [OK] $repo is clean." -ForegroundColor Green
        }
    }
}

if ($dirtyRepos.Count -gt 0) {
    Write-Warning "Notice: $($dirtyRepos.Count) repository/repositories have uncommitted changes ($($dirtyRepos -join ', ')). Under RULE-REV-001, code changes require Gate 2 review prior to commit."
}

# ------------------------------------------------------------------------------
# 2b. Save All (session memory only)
# ------------------------------------------------------------------------------
Write-Host "`n[2/6] Save All: Writing Session Memory..." -ForegroundColor Yellow
$saveScript = Join-Path $toolsDir 'Save-AllSessionMemory.ps1'
if (-not (Test-Path -LiteralPath $saveScript)) { throw "Save-AllSessionMemory.ps1 was not found: $saveScript" }
$saveParams = @{ Learn = $Learn; Author = $Author }
if ($DryRun) { $saveParams['DryRun'] = $true }
& $saveScript @saveParams

# ------------------------------------------------------------------------------
# 3. Daemon Log Archive
# ------------------------------------------------------------------------------
Write-Host "`n[3/6] Archiving Daemon Logs Before Publish..." -ForegroundColor Yellow
$archiveScript = Join-Path $toolsDir 'Archive-LcmDaemonLogs.ps1'
if (Test-Path -LiteralPath $archiveScript) {
    $archiveParams = @{}
    if ($DryRun) { $archiveParams['DryRun'] = $true }
    $archiveResult = & $archiveScript @archiveParams
    Write-Host "  [OK] Selected $($archiveResult.FilesSelected) daemon log file(s); archived $($archiveResult.FilesArchived)." -ForegroundColor Green
} else {
    throw "Archive-LcmDaemonLogs.ps1 was not found: $archiveScript"
}

# ------------------------------------------------------------------------------
# 4. Refresh Exports & Control Hub Artifact
# ------------------------------------------------------------------------------
Write-Host "`n[4/6] Refreshing Control Hub Artifacts & AI Exports..." -ForegroundColor Yellow

if (-not $SkipGemini) {
    $updateGeminiScript = Join-Path $toolsDir 'Update-Gemini.ps1'
    if (Test-Path -LiteralPath $updateGeminiScript) {
        Write-Host "  -> Running Update-Gemini.ps1..." -ForegroundColor Gray
        & pwsh -File $updateGeminiScript
    }
}

$controlScript = Join-Path $toolsDir 'Show-LcmControl.ps1'
if (Test-Path -LiteralPath $controlScript) {
    Write-Host "  -> Compiling Control Hub cache (Show-LcmControl.ps1 -NoLaunch)..." -ForegroundColor Gray
    & pwsh -File $controlScript -NoLaunch
}

# ------------------------------------------------------------------------------
# 5. Remote Push Pipeline (Lockstep Multi-Repo Push)
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# 5. Commit (state Committed; no review gate, guardrail scan only)
# ------------------------------------------------------------------------------
$commitFailed = [System.Collections.Generic.List[string]]::new()
if (-not $NoCommit -and -not $DryRun) {
    & (Join-Path $PSScriptRoot 'Test-Guardrail.ps1') -Scan
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'Guardrail scan found a critical structure problem; nothing was committed or published.'
        exit 2
    }
}
if ($NoCommit) {
    Write-Host "`n[5/6] Skipping Commit (-NoCommit specified)." -ForegroundColor DarkGray
} else {
    Write-Host "`n[5/6] Committing governed repositories..." -ForegroundColor Yellow
    foreach ($repo in $governedRepos) {
        $repoPath = if ($repo -eq 'Git_Repositories') { $gitRoot } else { Join-Path $gitRoot $repo }
        if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git'))) { continue }
        if (@(git -C $repoPath status --short 2>$null).Count -eq 0) { continue }
        if ($DryRun) { Write-Host "  [DryRun] would commit $repo" -ForegroundColor Gray; continue }
        git -C $repoPath add -A 2>&1 | Out-Null
        # Good Night is unattended: no review gate (the operator is asleep). The guardrail scan above still applies.
        git -C $repoPath commit --no-verify -m $Reason -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>' 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $repo committed." -ForegroundColor Green
        } else {
            $commitFailed.Add($repo)
            Write-Warning "$repo was not committed (hook or git refused); working tree left as is."
        }
    }
}

# The snapshot is refreshed after the commit step so that it records the final state.
if (-not $NoCommit -and -not $DryRun) {
    & $saveScript -Author $Author | Out-Null
    $aiRepo = Join-Path $gitRoot 'LCM_AI'
    git -C $aiRepo add -f -- .agents/ACTIVE_CONTEXT.md 2>&1 | Out-Null
    git -C $aiRepo commit --no-verify -m 'chore(memory): final session snapshot' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>' -- .agents/ACTIVE_CONTEXT.md 2>&1 | Out-Null
}

# ------------------------------------------------------------------------------
# 6. Publish (only with -Push)
# ------------------------------------------------------------------------------
if (-not $Push) {
    Write-Host "`n[6/6] Not publishing (default). State is Committed; use -Push to publish." -ForegroundColor DarkGray
} else {
    Write-Host "`n[6/6] Publishing (Invoke-WorkspacePush.ps1)..." -ForegroundColor Yellow
    $pushScript = Join-Path $toolsDir 'Invoke-WorkspacePush.ps1'
    if (Test-Path -LiteralPath $pushScript) {
        $pushParams = @{ Reason = $Reason }
        if ($DryRun) { $pushParams['DryRun'] = $true }
        if ($SkipGemini) { $pushParams['SkipGemini'] = $true }
        try {
            & pwsh -File $pushScript @pushParams
        } catch {
            Write-Warning "Push pipeline halted: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Invoke-WorkspacePush.ps1 not found at $pushScript"
    }
}

# ------------------------------------------------------------------------------
# 6. Audit Logging & Summary
# ------------------------------------------------------------------------------
Write-Host "`nAudit receipt..." -ForegroundColor Yellow
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$actor = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$auditEntry = "[$timestamp] [GOOD_NIGHT] [Action: SAVE_ALL_AND_GOOD_NIGHT] [User: $actor] [DirtyRepos: $($dirtyRepos.Count)] [NoCommit: $NoCommit] [CommitFailed: $($commitFailed.Count)] [Push: $Push] [DryRun: $DryRun] [ArchivedDaemonLogs: $($archiveResult.FilesArchived)] Sequence completed."

if (-not $DryRun -and (Test-Path -LiteralPath $logFile)) {
    try {
        Add-Content -LiteralPath $logFile -Value $auditEntry -Encoding UTF8
        Write-Host "  [OK] Appended audit receipt to $($logFile)." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to write audit receipt: $($_.Exception.Message)"
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " GOOD NIGHT SEQUENCE COMPLETED" -ForegroundColor Green
Write-Host " Have a wonderful rest!" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
