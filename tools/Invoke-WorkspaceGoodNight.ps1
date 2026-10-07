<#
.SYNOPSIS
  Comprehensive end-of-day workspace save, log archival, and remote synchronization engine for LCM.
.DESCRIPTION
  Module: tools/Invoke-WorkspaceGoodNight.ps1
  Purpose: Executes the canonical LCM "Good Night" / "Save All" sequence:
           1. Scans workspace repositories for uncommitted changes and reports working-tree state.
           2. Archives daemon-log evidence before any publish-owned maintenance can change it.
           3. Refreshes Control Hub data and AI governance exports (Update-Gemini.ps1, Show-LcmControl.ps1 -NoLaunch).
           4. Performs lockstep multi-repository push to remote tracking branches (Invoke-WorkspacePush.ps1).
           5. Logs structured [GOOD_NIGHT] audit receipt to cm_activity.log.
  Path: LCM_Inventory/tools/Invoke-WorkspaceGoodNight.ps1
  Authors: Rolf, LCM_AI Engine
  Version: 1.0.0
  Date: 2026-10-07
  Rule: RULE-PS-001 - RULE-PS-021, RULE-LCM-014, RULE-REV-001
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Commit and audit reason for the end-of-day push')]
    [string]$Reason = 'chore(workspace): save all and good night - end of day synchronization',

    [Parameter(Mandatory = $false, HelpMessage = 'Skip remote git push (local save, log archival, and exports only)')]
    [switch]$NoPush,

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

$scriptVersion = '1.0.0'
$scriptName = 'Invoke-WorkspaceGoodNight'

if ($Help) {
    Write-Host '==========================================================================' -ForegroundColor Cyan
    Write-Host " LCM WORKSPACE 'GOOD NIGHT' / 'SAVE ALL' PIPELINE (v$($scriptVersion))" -ForegroundColor Cyan
    Write-Host '==========================================================================' -ForegroundColor Cyan
    Write-Host 'SYNOPSIS:' -ForegroundColor Yellow
    Write-Host '  Executes the end-of-day workspace sequence: repository cleanliness preflight,'
    Write-Host '  daemon-log archival, AI export refresh, and multi-repo remote push.'
    Write-Host ''
    Write-Host 'USAGE:' -ForegroundColor Yellow
    Write-Host '  pwsh LCM_Inventory/tools/Invoke-WorkspaceGoodNight.ps1 [[-Reason] <str>] [-NoPush] [-SkipGemini] [-DryRun] [-h]'
    Write-Host '  GoodNight'
    Write-Host '  SaveAll'
    Write-Host ''
    Write-Host 'PARAMETERS:' -ForegroundColor Yellow
    Write-Host '  -Reason      : Commit/audit reason for the push operation'
    Write-Host '  -NoPush      : Skip git push (local save, log archival, and exports only)'
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
Write-Host "`n[1/5] Checking Repository Working-Tree Cleanliness..." -ForegroundColor Yellow

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
# 3. Daemon Log Archive
# ------------------------------------------------------------------------------
Write-Host "`n[2/5] Archiving Daemon Logs Before Publish..." -ForegroundColor Yellow
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
Write-Host "`n[3/5] Refreshing Control Hub Artifacts & AI Exports..." -ForegroundColor Yellow

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
if ($NoPush) {
    Write-Host "`n[4/5] Skipping Remote Git Push (-NoPush switch specified)." -ForegroundColor DarkGray
} else {
    Write-Host "`n[4/5] Executing Multi-Repository Push (Invoke-WorkspacePush.ps1)..." -ForegroundColor Yellow
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
Write-Host "`n[5/5] Recording Audit Receipt..." -ForegroundColor Yellow
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$actor = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$auditEntry = "[$timestamp] [GOOD_NIGHT] [Action: SAVE_ALL_AND_GOOD_NIGHT] [User: $actor] [DirtyRepos: $($dirtyRepos.Count)] [NoPush: $NoPush] [DryRun: $DryRun] [ArchivedDaemonLogs: $($archiveResult.FilesArchived)] Sequence completed."

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
