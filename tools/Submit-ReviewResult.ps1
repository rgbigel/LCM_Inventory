[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'Name or path of the repository')]
    [Alias('RepositoryName', 'Repo', 'Name')]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $false, HelpMessage = 'Review outcome disposition (Completed, Complete, Accepted, AcceptedAll, AcceptedStaged, AcceptedWithEdits, Rejected, Deferred)')]
    [ValidateSet("Completed", "Complete", "Accepted", "AcceptedAll", "AcceptedStaged", "AcceptedWithEdits", "Rejected", "Deferred", "ALL", "ACCEPT ALL", "COMPLETE ALL")]
    [string]$Result,

    [Parameter(Mandatory = $false, HelpMessage = 'Review notes, rationale, or instructions for the audit receipt')]
    [string]$Notes,

    [Parameter(Mandatory = $false, HelpMessage = 'Accept all changes including uncopied files without interactive confirmation')]
    [Alias('AcceptAll')]
    [switch]$All,

    [Parameter(Mandatory = $false, HelpMessage = 'Force review commit and bypass safety checks')]
    [switch]$Force,

    [Alias('h', '?')]
    [switch]$Help
)

<#
.SYNOPSIS
    Interactive review response recorder and staging execution engine for Beyond Compare 5 and LCM governance.
.DESCRIPTION
    Module: tools/Submit-ReviewResult.ps1
    Purpose: Consumes interactive review staging manifests, handles Delete/Rename directives, executes cleanups,
             prompts for uncopied file confirmations (bypassed with 'ACCEPT ALL' or -All), and performs review-gated commits per RULE-REV-001.
    Path: tools/Submit-ReviewResult.ps1
    Authors: Rolf, Workspace_AI Engine
    Version: 7.3.0
    Date: 2026-09-25
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " SUBMIT REVIEW RESULT (Submit-ReviewResult)" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "SYNOPSIS:" -ForegroundColor Yellow
    Write-Host "  Interactive review response recorder and staging engine for Beyond Compare 5."
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  pwsh Workspace_Inventory/tools/Submit-ReviewResult.ps1 [[-RepositoryPath] <str>] [-Result <str>] [-Notes <str>] [-All] [-Force] [-h]"
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor Yellow
    Write-Host "  -RepositoryPath  : Name or path of the repository"
    Write-Host "  -Result          : Review disposition (Accepted, AcceptedAll, AcceptedWithEdits, Rejected, Deferred)"
    Write-Host "  -Notes           : Review notes or rationale"
    Write-Host "  -All             : Accept all including uncopied files"
    Write-Host "  -Force           : Force commit"
    Write-Host "  -Help (-h, -?)   : Displays this help screen"
    Write-Host "==========================================================================" -ForegroundColor Cyan
    return
}

$workspaceRoot = 'D:\Git_Repositories'
if (-not (Test-Path -LiteralPath $workspaceRoot)) {
    $workspaceRoot = Split-Path $PSScriptRoot -Parent
}

$targetRepoPath = $null
if (-not [string]::IsNullOrWhiteSpace($RepositoryPath)) {
    $resolvedPath = $RepositoryPath.Trim('"', "'")
    if ($resolvedPath -in @('.', 'root', 'Git_Repositories', (Split-Path $workspaceRoot -Leaf))) {
        $targetRepoPath = $workspaceRoot
    } elseif (Test-Path -LiteralPath $resolvedPath) {
        $curr = $resolvedPath
        while ($curr -and $curr -ne (Split-Path $curr -Parent)) {
            if (Test-Path -LiteralPath (Join-Path $curr '.git')) {
                $targetRepoPath = $curr
                break
            }
            $curr = Split-Path $curr -Parent
        }
    }
    if (-not $targetRepoPath) {
        $candidatePath = Join-Path $workspaceRoot $resolvedPath
        if (Test-Path -LiteralPath $candidatePath) { $targetRepoPath = $candidatePath }
    }
} else {
    $targetRepoPath = $workspaceRoot
}

$repoName = Split-Path $targetRepoPath -Leaf
$reviewsDir = Join-Path $workspaceRoot "Workspace_Inventory\data\reviews"
if (-not (Test-Path -LiteralPath $reviewsDir)) { New-Item -ItemType Directory -Path $reviewsDir -Force | Out-Null }
$stagedManifestFile = Join-Path $reviewsDir "staged_review_${repoName}.json"

$stagedManifest = $null
if (Test-Path -LiteralPath $stagedManifestFile) {
    try {
        $stagedManifest = Get-Content -LiteralPath $stagedManifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {}
}

# ------------------------------------------------------------------------------
# Check for Uncopied Files and Prompt Operator (Bypassed if ACCEPT ALL / -All is used)
# ------------------------------------------------------------------------------
$includeUncopied = $false
$isExplicitAcceptAll = ($All -or $Result -in @("AcceptedAll", "ALL", "ACCEPT ALL"))

if ($stagedManifest -and $stagedManifest.Uncopied -and $stagedManifest.Uncopied.Count -gt 0) {
    if ($isExplicitAcceptAll) {
        $includeUncopied = $true
        $Result = "AcceptedAll"
        Write-Host "[ACCEPT ALL] Confirmed: Automatically including all $($stagedManifest.Uncopied.Count) uncopied/modified file(s) without prompt." -ForegroundColor Green
    } elseif ($Result -eq "AcceptedStaged") {
        $includeUncopied = $false
    } elseif (-not $Force -and ($null -eq $Result -or $Result -in @("Accepted", "AcceptedWithEdits"))) {
        Write-Host ""
        Write-Host "==========================================================================" -ForegroundColor Yellow
        Write-Host " NOTICE: UNCOPIED FILES DETECTED IN REVIEW" -ForegroundColor Yellow
        Write-Host "==========================================================================" -ForegroundColor Yellow
        Write-Host " You have $($stagedManifest.Uncopied.Count) modified/new file(s) that were NOT copied to the Left pane:"
        foreach ($uf in $stagedManifest.Uncopied) {
            Write-Host "   ? $($uf.RelativePath)" -ForegroundColor Yellow
        }
        Write-Host "--------------------------------------------------------------------------"
        Write-Host " Did you forget to copy them, or do you want to include them in this commit?" -ForegroundColor Cyan
        Write-Host "   [1] Yes, Include All    - Accept staged files PLUS these uncopied files" -ForegroundColor Green
        Write-Host "   [2] No, Staged Only     - Commit ONLY explicitly copied files (leave these uncommitted)" -ForegroundColor Gray
        Write-Host "   [q] Cancel Review"
        $resp = Read-Host " Enter choice [1-2, q]"
        if ($resp -eq "1" -or $resp -eq "y" -or $resp -eq "yes") {
            $includeUncopied = $true
            $Result = "Accepted"
        } elseif ($resp -eq "2" -or $resp -eq "n" -or $resp -eq "no") {
            $includeUncopied = $false
            $Result = "Accepted"
        } else {
            Write-Host "Review submission cancelled." -ForegroundColor Gray
            return
        }
    }
} elseif ($isExplicitAcceptAll) {
    $includeUncopied = $true
    $Result = "AcceptedAll"
}

if ([string]::IsNullOrWhiteSpace($Result)) {
    $Result = "Accepted"
}

if ($Result -eq "Rejected") {
    if (Test-Path -LiteralPath $stagedManifestFile) { Remove-Item -LiteralPath $stagedManifestFile -Force }
    Write-Host "Review rejected. Staging manifest purged." -ForegroundColor Gray
    return
}

# ------------------------------------------------------------------------------
# Execute Staging Actions: Deletions, Renames & Cleanups
# ------------------------------------------------------------------------------
$actionsExecuted = [System.Collections.Generic.List[string]]::new()

if ($stagedManifest) {
    # 1. Execute Deletions
    if ($stagedManifest.Deletions) {
        foreach ($df in $stagedManifest.Deletions) {
            $liveFile = Join-Path $targetRepoPath $df.RelativePath
            if (Test-Path -LiteralPath $liveFile) {
                Remove-Item -LiteralPath $liveFile -Force -ErrorAction SilentlyContinue
                git -C $targetRepoPath rm -f --ignore-unmatch $df.RelativePath 2>$null | Out-Null
                $actionsExecuted.Add("Deleted: $($df.RelativePath)")
                Write-Host "  [PURGED] Deleted file and Git tracking: $($df.RelativePath)" -ForegroundColor Red
            }
        }
    }

    # 2. Execute Renames
    if ($stagedManifest.Renames) {
        foreach ($rf in $stagedManifest.Renames) {
            $oldLive = Join-Path $targetRepoPath $rf.OldRelativePath
            $newLive = Join-Path $targetRepoPath $rf.NewRelativePath
            if (Test-Path -LiteralPath $oldLive) {
                $newDir = Split-Path $newLive -Parent
                if (-not (Test-Path -LiteralPath $newDir)) { New-Item -ItemType Directory -Path $newDir -Force | Out-Null }
                git -C $targetRepoPath mv -f $rf.OldRelativePath $rf.NewRelativePath 2>$null | Out-Null
                if (Test-Path -LiteralPath $oldLive) { Remove-Item -LiteralPath $oldLive -Force -ErrorAction SilentlyContinue }
                $actionsExecuted.Add("Renamed: $($rf.OldRelativePath) => $($rf.NewRelativePath)")
                Write-Host "  [RENAMED] $($rf.OldRelativePath) => $($rf.NewRelativePath)" -ForegroundColor Yellow
            }
        }
    }
}

# ------------------------------------------------------------------------------
# Git Staging & Commit
# ------------------------------------------------------------------------------
if ($includeUncopied -or ($null -eq $stagedManifest)) {
    git -C $targetRepoPath add -A
} else {
    # Stage accepted files
    if ($stagedManifest.Accepted) {
        foreach ($af in $stagedManifest.Accepted) {
            git -C $targetRepoPath add $af.RelativePath 2>$null | Out-Null
        }
    }
    if ($stagedManifest.Renames) {
        foreach ($rf in $stagedManifest.Renames) {
            git -C $targetRepoPath add $rf.NewRelativePath 2>$null | Out-Null
        }
    }
}

$status = @(git -C $targetRepoPath status --short)
if ($status.Count -gt 0) {
    $commitMsg = if (-not [string]::IsNullOrWhiteSpace($Notes)) { $Notes } else { "feat(review): review acceptance by $env:USERNAME" }
    git -C $targetRepoPath commit -m "$commitMsg"
    $newCommitSha = (git -C $targetRepoPath rev-parse --short HEAD).Trim()

    # Save Permanent Review Record
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $reviewRecord = [ordered]@{
        RepositoryName   = $repoName
        RepositoryPath   = $targetRepoPath
        CommitSha        = $newCommitSha
        ReviewResult     = $Result
        Reviewer         = $env:USERNAME
        Timestamp        = $timestamp
        Message          = $commitMsg
        ActionsExecuted  = $actionsExecuted
    }
    $timeTag = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $finalReviewFile = Join-Path $reviewsDir "review_${repoName}_${timeTag}.json"
    $reviewRecord | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $finalReviewFile -Encoding UTF8

    # Append to active CM activity ledger
    $cmLogFile = Join-Path $workspaceRoot "Workspace_Inventory\logs\cm_activity.log"
    if (Test-Path -LiteralPath (Split-Path $cmLogFile -Parent)) {
        $cmLogEntry = "[$timestamp] [REVIEW_SUBMITTED] [Target: $repoName] [Version: v7.1.0] [PushDate: $timestamp] [AffectedRepos: $repoName, Workspace_Inventory] REVIEW_COMMITTED - Committed review acceptance ($newCommitSha): $commitMsg"
        Add-Content -LiteralPath $cmLogFile -Value $cmLogEntry -Encoding UTF8
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host " REVIEW ACCEPTANCE COMMITTED ($newCommitSha)" -ForegroundColor Green
    Write-Host " Repository : $repoName"
    Write-Host " Message    : $commitMsg"
    Write-Host " Receipt    : $finalReviewFile" -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
} else {
    Write-Host "No staged changes to commit for $repoName." -ForegroundColor Gray
}

# Cleanup staging manifest and temp baseline tree
if (Test-Path -LiteralPath $stagedManifestFile) { Remove-Item -LiteralPath $stagedManifestFile -Force -ErrorAction SilentlyContinue }
if ($stagedManifest -and $stagedManifest.TempReviewRoot -and (Test-Path -LiteralPath $stagedManifest.TempReviewRoot)) {
    Remove-Item -LiteralPath $stagedManifest.TempReviewRoot -Recurse -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------------
# Auto-Synchronize Proposals Ledger (RULE-LCM-002: Dual-State Alignment)
# ------------------------------------------------------------------------------
try {
    $propJsonFile = Join-Path $workspaceRoot "Workspace_Inventory\data\proposals\proposals.json"
    if (Test-Path -LiteralPath $propJsonFile) {
        $propStore = Get-Content -LiteralPath $propJsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $matchedProposal = $false
        foreach ($p in $propStore.proposals) {
            $isRepoMatch = ($p.origin_repo -and $p.origin_repo.StartsWith($repoName))
            $isOpenState = ($p.progress_state -in @('verification', 'committed', 'in_progress', 'review') -or $p.state -in @('approved', 'suggested', 'in_progress', 'review'))
            if ($isRepoMatch -and $isOpenState) {
                $p.progress_state = 'completed'
                $p.state = 'completed'
                if (-not $p.dates) { $p | Add-Member -NotePropertyName "dates" -NotePropertyValue ([ordered]@{}) -Force }
                $p.dates | Add-Member -NotePropertyName "completed" -NotePropertyValue (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") -Force
                $matchedProposal = $true
            }
        }
        if ($matchedProposal) {
            $propStore.updated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
            $propStore | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $propJsonFile -Encoding UTF8
            Write-Host "Auto-synchronized proposals ledger to 'completed'." -ForegroundColor Green
        }
    }
} catch {
    Write-Verbose "Could not auto-update proposals.json: $($_.Exception.Message)"
}
